import Foundation
import WebKit
import UIKit
import SwiftUI

/// Bridges the iOS app to torn.com's authenticated session so we can
/// perform armoury loan/retrieve POSTs from inside Manager. Torn's
/// armouryActionItem endpoint requires the rfc_v CSRF cookie + the
/// PHPSESSID auth cookie — neither is reachable from URLSession or
/// SFSafariViewController (sandboxed). The workaround: run a hidden
/// WKWebView in the app's process, log in once, and execute every
/// action via callAsyncJavaScript inside torn.com's origin so cookies
/// are sent automatically and the script can read rfc_v from
/// document.cookie.
///
/// Cookies persist in WKWebsiteDataStore.default() across launches, so
/// the user signs in once and stays logged in until Torn invalidates
/// the session (~30 days idle).
@MainActor
final class TornWebSession: NSObject, ObservableObject {

    static let shared = TornWebSession()

    /// True once we've confirmed an authenticated session by hitting
    /// /factions.php?step=your and not getting bounced to /login.php.
    @Published private(set) var signedIn: Bool = false

    /// Last error text from a runJS / load attempt — surfaced to UI so
    /// the user sees why an action failed (network, expired session…).
    @Published private(set) var lastError: String?

    /// Shared config drives BOTH the offscreen action webview and the
    /// login sheet — same dataStore = cookies set during login flow are
    /// immediately readable by action calls.
    let configuration: WKWebViewConfiguration

    private var actionWebView: WKWebView?
    private var lastLoadedAt: Date?
    /// Resumed by the WKNavigationDelegate methods (didFinish / didFail)
    /// — single in-flight at a time since we serialize calls.
    private var navContinuation: CheckedContinuation<URL?, Error>?

    private override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        // Mobile Safari UA is what Torn expects — desktop UA triggers
        // a "site under construction" interstitial on some pages.
        cfg.applicationNameForUserAgent = "Mobile/15E148"
        self.configuration = cfg
        super.init()
    }

    /// Called from app launch / Settings — probes by loading the
    /// armoury page and seeing whether Torn redirects to login.
    func refreshSignedInState() async {
        do {
            let final = try await ensureLoaded(force: true)
            signedIn = !(final?.absoluteString.contains("login.php") ?? true)
        } catch {
            lastError = error.localizedDescription
            signedIn = false
        }
    }

    /// Forget the session — drops every torn.com cookie. The user has
    /// to sign in again next time they trigger an action.
    func signOut() async {
        let store = configuration.websiteDataStore
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let tornRecords = records.filter { $0.displayName.contains("torn.com") }
        await store.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            for: tornRecords
        )
        signedIn = false
        lastLoadedAt = nil
    }

    // MARK: — Action surface

    /// Loan one unit of `itemId` from the faction armoury to
    /// `userId`. `category` is the armoury bucket ("weapons" /
    /// "armor" / …) when known; pass nil to sweep every bucket
    /// (slower but works when the item isn't in the cached armoury
    /// snapshot, which can happen for Missing rows whose item isn't
    /// in stock).
    func loan(
        itemId: Int64, userId: Int64, userName: String, category: String?
    ) async throws {
        try requireSignedIn()
        let attempts: [String] = {
            if let c = category, !c.isEmpty {
                // Try the known bucket first, then the alternate spelling
                // for armor/armour so we don't miss a hit.
                return c == "armor" ? ["armor", "armour"] : [c]
            }
            // No hint — sweep every loanable selection in the order
            // most-likely-to-hit first (utilities/weapons account for
            // ~80% of OC requirements).
            return Self.armorySweepOrder
        }()

        var armoryID: String?
        var resolvedCategory: String = attempts.first ?? "utilities"
        for cat in attempts {
            if let id = try await findArmoryID(category: cat, itemId: itemId, ownedByUserId: nil) {
                armoryID = id
                resolvedCategory = cat
                break
            }
        }
        guard let armoryID else {
            throw ActionError.notFound("No spare item in armoury for item #\(itemId). It may be out of stock.")
        }
        try await performArmouryAction(
            role: "loan",
            armoryID: armoryID,
            itemId: itemId,
            userId: userId,
            userName: userName,
            postType: Self.postType(for: resolvedCategory)
        )
    }

    /// Categories searched (in order) when caller passes no hint.
    /// Mirrors ARMORY_API_SELECTIONS in oc-spawn-assistance.user.js
    /// minus 'caches' (not loanable) and 'temporary' (consumables).
    private static let armorySweepOrder: [String] = [
        "utilities", "weapons", "armor", "medical",
        "boosters", "drugs",
    ]

    /// Recall a loaned item. Mirrors retrieve flow in mgr_loadUnusedTab,
    /// but widens the search to every loanable bucket if the caller's
    /// hint doesn't hit — Torn's API selection names (e.g. `utilities`)
    /// occasionally differ from the page-AJAX `type` field, so we
    /// can't trust the hint alone.
    func retrieve(itemId: Int64, userId: Int64, userName: String, category: String) async throws {
        try requireSignedIn()

        let primary: [String] = category == "armor" ? ["armor", "armour"] : [category]
        // Try the hint first (cheapest), then the rest of the sweep
        // order. De-dupe so we don't re-hit the same bucket twice.
        var seen = Set<String>()
        let attempts: [String] = (primary + Self.armorySweepOrder).filter { seen.insert($0).inserted }

        var armoryID: String?
        var resolvedCategory = primary.first ?? category
        var lastReason = "no-rfcv-or-no-page-data"
        var lastSample = ""
        for cat in attempts {
            let result = try await findArmoryIDDiagnostic(
                category: cat, itemId: itemId, ownedByUserId: userId
            )
            switch result {
            case .found(let id):
                armoryID = id
                resolvedCategory = cat
            case .notFound(let reason, let sample):
                lastReason = reason
                lastSample = sample
            }
            if armoryID != nil { break }
        }
        guard let armoryID else {
            throw ActionError.notFound(
                "Torn didn't list the loaned item in any armoury bucket. "
                + "Reason: \(lastReason). Sample: \(lastSample.prefix(160))"
            )
        }
        try await performArmouryAction(
            role: "retrieve",
            armoryID: armoryID,
            itemId: itemId,
            userId: userId,
            userName: userName,
            postType: Self.postType(for: resolvedCategory)
        )
    }

    // MARK: — JS executors

    /// Diagnostic variant — returns either the matched armoryID OR a
    /// (reason, response-sample) pair. Lets retrieve / loan surface
    /// the real cause of a miss instead of "not found" for everything.
    enum FindResult {
        case found(String)
        case notFound(reason: String, sample: String)
    }

    private func findArmoryIDDiagnostic(
        category: String, itemId: Int64, ownedByUserId: Int64?
    ) async throws -> FindResult {
        let arguments: [String: Any] = [
            "category": category,
            "itemID":   NSNumber(value: itemId),
            "userID":   ownedByUserId.map { NSNumber(value: $0) } as Any? ?? NSNull(),
        ]
        let js = """
        const cookies = document.cookie || '';
        const rfcv = cookies.match(/rfc_v=([^;]+)/)?.[1];
        const here = location.href;
        if (!rfcv) {
            return {
                reason: 'no-rfcv',
                sample: 'url=' + here.slice(0, 100)
                    + ' cookieKeys=' + cookies.split(';').map(c => c.split('=')[0].trim()).join(',').slice(0, 200)
            };
        }
        const wantUser = (userID !== null && userID !== undefined);
        let firstSample = '';
        let pages = 0;
        let httpFail = '';
        let lastStatus = 0;
        for (let start = 0; start < 1000; start += 50) {
            const body = new URLSearchParams({
                step: 'armouryTabContent', type: category,
                start: String(start), ajax: 'true'
            });
            let res;
            try {
                res = await fetch('/factions.php?rfcv=' + rfcv, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body, credentials: 'same-origin'
                });
            } catch (e) {
                httpFail = 'fetch-throw:' + (e?.message || e);
                break;
            }
            lastStatus = res.status;
            if (!res.ok) { httpFail = 'http-' + res.status; break; }
            const text = await res.text();
            // Always capture the FIRST bucket's first response —
            // gives us a real artifact when every bucket fails.
            if (!firstSample) firstSample = text.slice(0, 280);
            let data;
            try { data = JSON.parse(text); }
            catch { httpFail = 'parse-fail-len' + text.length; break; }
            if (!data?.items) {
                // Differentiate "Torn returned an error envelope" from
                // "Torn returned a different shape we don't recognise".
                const keys = Object.keys(data || {}).slice(0, 6).join(',');
                httpFail = 'no-items-key keys=' + keys;
                break;
            }
            const items = Array.isArray(data.items) ? data.items : Object.values(data.items);
            if (items.length === 0) break;
            pages += 1;
            for (const e of items) {
                if (Number(e.itemID) !== Number(itemID)) continue;
                if (wantUser) {
                    const uid = e.user && (e.user.userID ?? e.user.id);
                    if (uid !== undefined && String(uid) === String(userID) && e.armoryID) {
                        return { found: String(e.armoryID) };
                    }
                } else {
                    const isUnused = e.user === false || e.user === '' || e.user === 0
                        || (e.user && !(e.user.userID ?? e.user.id));
                    if (isUnused && e.armoryID) {
                        return { found: String(e.armoryID) };
                    }
                }
            }
            if (items.length < 50) break;
        }
        return {
            reason: httpFail || (pages === 0 ? 'empty-bucket' : 'no-match-' + pages + 'pg'),
            sample: 'url=' + here.slice(0, 60) + ' status=' + lastStatus + ' body=' + firstSample.slice(0, 200)
        };
        """
        let raw = try await callTornJS(js, arguments: arguments)
        guard let dict = raw as? [String: Any] else {
            return .notFound(reason: "non-dict-response", sample: String(describing: raw).prefix(160).description)
        }
        if let id = dict["found"] as? String { return .found(id) }
        let reason = (dict["reason"] as? String) ?? "unknown"
        let sample = (dict["sample"] as? String) ?? ""
        return .notFound(reason: "\(category):\(reason)", sample: sample)
    }

    /// Convenience wrapper used by `loan` — delegates to the diagnostic
    /// version and squashes the result down to nil/non-nil since loan
    /// has its own per-bucket retry loop and surfaces a generic
    /// "out of stock" message on full miss.
    private func findArmoryID(category: String, itemId: Int64, ownedByUserId: Int64?) async throws -> String? {
        let result = try await findArmoryIDDiagnostic(
            category: category, itemId: itemId, ownedByUserId: ownedByUserId
        )
        if case .found(let id) = result { return id }
        return nil
    }

    private func performArmouryAction(
        role: String, armoryID: String, itemId: Int64,
        userId: Int64, userName: String, postType: String
    ) async throws {
        let userParam = "\(userName) [\(userId)]"
        let arguments: [String: Any] = [
            "role":     role,
            "armoryID": armoryID,
            "itemID":   String(itemId),    // Torn accepts a string; safer than risking JS Number precision on giant IDs
            "type":     postType,
            "user":     userParam,
        ]
        let js = """
        const rfcv = document.cookie.match(/rfc_v=([^;]+)/)?.[1];
        if (!rfcv) return { ok: false, reason: 'missing-rfcv' };
        const body = new URLSearchParams({
            ajax: 'true', step: 'armouryActionItem', role: role,
            item: armoryID, itemID: itemID, type: type,
            user: user, quantity: '1'
        });
        const res = await fetch('/factions.php?rfcv=' + rfcv, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body, credentials: 'same-origin'
        });
        const text = await res.text();
        return { ok: res.ok, status: res.status, body: text.slice(0, 600) };
        """
        let result = try await callTornJS(js, arguments: arguments)
        guard let dict = result as? [String: Any] else {
            throw ActionError.unexpectedResponse("Empty response from Torn.")
        }
        let body = (dict["body"] as? String) ?? ""
        let status = dict["status"] as? Int ?? 0
        // Torn signals an expired session in three flavours we've seen:
        // a 401/403, an HTML login redirect, or a JSON envelope with
        // "authentication" or "logged out" in the message. Treat them
        // all the same — drop the cached session flag and surface a
        // clear "sign in again" error so the UI can pop the login
        // sheet without the user parsing a Torn error.
        if Self.looksLikeAuthFailure(status: status, body: body) {
            signedIn = false
            throw ActionError.notSignedIn("Torn session expired — sign in again.")
        }
        // The userscript treats any response containing "success" as OK.
        // Torn's response is JSON-ish — { "success": true, ... } — so
        // a simple substring test is sufficient and tolerant of schema
        // tweaks.
        if body.contains("\"success\":true") || body.contains("'success': true")
            || body.contains("success") {
            return
        }
        throw ActionError.tornError("Torn rejected the action (HTTP \(status)). Body: \(body.prefix(200))")
    }

    /// Heuristics for "Torn killed your session" responses. Conservative
    /// — we'd rather miss one occasionally than show "session expired"
    /// for a real action error.
    private static func looksLikeAuthFailure(status: Int, body: String) -> Bool {
        if status == 401 || status == 403 { return true }
        let lower = body.lowercased()
        if lower.contains("authentication") { return true }
        if lower.contains("logged out") { return true }
        if lower.contains("login.php") { return true }
        return false
    }

    private func callTornJS(_ js: String, arguments: [String: Any]) async throws -> Any? {
        let wv = ensureActionWebView()
        try await ensureLoadedIfStale(wv)
        do {
            return try await wv.callAsyncJavaScript(
                js, arguments: arguments,
                in: nil, contentWorld: .page
            )
        } catch {
            // Torn occasionally evicts the session under us — retry
            // once after a fresh load before bubbling the error.
            try await ensureLoaded(force: true)
            return try await wv.callAsyncJavaScript(
                js, arguments: arguments,
                in: nil, contentWorld: .page
            )
        }
    }

    // MARK: — WebView lifecycle

    @discardableResult
    private func ensureLoaded(force: Bool = false) async throws -> URL? {
        let wv = ensureActionWebView()
        return try await ensureLoadedIfStale(wv, force: force)
    }

    @discardableResult
    private func ensureLoadedIfStale(_ wv: WKWebView, force: Bool = false) async throws -> URL? {
        // 60 s freshness window — cookies inside the page (including
        // rfc_v) are still valid; reloading on every action would be
        // wasteful and slow.
        // BUT: if the cached URL is login.php (which happens when
        // refreshSignedInState ran before the user signed in), we
        // MUST reload — otherwise our same-origin fetch executes from
        // an unauthenticated page context and Torn returns an error
        // envelope without `items`.
        let cur = wv.url?.absoluteString ?? ""
        let stale = lastLoadedAt.map { Date().timeIntervalSince($0) > 60 } ?? true
        let onLogin = cur.contains("login.php") || cur.isEmpty
        if !force, !stale, !onLogin, cur.contains("torn.com") {
            // Even when the page is fresh, re-assert the armoury route
            // before each action — Torn's React router controls which
            // tab is "active" and the page-AJAX endpoint occasionally
            // returns empty / error envelopes when the active tab is
            // anything other than armoury.
            try? await ensureOnArmouryTab(wv)
            return wv.url
        }
        // Load the armoury route directly via the hash fragment — Torn's
        // React router consumes it on mount so the armoury tab is the
        // active one by the time we run our fetch.
        let url = URL(string: "https://www.torn.com/factions.php?step=your#/tab=armoury")!
        let final = try await load(wv, url: url)
        try? await ensureOnArmouryTab(wv)
        lastLoadedAt = Date()
        return final
    }

    /// Force the React router to the armoury tab and wait briefly for
    /// it to settle before letting the caller run their fetch. Mirrors
    /// the userscript's two-step "navigate then act" flow exactly.
    private func ensureOnArmouryTab(_ wv: WKWebView) async throws {
        let nav = """
        if (!location.hash.includes('tab=armoury') && !location.hash.includes('tab=armory')) {
            location.hash = '#/tab=armoury';
        }
        // Yield twice — once for the React router to react to the
        // hash change, once more for any tab-mount AJAX to settle.
        await new Promise(r => setTimeout(r, 350));
        await new Promise(r => setTimeout(r, 350));
        return location.hash;
        """
        _ = try? await wv.callAsyncJavaScript(nav, arguments: [:], in: nil, contentWorld: .page)
    }

    private func load(_ wv: WKWebView, url: URL) async throws -> URL? {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL?, Error>) in
            self.navContinuation = cont
            wv.load(URLRequest(url: url))
        }
    }

    /// Lazily creates the offscreen WKWebView and parents it under the
    /// active key window so navigation actually fires (a detached
    /// WKWebView can stall navigation on iOS 17). 1×1 hidden frame so
    /// it never paints.
    private func ensureActionWebView() -> WKWebView {
        if let wv = actionWebView { return wv }
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        wv.isHidden = true
        wv.navigationDelegate = self
        if let window = Self.keyWindow() {
            window.addSubview(wv)
        }
        actionWebView = wv
        return wv
    }

    // MARK: — Helpers

    private func requireSignedIn() throws {
        if !signedIn {
            throw ActionError.notSignedIn("Sign in to torn.com to enable in-app loan / retrieve.")
        }
    }

    /// Map armoury category → Torn's `type` POST field. Mirrors
    /// ARMORY_TAB_TO_POST_TYPE in oc-spawn-assistance.user.js.
    private static func postType(for category: String) -> String {
        switch category.lowercased() {
        case "drugs":     return "Drug"
        case "medical":   return "Medical"
        case "boosters":  return "Booster"
        case "temporary": return "Temporary"
        case "clothing":  return "Clothing"
        case "armor", "armour": return "Armor"
        case "weapons":   return "Primary"
        case "utilities": return "Tool"
        default:          return "Tool"
        }
    }

    private func displayCategory(_ c: String) -> String {
        c == "armor" ? "armor" : c
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
    }

    enum ActionError: LocalizedError {
        case notSignedIn(String)
        case notFound(String)
        case tornError(String)
        case unexpectedResponse(String)
        var errorDescription: String? {
            switch self {
            case .notSignedIn(let s),
                 .notFound(let s),
                 .tornError(let s),
                 .unexpectedResponse(let s):
                return s
            }
        }
    }
}

// MARK: — WKNavigationDelegate

extension TornWebSession: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // Read webView.url inside the MainActor block — WKWebView's
            // `url` is main-actor-isolated under strict concurrency.
            let finalURL = webView.url
            self.navContinuation?.resume(returning: finalURL)
            self.navContinuation = nil
        }
    }
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.navContinuation?.resume(throwing: error)
            self.navContinuation = nil
        }
    }
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.navContinuation?.resume(throwing: error)
            self.navContinuation = nil
        }
    }
}

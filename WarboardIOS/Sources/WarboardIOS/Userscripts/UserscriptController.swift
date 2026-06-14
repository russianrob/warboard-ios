import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
#endif

/// Owns the WKWebView configuration and rebuilds the injected user-script set
/// on every navigation (Approach 1). Pure ordering/selection is delegated to
/// `UserscriptInjectionPlanner`; this type only does the WebKit wiring.
@MainActor
final class UserscriptController: NSObject, ObservableObject {

    /// A GM_registerMenuCommand entry the SwiftUI chrome renders. `id` matches
    /// the JS-side menu index so `invokeMenuCommand(_:)` can call back through
    /// `window.__wbInvokeMenuCommand`.
    struct MenuCommand: Identifiable, Equatable {
        let id: Int
        let label: String
    }

    /// Live menu commands the current page's scripts have registered. Reset on
    /// each navigation rebuild; published so the URL-bar menu re-renders.
    @Published private(set) var menuCommands: [MenuCommand] = []

    /// A `.user.js` URL the Browser tab navigated to, captured so SwiftUI can
    /// present the install-confirmation sheet. `Identifiable` drives
    /// `.sheet(item:)`; nil-ed when the sheet is dismissed.
    struct PendingInstall: Identifiable {
        let id = UUID()
        let url: URL
    }

    /// Set when a main-frame navigation targets a `.user.js`; the navigation is
    /// cancelled and BrowserView shows the install sheet instead.
    @Published var pendingInstall: PendingInstall?

    /// On-device DevTools (eruda) toggle. When on, the eruda console/network/
    /// elements overlay is injected into the page (and re-injected on each
    /// full navigation). Published so the menu shows its state.
    @Published private(set) var devToolsEnabled = false

    /// Eruda's bundle source, fetched once natively (so Torn's CSP doesn't
    /// block it) and reused for every (re)injection.
    private var erudaSource: String?

    private let registry: ScriptRegistry
    private let requireCache: RequireCache
    private let gmBridge: GMBridge

    /// The web view this controller drives. Set in `makeWebView`; used to call
    /// menu-command callbacks back into the page.
    private weak var webView: WKWebView?

    /// A URL we just re-issued via `webView.load(...)` to keep a cross-host
    /// Torn navigation inside this web view (see `decidePolicyFor`). When that
    /// app-initiated load comes back through the delegate we recognize it by
    /// this marker and let it proceed, instead of cancelling it again (loop).
    private var forcedInAppLoadURL: String?

    /// Built once; handed to the WKWebView. We mutate its
    /// userContentController per navigation.
    let configuration: WKWebViewConfiguration

    private var userContent: WKUserContentController {
        configuration.userContentController
    }

    init(registry: ScriptRegistry, requireCache: RequireCache, gmBridge: GMBridge) {
        self.registry = registry
        self.requireCache = requireCache
        self.gmBridge = gmBridge

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // share Torn login cookie jar
        // NOTE: do NOT set a Safari applicationNameForUserAgent here. Spoofing a
        // full Mobile Safari UA (tried in 0.11.218) BACKFIRED — Cloudflare ran its
        // stricter Safari-path Turnstile, whose fingerprint consistency check the
        // WebView can't satisfy, so the "Verify you are human" checkbox looped
        // forever. The bare WKWebView UA gets the easier self-clearing "Just a
        // moment…" JS challenge instead. Keep the default UA.
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // Serve bundled WebExtension resources for browser.runtime.getURL().
        config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: ExtResourceScheme.scheme)
        self.configuration = config
        super.init()

        // GM message handlers are registered ONCE (they outlive navigations);
        // only user scripts are torn down/rebuilt per navigation.
        gmBridge.register(on: config.userContentController)

        // Link-tap diagnostics: a capture-phase click probe reports every
        // anchor tap to native, where WebDiag forwards it to the warboard
        // log stream. Registered ONCE alongside the GM handlers.
        WebDiagBridge.install(on: config.userContentController)

        // GM_registerMenuCommand → surface the command in the chrome menu.
        gmBridge.onRegisterMenuCommand = { [weak self] _, name, id in
            Task { @MainActor in self?.addMenuCommand(name: name, id: id) }
        }

        // WebExtension runtime: register the relay on this config + start the
        // hidden background host; route browser.tabs.create into this browser.
        ExtensionRuntime.shared.install(on: config)
        ExtensionRuntime.shared.onOpenURL = { [weak self] urlString in
            guard let self, let url = URL(string: urlString) else { return }
            Task { @MainActor in self.webView?.load(URLRequest(url: url)) }
        }
        // storage.onChanged → emit into the extension's content world on the page
        // web view, so feature toggles apply live (no refresh). The content scripts
        // + their onChanged listeners run in `.world(name: extId)`.
        ExtensionRuntime.shared.pushStorageChangedToContent = { [weak self] extId, area, changes in
            let json = (try? JSONSerialization.data(withJSONObject: changes))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            Task { @MainActor in
                guard let wv = self?.webView else { return }
                _ = try? await wv.callAsyncJavaScript(
                    "window.__webext_emit && window.__webext_emit('storageChanged', JSON.parse(c), a);",
                    arguments: ["c": json, "a": area], in: nil, contentWorld: .world(name: extId))
            }
        }
    }

    /// Convenience for SwiftUI hosts: build a controller from the default,
    /// process-wide registry/cache/bridge dependencies.
    override convenience init() {
        self.init(registry: ScriptRegistry.shared,
                  requireCache: RequireCache(root: RequireCache.defaultRoot()),
                  gmBridge: GMBridge())
    }

    private func addMenuCommand(name: String, id: Int) {
        menuCommands.removeAll { $0.id == id }
        menuCommands.append(MenuCommand(id: id, label: name))
    }

    /// Invoke a script's registered menu command by id (calls the JS hook the
    /// bootstrap installs as `window.__wbInvokeMenuCommand`).
    func invokeMenuCommand(_ id: Int) {
        webView?.evaluateJavaScript("window.__wbInvokeMenuCommand(\(id))",
                                    completionHandler: nil)
    }

    /// Maps the planner's platform-free timing to WebKit's enum.
    private func injectionTime(_ t: InjectionTiming) -> WKUserScriptInjectionTime {
        switch t {
        case .documentStart: return .atDocumentStart
        case .documentEnd:   return .atDocumentEnd
        }
    }

    // Cloudflare challenge loop detection + auto-recovery. After ~2h idle the
    // cf_clearance cookie expires; reopening the app triggers a FRESH challenge
    // that WKWebView can loop on (PDA's recognized UA gets the easy one and
    // passes). Set from decidePolicyFor:navigationResponse below.
    private var cfChallengeActive = false
    private var cfChallengeLoads: [Date] = []
    private var cfRecoveryAttempts = 0

    /// Rebuild the WKUserScript set for `url`. Called from
    /// decidePolicyFor BEFORE allowing the navigation, so WebKit applies the
    /// new scripts to the page about to load.
    func rebuildUserScripts(for url: URL) {
        // New page → the previous page's menu commands no longer apply.
        menuCommands.removeAll()

        // On a Cloudflare challenge page, inject ONLY the diag probe + link fixer:
        // a userscript/extension that clones the challenge's fetch breaks it in
        // WKWebView (→ the reopen loop). Skip ALL userscripts + extension scripts.
        if cfChallengeActive {
            userContent.removeAllUserScripts()
            userContent.addUserScript(WebDiagBridge.probeUserScript())
            userContent.addUserScript(Self.linkFixerUserScript())
            WebDiag.log("cf-skip-inject", ["url": url.absoluteString])
            return
        }

        // 1. Enabled scripts whose @match/@include match and aren't @excluded,
        //    in install order. Selection lives in the registry (MatchMatcher).
        let scripts = registry.enabledScripts(matching: url)

        // 2. Resolve @require sources from the on-disk cache. A cache miss means
        //    the lib isn't available; the planner drops that script's body.
        var requireSources: [String: String] = [:]
        for script in scripts {
            for req in script.requires where requireSources[req] == nil {
                if let src = requireCache.read(forURL: req) {
                    requireSources[req] = src
                }
            }
        }

        // 3. The GM bootstrap, carrying this navigation's per-script storage
        //    snapshots (sync GM_getValue) + GM_info, built by the bridge.
        let bootstrap = gmBridge.bootstrapSource(for: scripts, url: url)

        // 4. Pure ordering.
        let planned = UserscriptInjectionPlanner.plan(
            for: url,
            scripts: scripts,
            requireSources: requireSources,
            bootstrapSource: bootstrap
        )

        // 5. Apply. removeAllUserScripts clears the PREVIOUS navigation's set;
        //    GM message handlers (registered in init) are untouched. The
        //    click-probe is a user script too, so re-add it after the wipe.
        userContent.removeAllUserScripts()
        userContent.addUserScript(WebDiagBridge.probeUserScript())
        userContent.addUserScript(Self.linkFixerUserScript())
        for p in planned {
            let ws = WKUserScript(
                source: p.source,
                injectionTime: injectionTime(p.timing),
                forMainFrameOnly: p.mainFrameOnly,
                in: .page                       // MAIN world: unsafeWindow === window
            )
            userContent.addUserScript(ws)
        }

        // 6. WebExtension (ReTorn) content scripts for this URL, injected into
        //    the isolated "retorn" content world so ReTorn's bundled jQuery
        //    stack stays off Torn's page and the userscripts above.
        for ws in ExtensionRuntime.shared.contentWorldScripts(for: url) {
            userContent.addUserScript(ws)
        }

        // 7. WebExtension main-world (.page) injections — ReTorn's fetch
        //    interceptor, which must run in the page world to patch Torn's real
        //    fetch + reach page globals; it bridges back to the content world
        //    via cross-world DOM CustomEvents.
        for ws in ExtensionRuntime.shared.mainWorldScripts(for: url) {
            userContent.addUserScript(ws)
        }
    }

    /// Torn intercepts `target="_blank"` link clicks before WebKit can open a
    /// new window, so those links do nothing in a single-web-view browser.
    /// This capture-phase listener opens them in-place instead. Re-injected
    /// every navigation (it's cleared by removeAllUserScripts above).
    private static func linkFixerUserScript() -> WKUserScript {
        let src = """
        (function () {
          if (window.__wbLinkFixer) return;
          window.__wbLinkFixer = true;
          document.addEventListener('click', function (e) {
            var t = e.target;
            var a = (t && t.closest) ? t.closest('a[target="_blank"]') : null;
            if (a && a.href && /^https?:/i.test(a.href)) {
              e.preventDefault();
              window.location.assign(a.href);
            }
          }, true);
        })();
        """
        return WKUserScript(source: src, injectionTime: .atDocumentStart,
                            forMainFrameOnly: false, in: .page)
    }
}

extension UserscriptController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            WebDiag.log("nav", [
                "url": url.absoluteString,
                "type": navigationAction.navigationType.rawValue,
                "mainFrame": navigationAction.targetFrame?.isMainFrame ?? false,
            ])
        }

        // A main-frame hit on a `.user.js` is an install request, not a page to
        // render: cancel the load and hand the URL to the install sheet. Done
        // before the rebuild so the cancelled nav never re-plans scripts.
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.path.lowercased().hasSuffix(".user.js") {
            decisionHandler(.cancel)
            pendingInstall = PendingInstall(url: url)
            return
        }

        // Keep cross-host Torn navigations inside this web view. iOS routes a
        // programmatic, cross-origin WKWebView navigation to a Universal-Link
        // handler when the destination domain claims one — wiki.torn.com serves
        // its own apple-app-site-association handing its links to TornPDA — which
        // yanks the user out of warboard into PDA. Re-issuing the load ourselves
        // (an app-initiated `load`, unlike a page-initiated nav) is NOT eligible
        // for Universal-Link routing, so the page loads in-app instead. Scoped to
        // *.torn.com cross-host hops so ordinary same-domain SPA navs are untouched.
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.scheme == "https" || url.scheme == "http",
           let destHost = url.host,
           destHost == "torn.com" || destHost.hasSuffix(".torn.com"),
           let curHost = webView.url?.host,
           destHost.caseInsensitiveCompare(curHost) != .orderedSame,
           forcedInAppLoadURL != url.absoluteString {
            forcedInAppLoadURL = url.absoluteString
            WebDiag.log("crosshost-keep", ["url": url.absoluteString, "from": curHost])
            decisionHandler(.cancel)
            webView.load(navigationAction.request)
            return
        }
        // Our own re-issued load returning through the delegate — clear the
        // marker so a later genuine nav to the same URL is handled normally.
        if navigationAction.request.url?.absoluteString == forcedInAppLoadURL {
            forcedInAppLoadURL = nil
        }

        // Only main-frame, real-URL navigations trigger a rebuild; subframes
        // and about:blank keep the current set. (Scripts are main-frame-only.)
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.scheme == "https" || url.scheme == "http" {
            rebuildUserScripts(for: url)
        }
        decisionHandler(.allow)
    }

    /// Detect Cloudflare challenge responses on the main Torn document. After ~2h
    /// idle the `cf_clearance` cookie expires, so reopening triggers a fresh
    /// challenge WKWebView can loop on. Logs every challenge (diag) and, when it's
    /// actually LOOPING, auto-recovers by clearing only the Cloudflare cookies
    /// (Torn login preserved) + reloading once.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame,
           let resp = navigationResponse.response as? HTTPURLResponse,
           let host = resp.url?.host, host.contains("torn.com") {
            let mitigated = (resp.value(forHTTPHeaderField: "cf-mitigated") ?? "").lowercased()
            let isChallenge = mitigated == "challenge" || resp.statusCode == 403 || resp.statusCode == 503
            evaluateCloudflare(isChallenge: isChallenge, status: resp.statusCode,
                               mitigated: mitigated, url: resp.url?.absoluteString ?? "")
        }
        decisionHandler(.allow)
    }

    private func evaluateCloudflare(isChallenge: Bool, status: Int, mitigated: String, url: String) {
        if isChallenge {
            cfChallengeActive = true
            let now = Date()
            cfChallengeLoads.append(now)
            cfChallengeLoads = cfChallengeLoads.filter { now.timeIntervalSince($0) < 15 }
            WebDiag.log("cf-challenge", [
                "status": status, "mitigated": mitigated,
                "loadsIn15s": cfChallengeLoads.count, "recoveries": cfRecoveryAttempts,
            ])
            // A genuine loop = 3+ challenge documents within 15s. Recover ONCE —
            // clearing cf cookies again on every loop would itself loop.
            if cfChallengeLoads.count >= 3 && cfRecoveryAttempts < 1 {
                cfRecoveryAttempts += 1
                recoverFromCloudflareLoop()
            }
        } else {
            // Any non-challenge main-frame Torn response means we're through —
            // clear the latch on the exact complement of the set condition (NOT
            // just status==200, or a 3xx/redirect would leave scripts suppressed
            // for the whole session).
            if cfChallengeActive {
                WebDiag.log("cf-cleared", ["url": url, "status": status, "afterRecoveries": cfRecoveryAttempts])
            }
            cfChallengeActive = false
            cfChallengeLoads.removeAll()
            cfRecoveryAttempts = 0
        }
    }

    /// Clear ONLY the Cloudflare cookies (`cf_*` / `__cf*`) so the Torn login
    /// survives, then reload once for a clean fresh challenge.
    private func recoverFromCloudflareLoop() {
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore else { return }
        WebDiag.log("cf-recover", ["action": "clear-cf-cookies+reload"])
        store.getAllCookies { [weak self] cookies in
            let cf = cookies.filter { $0.name.hasPrefix("cf_") || $0.name.hasPrefix("__cf") }
            let group = DispatchGroup()
            for c in cf { group.enter(); store.delete(c) { group.leave() } }
            group.notify(queue: .main) {
                WebDiag.log("cf-recover-done", [
                    "deleted": cf.count, "names": cf.map(\.name).joined(separator: ","),
                ])
                self?.cfChallengeLoads.removeAll()
                self?.webView?.reload()
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebDiag.log("didFinish", ["url": webView.url?.absoluteString ?? "nil"])
        // Eruda lives in the page's window, so a full load wipes it — re-inject
        // when DevTools is on. (SPA hash navs keep the same window, so they
        // don't need this.)
        injectErudaIfEnabled()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        WebDiag.log("didFail", [
            "url": webView.url?.absoluteString ?? "nil",
            "error": error.localizedDescription,
        ])
    }
}

extension UserscriptController {
    /// Build the WKWebView the Browser tab displays. The controller is the
    /// navigation delegate (drives the per-navigation rebuild) and must be
    /// retained by the caller for the web view's lifetime.
    func makeWebView() -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        self.webView = wv
        return wv
    }
}

/// Receives the capture-phase click probe's messages from the page and
/// forwards them to `WebDiag`. A standalone `NSObject` (not the
/// `UserscriptController`) so the plain `WKScriptMessageHandler` retain
/// chain stays separate from the reply-style GM bridge. Registered ONCE
/// in `.page` alongside the GM handlers.
final class WebDiagBridge: NSObject, WKScriptMessageHandler {
    static let messageHandlerName = "wbdiag"

    /// Capture-phase document click listener. Resolves the clicked element's
    /// nearest `<a>` and posts its href/target/class to native; reports
    /// `noAnchor` when the tap didn't land inside a link. mainFrameOnly:false
    /// so taps in Torn's iframes (chat panel) are captured too.
    private static let probeSource = """
    (function () {
      document.addEventListener('click', function (e) {
        try {
          var tag = (e.target && e.target.tagName) ? String(e.target.tagName) : '';
          var a = e.target && e.target.closest ? e.target.closest('a') : null;
          if (a) {
            window.webkit.messageHandlers.wbdiag.postMessage({
              href: a.href || '',
              target: a.target || '',
              cls: a.className ? String(a.className) : '',
              prevented: false,
              tag: tag
            });
          } else {
            window.webkit.messageHandlers.wbdiag.postMessage({ noAnchor: true, tag: tag });
          }
        } catch (err) {}
      }, true);
    })();
    """

    /// The capture-phase click-probe user script. Re-added by
    /// `UserscriptController.rebuildUserScripts` after every
    /// `removeAllUserScripts()`, since that call also clears this probe.
    static func probeUserScript() -> WKUserScript {
        WKUserScript(
            source: probeSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false,
            in: .page
        )
    }

    /// Install the receiving message handler and the initial click probe.
    /// The handler outlives per-navigation rebuilds; the probe is re-added
    /// on each rebuild via `probeUserScript()`.
    static func install(on userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(
            forName: messageHandlerName, contentWorld: .page)
        let bridge = WebDiagBridge()
        userContentController.add(bridge, contentWorld: .page, name: messageHandlerName)
        userContentController.addUserScript(probeUserScript())
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        WebDiag.log("click", body)
    }
}

extension UserscriptController {
    /// Pinned to eruda 3.x. jsDelivr resolves the latest 3.x patch; URLSession
    /// follows the redirect.
    private static let erudaURL = "https://cdn.jsdelivr.net/npm/eruda@3"

    /// Wrap eruda's UMD bundle so it attaches to `window.eruda`. Torn's page has
    /// a module loader (AMD `define.amd` / CommonJS `module`), and eruda's UMD
    /// would bind to THAT instead of the global — leaving `window.eruda`
    /// undefined and the console invisible. We hide define/module/exports across
    /// the eval, then init.
    private static func erudaInjection(_ source: String, show: Bool) -> String {
        return """
        (function(){
          var _d = window.define, _m = window.module, _e = window.exports;
          try { window.define = undefined; window.module = undefined; window.exports = undefined; } catch (e) {}
          var err = '';
          try {
        \(source)
          } catch (e) { err = String(e); }
          try { window.define = _d; window.module = _m; window.exports = _e; } catch (e) {}
          try {
            if (window.eruda) {
              if (!window.__wbEruda) { eruda.init(); window.__wbEruda = true; }
              \(show ? "try { eruda.show(); } catch (e) {}" : "")
            }
          } catch (e) { if (!err) err = String(e); }
          return JSON.stringify({ eruda: typeof window.eruda, inited: !!window.__wbEruda, err: err });
        })();
        """
    }

    func toggleDevTools() { setDevTools(!devToolsEnabled) }

    func setDevTools(_ on: Bool) {
        devToolsEnabled = on
        guard let wv = webView else { return }
        if on {
            Task { @MainActor in
                guard let src = await loadErudaSource(), let wv = self.webView else {
                    WebDiag.log("devtools", ["phase": "no-source-or-webview"])
                    return
                }
                wv.evaluateJavaScript(Self.erudaInjection(src, show: true)) { result, error in
                    WebDiag.log("devtools", ["phase": "toggle-on",
                                             "status": "\(result ?? "nil")",
                                             "error": error.map { "\($0)" } ?? ""])
                }
            }
        } else {
            wv.evaluateJavaScript("try{if(window.eruda&&eruda.hide)eruda.hide();}catch(e){}", completionHandler: nil)
        }
    }

    private func injectErudaIfEnabled() {
        guard devToolsEnabled else { return }
        Task { @MainActor in
            guard let src = await loadErudaSource(), let wv = self.webView else { return }
            wv.evaluateJavaScript(Self.erudaInjection(src, show: false), completionHandler: nil)
        }
    }

    /// Fetch the eruda bundle once and cache it. Native fetch, so Torn's CSP
    /// (which would block a page-loaded <script src>) doesn't apply; the source
    /// is then evaluated into the page directly.
    private func loadErudaSource() async -> String? {
        if let s = erudaSource { return s }
        guard let url = URL(string: Self.erudaURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let s = String(data: data, encoding: .utf8)
            erudaSource = s
            return s
        } catch {
            return nil
        }
    }
}

extension UserscriptController: WKUIDelegate {
    /// target=_blank / window.open links (Torn chat profile/item links) open
    /// no window by default in WKWebView — load them in the same view so they
    /// don't look unclickable.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        WebDiag.log("newwindow", ["url": navigationAction.request.url?.absoluteString ?? "nil"])
        if navigationAction.request.url != nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    #if canImport(UIKit)
    // WKWebView shows NO JS dialogs unless the UI delegate handles them, so a
    // script's alert()/confirm()/prompt() (e.g. FFS's "click to add" limited-key
    // prompt) silently no-ops. Present native UIAlertControllers like PDA does.
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard let vc = Self.wbTopViewController() else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        vc.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard let vc = Self.wbTopViewController() else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        vc.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard let vc = Self.wbTopViewController() else { completionHandler(nil); return }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        vc.present(alert, animated: true)
    }

    /// Topmost presented view controller of the key window, to present alerts from.
    private static func wbTopViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}

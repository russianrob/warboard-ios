import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
#endif

/// Native side of the GM bridge. Registered as the `gmBridge`
/// `WKScriptMessageHandlerWithReply`; routes bootstrap messages to native
/// privileged operations and replies with the JS Promise resolution.
final class GMBridge: NSObject, WKScriptMessageHandlerWithReply {

    /// Per-script state the bridge needs, keyed by `Userscript.id`.
    struct ScriptContext {
        let scriptID: String
        let connects: [String]
        let wildcardConnectGranted: Bool
        let store: GMStore
    }

    /// Maintained by `UserscriptController` on every navigation rebuild.
    var activeScripts: [String: ScriptContext] = [:]

    /// Callbacks into the app shell (wired by `UserscriptController`).
    var onOpenInTab: ((URL, Bool) -> Void)?
    var onRequestWildcardConsent: ((_ scriptID: String,
                                    _ completion: @escaping (Bool) -> Void) -> Void)?
    var onRegisterMenuCommand: ((_ scriptID: String, _ name: String, _ id: Int) -> Void)?

    private let session: URLSession

    /// Engine version stamped into `GM_info.version` / `scriptHandler` build.
    let engineVersion: String

    init(session: URLSession = .shared, engineVersion: String = "1.0") {
        self.session = session
        self.engineVersion = engineVersion
        super.init()
    }

    /// JS-side `window.webkit.messageHandlers` name the bootstrap posts to.
    static let messageHandlerName = "gmBridge"

    /// Install the reply-style message handler that the GM bootstrap calls.
    /// Registered ONCE by `UserscriptController` (the handler outlives
    /// per-navigation user-script rebuilds). Main world so it shares the
    /// page's `window`. Idempotent: drops any prior registration first.
    func register(on userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(
            forName: Self.messageHandlerName, contentWorld: .page)
        userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: Self.messageHandlerName)
    }

    /// Build the document-start GM bootstrap for the scripts matched on `url`,
    /// and (re)populate `activeScripts` so storage/XHR routing works for each.
    ///
    /// The injected bootstrap exposes a single `__WB_SCRIPT_CONTEXT__`, so the
    /// emitted source carries the FIRST matched script's id + GM_info + storage
    /// snapshot; every matched script is still registered in `activeScripts` so
    /// the native side answers their bridge calls. (Per-script isolated GM_info
    /// across multiple scripts on one page is a known engine limitation — see
    /// the reconciliation report.)
    func bootstrapSource(for scripts: [Userscript], url: URL) -> String {
        for script in scripts {
            activeScripts[script.id] = ScriptContext(
                scriptID: script.id,
                connects: script.connects,
                wildcardConnectGranted: script.wildcardConnectGranted,
                store: store(for: script.id))
        }

        guard let primary = scripts.first else {
            return GMBootstrap.source(scriptID: "", infoJSON: "{}",
                                      snapshotLiteral: "{}")
        }

        let snapshot = (try? store(for: primary.id)
            .snapshotJSON(scriptId: primary.id)) ?? "{}"
        return GMBootstrap.source(
            scriptID: primary.id,
            infoJSON: Self.infoJSON(for: primary, engineVersion: engineVersion),
            snapshotLiteral: snapshot)
    }

    /// Shared persistent GM storage; every script's context reads/writes here
    /// keyed by `scriptId`, so one `GMStore` backs the whole engine.
    private let gmStore = GMStore()

    private func store(for scriptID: String) -> GMStore { gmStore }

    /// Build the `GM_info` object literal for a script (spliced into
    /// `__WB_SCRIPT_CONTEXT__.info` by `GMBootstrap.source`).
    static func infoJSON(for script: Userscript, engineVersion: String) -> String {
        let info: [String: Any] = [
            "script": [
                "name": script.name,
                "namespace": script.namespace ?? "",
                "version": script.version ?? "",
                "description": script.description ?? "",
                "matches": script.matches,
                "includes": script.includes,
                "excludes": script.excludes,
                "runAt": script.runAt.token,
                "grant": script.grants
            ] as [String: Any],
            "scriptHandler": "WarboardIOS",
            "version": engineVersion,
            "scriptMetaStr": script.source.userScriptMetaBlock ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: info),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: - WKScriptMessageHandlerWithReply

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any],
              let scriptID = body["scriptId"] as? String,
              let action = body["action"] as? String,
              let ctx = activeScripts[scriptID] else {
            replyHandler(nil, "no active script context")
            return
        }
        let payload = body["payload"] as? [String: Any] ?? [:]

        switch action {
        case "setValue":
            if let key = payload["key"] as? String {
                try? ctx.store.set(scriptId: ctx.scriptID, key: key,
                                   value: JSONValue(fromAny: payload["value"]))
            }
            replyHandler(nil, nil)

        case "deleteValue":
            if let key = payload["key"] as? String {
                try? ctx.store.delete(scriptId: ctx.scriptID, key: key)
            }
            replyHandler(nil, nil)

        case "xmlhttpRequest":
            performXHR(payload: payload, scriptID: scriptID, ctx: ctx,
                       replyHandler: replyHandler)

        case "setClipboard":
            #if canImport(UIKit)
            UIPasteboard.general.string = payload["text"] as? String ?? ""
            #endif
            replyHandler(nil, nil)

        case "openInTab":
            if let urlStr = payload["url"] as? String, let url = URL(string: urlStr) {
                let active = (payload["active"] as? Bool) ?? true
                DispatchQueue.main.async { self.onOpenInTab?(url, active) }
            }
            replyHandler(nil, nil)

        case "registerMenuCommand":
            if let name = payload["name"] as? String,
               let id = payload["id"] as? Int {
                DispatchQueue.main.async {
                    self.onRegisterMenuCommand?(scriptID, name, id)
                }
            }
            replyHandler(nil, nil)

        case "notification":
            // Route GM_notification through the same WBExtNotify bridge
            // browser.notifications.create uses (this lib target can't see
            // NotificationManager — the app's AppDelegate observes + fires).
            let nTitle = (payload["title"] as? String) ?? "Warboard"
            let nText = (payload["text"] as? String) ?? (payload["body"] as? String) ?? ""
            let nId = (payload["id"] as? String) ?? UUID().uuidString
            NotificationCenter.default.post(
                name: Notification.Name("WBExtNotify"), object: nil,
                userInfo: ["title": nTitle, "body": nText, "id": nId])
            replyHandler(nil, nil)

        default:
            replyHandler(nil, "unknown action: \(action)")
        }
    }

    // MARK: - xmlhttpRequest

    private func performXHR(payload: [String: Any],
                            scriptID: String,
                            ctx: ScriptContext,
                            replyHandler: @escaping (Any?, String?) -> Void) {
        guard let urlStr = payload["url"] as? String, let url = URL(string: urlStr) else {
            replyHandler(nil, "invalid url"); return
        }
        // The single shared bootstrap attributes EVERY page script's GM calls to
        // the FIRST matched script's id, so `ctx.connects` is only that one
        // script's @connect list — a request from a later-loaded script (e.g. FFS
        // → ffscouter.com) would be checked against the wrong allowlist and
        // blocked. Decide against the UNION of all active scripts' @connect lists;
        // they are all the user's own installed scripts.
        let unionConnects = Array(Set(activeScripts.values.flatMap { $0.connects }))
        let anyWildcard = activeScripts.values.contains { $0.wildcardConnectGranted }
        let policy = ConnectPolicy(connects: unionConnects,
                                   wildcardConnectGranted: anyWildcard)
        switch policy.decision(forURL: url) {
        case .blocked:
            replyHandler(nil, "blocked by @connect: \(url.host ?? "?")")
        case .needsWildcardConsent:
            guard let ask = onRequestWildcardConsent else {
                replyHandler(nil, "wildcard @connect not granted"); return
            }
            DispatchQueue.main.async {
                ask(scriptID) { granted in
                    guard granted else {
                        replyHandler(nil, "wildcard @connect denied"); return
                    }
                    // Caller (UserscriptController) persists the flag + refreshes
                    // activeScripts; reflect the grant locally and re-dispatch.
                    self.activeScripts[scriptID] = ScriptContext(
                        scriptID: ctx.scriptID,
                        connects: ctx.connects,
                        wildcardConnectGranted: true,
                        store: ctx.store)
                    self.sendXHR(payload: payload, url: url, replyHandler: replyHandler)
                }
            }
        case .allowed:
            sendXHR(payload: payload, url: url, replyHandler: replyHandler)
        }
    }

    private func sendXHR(payload: [String: Any], url: URL,
                         replyHandler: @escaping (Any?, String?) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = (payload["method"] as? String) ?? "GET"
        if let headers = payload["headers"] as? [String: String] {
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        }
        if let data = payload["data"] as? String, !data.isEmpty {
            req.httpBody = data.data(using: .utf8)
        }
        if let timeout = payload["timeout"] as? Double, timeout > 0 {
            req.timeoutInterval = timeout / 1000.0
        }
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                replyHandler(["error": error.localizedDescription], nil)
                return
            }
            let http = response as? HTTPURLResponse
            var headerMap: [String: String] = [:]
            http?.allHeaderFields.forEach { k, v in
                headerMap["\(k)"] = "\(v)"
            }
            let result: [String: Any] = [
                "status": http?.statusCode ?? 0,
                "statusText": HTTPURLResponse.localizedString(
                    forStatusCode: http?.statusCode ?? 0),
                "responseHeaders": headerMap,
                "responseText": data.flatMap { String(data: $0, encoding: .utf8) } ?? "",
                "finalUrl": (http?.url ?? url).absoluteString
            ]
            replyHandler(result, nil)
        }.resume()
    }
}

private extension String {
    /// Slice the `// ==UserScript== … // ==/UserScript==` metadata block out of
    /// the script source for `GM_info.scriptMetaStr`.
    var userScriptMetaBlock: String? {
        guard let start = range(of: "// ==UserScript=="),
              let end = range(of: "// ==/UserScript==") else { return nil }
        return String(self[start.lowerBound..<end.upperBound])
    }
}

private extension JSONValue {
    /// Convert a raw value decoded from the JS message body (an `NSNumber`,
    /// `String`, array, dictionary, or `NSNull`) into the engine's `JSONValue`
    /// so `GMStore` can persist it. Unrecognized values become `.null`.
    init(fromAny value: Any?) {
        switch value {
        case nil, is NSNull:
            self = .null
        case let b as Bool where Self.isBoolean(value):
            self = .bool(b)
        case let n as NSNumber:
            if Self.isBoolean(n) {
                self = .bool(n.boolValue)
            } else {
                self = .number(n.doubleValue)
            }
        case let s as String:
            self = .string(s)
        case let d as Double:
            self = .number(d)
        case let i as Int:
            self = .number(Double(i))
        case let arr as [Any]:
            self = .array(arr.map { JSONValue(fromAny: $0) })
        case let obj as [String: Any]:
            var out: [String: JSONValue] = [:]
            for (k, v) in obj { out[k] = JSONValue(fromAny: v) }
            self = .object(out)
        default:
            self = .null
        }
    }

    /// `WKWebView` bridges JS booleans as `NSNumber` backed by `CFBoolean`;
    /// distinguish those from numeric `NSNumber`s so `true` doesn't become `1`.
    private static func isBoolean(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

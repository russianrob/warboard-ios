import Foundation
import WebKit

/// Runs the extension's `background.js` (inlined to a plain script as
/// `_background.js`) in a hidden, retained `WKWebView` whose origin is
/// `webext://retorn` (so the bootstrap's `getURL('files/...')` default fetches
/// are same-origin). The shim + fetch-proxy + background script are injected at
/// document-start; `dispatch(_:)` relays a content-script message into the
/// background's `onMessage` handlers and returns the reply.
final class ExtBackgroundHost: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private let id: String
    private let relay: ExtMessageRelay
    private var version: String
    private let storage: ExtStorage
    private var isReady = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    init(id: String, relay: ExtMessageRelay, version: String, storage: ExtStorage) {
        self.id = id
        self.relay = relay
        self.version = version
        self.storage = storage
        super.init()
    }

    func start() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: ExtResourceScheme.scheme)
        relay.register(on: config.userContentController, world: .page)

        let head = "window.__webext_id=\(jsString(id));window.__webext_version=\(jsString(version));"
        config.userContentController.addUserScript(docStart(head + WebExtShimJS.source))
        config.userContentController.addUserScript(docStart(WebExtBgFetchJS.source))
        if let bg = bundled("_background.js") {
            config.userContentController.addUserScript(docStart(bg))
        }

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        webView = wv
        if let url = URL(string: "\(ExtResourceScheme.scheme)://\(id)/_bg.html") {
            wv.load(URLRequest(url: url))
        }
    }

    /// Update the version used by `maybeFireInstalled` (so a hot-swap fires
    /// `onInstalled(update)` and the extension migrates). Call before `restart()`.
    func updateVersion(_ v: String) { version = v }

    /// Tear down the hidden bg webview and start a fresh one — reloads
    /// `_background.js` from the (now-updated) cache. Safe if never started.
    @MainActor
    func restart() {
        webView?.navigationDelegate = nil
        webView = nil
        isReady = false
        start()
    }

    /// Run the background's onMessage handlers for `message` and return the reply.
    /// `@MainActor` so the WKWebView call runs on the main thread — without it this
    /// non-isolated async func can resume off-main, and calling WKWebView off the
    /// main thread crashes hard (the original open/set_api crashes).
    @MainActor
    func dispatch(_ message: Any, sender: [String: Any]) async -> Any? {
        await waitReady()
        guard let wv = webView else { return nil }
        let name = (message as? [String: Any])?["name"] as? String ?? "?"
        ExtCrashDiag.breadcrumb("dispatch:call:\(name)")
        do {
            let result = try await wv.callAsyncJavaScript(
                "return await window.__webext_handleMessage(m, s);",
                arguments: ["m": message, "s": sender],
                in: nil,
                contentWorld: .page)
            ExtCrashDiag.breadcrumb("dispatch:ret:\(name)")
            // An NSNull/empty reply means the bg's onMessage produced no response
            // — ReTorn then crashes on `r.status`. Log which message hit it.
            if result is NSNull {
                WebDiag.log("webext-dispatch-null", ["id": id, "name": name, "ready": isReady])
            }
            return result
        } catch {
            ExtCrashDiag.breadcrumb("dispatch:err:\(name)")
            WebDiag.log("webext-dispatch-throw", ["id": id, "name": name, "error": "\(error)"])
            return nil
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for w in waiters { w.resume() }
        maybeFireInstalled()
        fireStartup()
        logHealth(webView)
    }

    /// The hidden bg webview runs in its own content process; if it crashes
    /// (memory, a JS fault) every later dispatch returns nil and ReTorn breaks
    /// on `r.status`. Reload it so it recovers on the next message.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isReady = false
        WebDiag.log("webext-bg-terminated", ["id": id])
        if let url = URL(string: "\(ExtResourceScheme.scheme)://\(id)/_bg.html") {
            webView.load(URLRequest(url: url))
        }
    }

    /// One-shot probe after load: is the runtime actually live in the bg host
    /// (shim + handleMessage present, _background.js's onMessage listener
    /// registered)? Pinpoints a broken/undefined reply path.
    private func logHealth(_ webView: WKWebView) {
        let probe = """
        return JSON.stringify({
          browser: !!window.browser,
          handleMessage: typeof window.__webext_handleMessage,
          listeners: (window.__webext_listenerCount ? window.__webext_listenerCount() : -1)
        });
        """
        Task { @MainActor in
            if let value = try? await webView.callAsyncJavaScript(
                probe, arguments: [:], in: nil, contentWorld: .page),
               let json = value as? String {
                WebDiag.log("webext-bg-health", ["id": self.id, "state": json])
            }
        }
    }

    /// Fire ReTorn's `onInstalled` on first run / version change so its
    /// `newInstallation()` seeds default settings + features into storage.
    /// Without this the `features` object is never populated and every ReTorn
    /// feature silently no-ops (`features?.pages...enabled` is undefined).
    private func maybeFireInstalled() {
        let stored = storage.storedVersion
        var details: [String: Any] = [:]
        if stored == nil {
            details["reason"] = "install"
        } else if stored != version {
            details["reason"] = "update"
            details["previousVersion"] = stored!
        } else {
            return
        }
        storage.storedVersion = version
        ExtCrashDiag.breadcrumb("fireInstalled:\((details["reason"] as? String) ?? "")")
        Task { @MainActor [weak self] in
            guard let wv = self?.webView else { return }
            _ = try? await wv.callAsyncJavaScript(
                "window.__webext_fireInstalled(d);",
                arguments: ["d": details], in: nil, contentWorld: .page)
        }
    }

    /// Fire `runtime.onStartup` on EVERY background boot. wxt extensions
    /// (TornTools) run their storage migration/seed from `onStartup` →
    /// `migrateDatabase()` → seeds defaults when storage is empty. This is the
    /// robust seed path: unlike the one-time `onInstalled`, it can't be burned
    /// by a prior boot that aborted before registering the install listener.
    private func fireStartup() {
        Task { @MainActor [weak self] in
            guard let self, let wv = self.webView else { return }
            let result = try? await wv.callAsyncJavaScript(
                "return (window.__webext_fireStartup ? window.__webext_fireStartup() : -1);",
                arguments: [:], in: nil, contentWorld: .page)
            WebDiag.log("webext-fire-startup", ["id": self.id, "listeners": (result as? Int) ?? -1])
        }
    }

    /// Emit `runtime.alarms.onAlarm` for `name` into the bg world. Driven by
    /// `ExtMessageRelay`'s per-alarm timers — this is the extension's recurring
    /// trigger (e.g. TornTools' data-update alarm → `timedUpdates()` →
    /// `updateUserdata()`). A nil web view (bg torn down) is a safe no-op.
    func fireAlarm(name: String) {
        Task { @MainActor [weak self] in
            guard let self, let wv = self.webView else { return }
            _ = try? await wv.callAsyncJavaScript(
                "window.__webext_emit && window.__webext_emit('alarm', { name: n });",
                arguments: ["n": name], in: nil, contentWorld: .page)
        }
    }

    /// Emit `storage.onChanged` into the bg world so background-side listeners
    /// react live (mirrors the content-world push in ExtensionRuntime).
    func fireStorageChanged(area: String, changes: [String: [String: Any]]) {
        let json = (try? JSONSerialization.data(withJSONObject: changes))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        Task { @MainActor [weak self] in
            guard let self, let wv = self.webView else { return }
            _ = try? await wv.callAsyncJavaScript(
                "window.__webext_emit && window.__webext_emit('storageChanged', JSON.parse(c), a);",
                arguments: ["c": json, "a": area], in: nil, contentWorld: .page)
        }
    }

    // MARK: - helpers

    private func waitReady() async {
        if isReady { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            readyWaiters.append(cont)
        }
    }

    private func docStart(_ source: String) -> WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private func jsString(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escaped)'"
    }

    private func bundled(_ name: String) -> String? {
        let base = RemoteExtStore.shared.containerBase(for: id)
        guard let data = try? Data(contentsOf: base.appendingPathComponent("\(id)/\(name)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}

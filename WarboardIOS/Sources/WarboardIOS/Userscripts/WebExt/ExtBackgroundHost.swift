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
    private let relay: ExtMessageRelay
    private let version: String
    private var isReady = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    init(relay: ExtMessageRelay, version: String) {
        self.relay = relay
        self.version = version
        super.init()
    }

    func start() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: ExtResourceScheme.scheme)
        relay.register(on: config.userContentController, world: .page)

        let head = "window.__webext_version=\(jsString(version));"
        config.userContentController.addUserScript(docStart(head + WebExtShimJS.source))
        config.userContentController.addUserScript(docStart(WebExtBgFetchJS.source))
        if let bg = Self.bundled("_background.js") {
            config.userContentController.addUserScript(docStart(bg))
        }

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        webView = wv
        if let url = URL(string: "\(ExtResourceScheme.scheme)://retorn/_bg.html") {
            wv.load(URLRequest(url: url))
        }
    }

    /// Run the background's onMessage handlers for `message` and return the reply.
    func dispatch(_ message: Any, sender: [String: Any]) async -> Any? {
        await waitReady()
        guard let wv = webView else { return nil }
        do {
            return try await wv.callAsyncJavaScript(
                "return await window.__webext_handleMessage(m, s);",
                arguments: ["m": message, "s": sender],
                in: nil,
                contentWorld: .page)
        } catch {
            return nil
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for w in waiters { w.resume() }
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

    static func bundled(_ name: String) -> String? {
        guard let base = Bundle.main.resourceURL,
              let data = try? Data(contentsOf: base.appendingPathComponent("retorn/\(name)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}

import SwiftUI
#if canImport(WebKit)
import WebKit

/// SwiftUI wrapper around `WKWebView` that hosts torn.com, persists
/// cookies (so login survives app restarts), and runs the bundled
/// userscripts on every page load. The `request` is exposed as a
/// `Binding` so the parent view can navigate the WebView from outside
/// (e.g. a notification deep-link tap).
struct TornWebView: UIViewRepresentable {

    /// Current URL the parent wants the WebView to be at. Changing
    /// this binding triggers a load on the next updateUIView pass.
    @Binding var url: URL

    /// Reports the actually-loaded URL back to the parent so it can
    /// remember the last screen across app restarts.
    var onNavigate: ((URL) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Inject the GM_* shim at document start so userscripts find it
        // ready when they run. Page-script-injection-time is critical
        // here — at-document-end the shim might race with userscripts
        // that auto-execute on early DOM events.
        if let shim = Bundle.module.url(forResource: "gm-shim", withExtension: "js"),
           let shimSrc = try? String(contentsOf: shim, encoding: .utf8) {
            let userScript = WKUserScript(
                source: shimSrc,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
            )
            config.userContentController.addUserScript(userScript)
        }
        // Match Safari-on-iOS so Torn doesn't serve a stripped-down
        // mobile layout the userscripts don't expect.
        config.applicationNameForUserAgent = "Mobile/15E148 Safari/604.1"
        // Persistent data store keeps cookies + localStorage across
        // app launches → no re-login between sessions.
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true

        webView.load(URLRequest(url: url))
        context.coordinator.lastLoadedUrl = url
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if the parent asked for a different URL than the
        // one we last loaded — prevents unwanted reloads on every
        // SwiftUI re-render.
        if context.coordinator.lastLoadedUrl != url {
            webView.load(URLRequest(url: url))
            context.coordinator.lastLoadedUrl = url
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TornWebView
        var lastLoadedUrl: URL?

        init(parent: TornWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            UserscriptManager.injectMatching(into: webView, currentUrl: url.absoluteString)
            parent.onNavigate?(url)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void,
        ) {
            // Keep Torn navigation in the WebView; everything else
            // (third-party links the user taps) hands off to Safari.
            if let host = navigationAction.request.url?.host,
               !host.hasSuffix("torn.com") {
                if let target = navigationAction.request.url {
                    UIApplication.shared.open(target)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif

import SwiftUI
import WebKit

/// Embedded WKWebView pointed at torn.com for the Chat sub-tab.
///
/// Cookies + DOM storage persist via the default `WKWebsiteDataStore`,
/// so the user logs into Torn **once** inside the app and the session
/// survives app restarts thereafter. Note that this is a SEPARATE
/// cookie jar from Safari / SFSafariViewController — first visit shows
/// Torn's login page even if the user is already logged in via Safari.
/// After in-app login, subsequent visits land on the faction page with
/// chat ready in Torn's right-side panel.
///
/// The WebView is recreated each time the user switches into the Chat
/// tab (SwiftUI tears down the case body on subTab change). Login
/// state survives because cookies are persisted; scroll position and
/// any in-flight chat draft do not — accepted trade-off for keeping
/// the implementation simple. To preserve in-tab state across sub-tab
/// switches, hoist `WebViewHolder` up to `WarRoomView` and pass the
/// shared `WKWebView` down.
struct TornChatWebView: View {
    var body: some View {
        // No .ignoresSafeArea — letting SwiftUI inset for the home
        // indicator + bottom nav keeps Torn's chat input above the
        // hardware safe-area instead of being clipped by it.
        WKWebViewRepresentable()
    }
}

private struct WKWebViewRepresentable: UIViewRepresentable {
    private let url = URL(string: "https://www.torn.com/index.php")!

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()        // persistent cookies + storage
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.uiDelegate = context.coordinator         // make target=_blank links work
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Torn's chat links (profiles, items) open with `target="_blank"` /
    /// `window.open`. Without a WKUIDelegate the WebView drops those, so the
    /// links look unclickable. Load them in this same view instead.
    final class Coordinator: NSObject, WKUIDelegate {
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.request.url != nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

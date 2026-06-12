import SwiftUI
import WebKit

/// Renders a visible ReTorn extension page (options / popup) from
/// `webext://retorn/<page>` in a WKWebView wired to the runtime's shim + relay,
/// so the page's `browser.storage`/`sendMessage` calls hit the same storage and
/// background host as the rest of the runtime. Presented as a full-screen sheet
/// by the app; supplies its own Done button (matches WarRoomView/ManagerView).
public struct ExtPageView: View {
    @Environment(\.dismiss) private var dismiss
    private let page: String
    private let title: String

    /// - Parameters:
    ///   - page: bundle-relative page path, e.g. `"pages/options.html"`.
    ///   - title: navigation bar title.
    public init(page: String, title: String) {
        self.page = page
        self.title = title
    }

    public var body: some View {
        ExtPageWebView(page: page)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
    }
}

private struct ExtPageWebView: UIViewRepresentable {
    let page: String

    func makeUIView(context: Context) -> WKWebView {
        let config = ExtensionRuntime.shared.makeExtensionPageConfig()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        if let url = URL(string: "\(ExtResourceScheme.scheme)://retorn/\(page)") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

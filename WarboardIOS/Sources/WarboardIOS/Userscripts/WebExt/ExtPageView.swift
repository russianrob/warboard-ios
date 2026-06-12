import SwiftUI
import WebKit

/// Renders a visible extension page (options / popup) from
/// `webext://<extId>/<page>` in a WKWebView wired to THAT extension's shim +
/// relay + storage, so the page's `browser.storage`/`sendMessage` calls hit the
/// same storage and background host as the rest of the runtime. Presented as a
/// full-screen sheet by the app; supplies its own Done button.
public struct ExtPageView: View {
    @Environment(\.dismiss) private var dismiss
    private let extId: String
    private let page: String
    private let title: String

    /// - Parameters:
    ///   - extId: the bundled extension id (resource folder / `webext://` host).
    ///   - page: bundle-relative page path, e.g. `"options.html"`.
    ///   - title: navigation bar title.
    public init(extId: String, page: String, title: String) {
        self.extId = extId
        self.page = page
        self.title = title
    }

    public var body: some View {
        ExtPageWebView(extId: extId, page: page)
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
    let extId: String
    let page: String

    func makeUIView(context: Context) -> WKWebView {
        let config = ExtensionRuntime.shared.makeExtensionPageConfig(for: extId)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        if let url = URL(string: "\(ExtResourceScheme.scheme)://\(extId)/\(page)") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

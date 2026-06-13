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

    func makeCoordinator() -> Coordinator { Coordinator(extId: extId) }

    func makeUIView(context: Context) -> WKWebView {
        let config = ExtensionRuntime.shared.makeExtensionPageConfig(for: extId)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.attach(webView)
        if let url = URL(string: "\(ExtResourceScheme.scheme)://\(extId)/\(page)") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Bridges native `storage.onChanged` into THIS options/popup page's `.page`
    /// world (where `makeExtensionPageConfig` injected the shim + relay) so the
    /// page's own onChanged listeners fire and its reactive controls update live
    /// after a write — without this an options-page setting saves but the control
    /// snaps back until a reload. Mirrors `UserscriptController`'s Torn-page push.
    final class Coordinator {
        private let extId: String
        private weak var webView: WKWebView?
        init(extId: String) { self.extId = extId }

        @MainActor func attach(_ wv: WKWebView) {
            webView = wv
            ExtensionRuntime.shared.pushStorageChangedToExtPage = { [weak self] eid, area, changes in
                guard let self, eid == self.extId else { return }
                let json = (try? JSONSerialization.data(withJSONObject: changes))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                Task { @MainActor [weak self] in
                    guard let self, let wv = self.webView else { return }
                    _ = try? await wv.callAsyncJavaScript(
                        "window.__webext_emit && window.__webext_emit('storageChanged', JSON.parse(c), a);",
                        arguments: ["c": json, "a": area], in: nil, contentWorld: .page)
                }
            }
        }

        // Drop our web view ref so any still-registered closure no-ops. We do not
        // null the shared hook (a re-presented page overwrites it on attach), so a
        // reopen race can't clear the new page's hook.
        @MainActor func detach() { webView = nil }
    }
}

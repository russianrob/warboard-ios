import SwiftUI
import WebKit

/// Observable navigation state for the in-app userscript browser.
/// Holds the live WKWebView so the SwiftUI URL bar + toolbar can drive
/// it, and mirrors the bits the chrome renders (URL text, progress,
/// canGoBack/Forward). The WKWebView itself is created in the
/// representable's makeUIView and handed back here via `attach`.
@MainActor
final class BrowserModel: ObservableObject {
    @Published var urlText: String = "https://www.torn.com/index.php"
    @Published var displayURL: String = ""
    @Published var progress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    /// Set once the representable builds the WebView.
    weak var webView: WKWebView?

    /// Pending load requested before the WebView existed (tab not yet
    /// mounted). Drained in `attach`.
    private var pendingLoad: URL?

    func attach(_ wv: WKWebView) {
        webView = wv
        if let url = pendingLoad {
            pendingLoad = nil
            wv.load(URLRequest(url: url))
        } else if wv.url == nil {
            wv.load(URLRequest(url: URL(string: urlText)!))
        }
    }

    /// Navigate to whatever is in `urlText`, coercing a bare host/path
    /// into an https URL. Non-URL search terms are out of scope — we
    /// only accept explicit URLs here.
    func go() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized) else { return }
        load(url)
    }

    func load(_ url: URL) {
        if let wv = webView {
            wv.load(URLRequest(url: url))
        } else {
            pendingLoad = url
        }
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }

    func reload() {
        guard let wv = webView else { return }
        if isLoading { wv.stopLoading() } else { wv.reload() }
    }
}

/// Bridges the WKWebView into SwiftUI and wires the UserscriptController
/// so the engine rebuilds the injected WKUserScript set on every
/// navigation. Generalizes WKWebViewRepresentable from
/// TornChatWebView.swift to a navigable, script-hosting browser.
private struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    let controller: UserscriptController

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        // The controller owns the WKWebViewConfiguration: it installs the GM
        // message handlers once and is the WKNavigationDelegate (its
        // decidePolicyFor rebuilds the per-page user scripts before each load).
        let wv = controller.makeWebView()

        // Observe nav state via KVO so the SwiftUI chrome (URL bar, progress,
        // back/forward) reflects the live web view without stealing the
        // controller's navigation delegate.
        context.coordinator.observe(wv)

        model.attach(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// KVO-observes the web view's navigation properties and pushes them onto
    /// the BrowserModel for the SwiftUI chrome to render.
    final class Coordinator: NSObject {
        let model: BrowserModel
        private var observations: [NSKeyValueObservation] = []
        init(model: BrowserModel) { self.model = model }

        func observe(_ wv: WKWebView) {
            observations = [
                wv.observe(\.url, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in
                        model?.displayURL = w.url?.absoluteString ?? ""
                        if let s = w.url?.absoluteString { model?.urlText = s }
                    }
                },
                wv.observe(\.estimatedProgress, options: [.new]) { [weak model] w, _ in
                    Task { @MainActor in model?.progress = w.estimatedProgress }
                },
                wv.observe(\.isLoading, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in model?.isLoading = w.isLoading }
                },
                wv.observe(\.canGoBack, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in model?.canGoBack = w.canGoBack }
                },
                wv.observe(\.canGoForward, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in model?.canGoForward = w.canGoForward }
                },
            ]
        }

        func stop() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
        }
    }
}

/// The Browser tab: a navigable WKWebView with a URL bar, back/forward/
/// reload, and a determinate progress bar, hosting the userscript engine.
public struct BrowserView: View {
    public init() {}
    @StateObject private var model = BrowserModel()

    /// One controller instance per Browser tab, built from the default
    /// registry/cache/bridge so installs from the Scripts tab take effect on
    /// the next navigation. Observed directly so its published `menuCommands`
    /// drive the URL-bar menu.
    @StateObject private var controller = UserscriptController()

    public var body: some View {
        VStack(spacing: 0) {
            urlBar
            progressBar
            BrowserWebView(model: model, controller: controller)
        }
        .navigationTitle("Browser")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $controller.pendingInstall) { item in
            InstallScriptView(url: item.url) { controller.pendingInstall = nil }
        }
    }

    private var urlBar: some View {
        HStack(spacing: 10) {
            Button(action: model.goBack) { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack)
            Button(action: model.goForward) { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward)

            TextField("URL", text: $model.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { model.go() }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: model.reload) {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }

            // Per-page script actions (GM_registerMenuCommand). The
            // controller publishes the live command list for the current
            // page; the menu invokes them by id back through the bridge.
            Menu {
                if controller.menuCommands.isEmpty {
                    Text("No script actions").foregroundStyle(.secondary)
                }
                ForEach(controller.menuCommands) { cmd in
                    Button(cmd.label) { controller.invokeMenuCommand(cmd.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder private var progressBar: some View {
        if model.isLoading {
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
                .frame(height: 2)
        } else {
            Color.clear.frame(height: 2)
        }
    }
}

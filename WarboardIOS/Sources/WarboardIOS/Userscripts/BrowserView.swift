import SwiftUI
import WebKit
import UIKit

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

    /// Whether the URL bar is showing. Driven by scroll direction (Safari
    /// style): hidden while scrolling down into the page, revealed on scroll
    /// up, at the top, or when a new page starts loading.
    @Published var chromeVisible: Bool = true

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

    // Auto-hide bookkeeping (main-actor isolated, so the KVO handler just
    // forwards the raw offset here).
    private var lastOffsetY: CGFloat = 0
    private var scrollAccum: CGFloat = 0
    private let hideThreshold: CGFloat = 28

    /// Fold a new scroll offset into the show/hide decision for the URL bar.
    /// Same-direction travel accumulates; the bar only flips once it clears
    /// the threshold, so a few stray pixels (or rubber-banding) don't toggle
    /// it. Pinned at the top always shows.
    func updateScroll(offsetY y: CGFloat) {
        let dy = y - lastOffsetY
        lastOffsetY = y
        var desired: Bool?
        if y <= 0 {
            desired = true
            scrollAccum = 0
        } else {
            if (dy > 0) == (scrollAccum >= 0) { scrollAccum += dy } else { scrollAccum = dy }
            if scrollAccum > hideThreshold { desired = false; scrollAccum = 0 }
            else if scrollAccum < -hideThreshold { desired = true; scrollAccum = 0 }
        }
        if let d = desired, chromeVisible != d { chromeVisible = d }
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

        // Pull-to-refresh on the page itself (Safari-style). The coordinator
        // ends the spinner when isLoading drops back to false.
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        wv.scrollView.refreshControl = refresh
        context.coordinator.refreshControl = refresh

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
        weak var refreshControl: UIRefreshControl?
        init(model: BrowserModel) { self.model = model }

        @objc func handleRefresh() {
            Task { @MainActor in model.reload() }
        }

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
                wv.observe(\.isLoading, options: [.initial, .new]) { [weak self, weak model] w, _ in
                    Task { @MainActor in
                        model?.isLoading = w.isLoading
                        // Always surface the bar when a new page starts so the
                        // user can see/redirect where they're going.
                        if w.isLoading { model?.chromeVisible = true }
                        else { self?.refreshControl?.endRefreshing() }
                    }
                },
                wv.observe(\.canGoBack, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in model?.canGoBack = w.canGoBack }
                },
                wv.observe(\.canGoForward, options: [.initial, .new]) { [weak model] w, _ in
                    Task { @MainActor in model?.canGoForward = w.canGoForward }
                },
                wv.scrollView.observe(\.contentOffset, options: [.new]) { [weak model] sv, _ in
                    let y = sv.contentOffset.y
                    Task { @MainActor in model?.updateScroll(offsetY: y) }
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
    /// Invoked when the user taps "Notifications…" in the page menu. The app
    /// shell wires this to its Notifications settings screen — the screen
    /// lives in the app target (it needs PrefsStore), which this framework
    /// can't import, so it comes in as a closure.
    private let onShowNotifications: (() -> Void)?
    public init(onShowNotifications: (() -> Void)? = nil) {
        self.onShowNotifications = onShowNotifications
    }
    @StateObject private var model = BrowserModel()
    @State private var showScripts = false

    /// One controller per Browser tab. It reads the shared ScriptRegistry, so a
    /// script installed from the Scripts screen or the in-browser installer is
    /// picked up on the next page build; the `.userscriptsDidChange` observer
    /// below reloads the current page so it applies without navigating or
    /// relaunching. Observed directly so its published `menuCommands` drive the
    /// URL-bar menu.
    @StateObject private var controller = UserscriptController()

    public var body: some View {
        VStack(spacing: 0) {
            if model.chromeVisible {
                VStack(spacing: 0) {
                    urlBar
                    progressBar
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            BrowserWebView(model: model, controller: controller)
        }
        .animation(.easeInOut(duration: 0.22), value: model.chromeVisible)
        .sheet(isPresented: $showScripts) {
            NavigationStack { ScriptsView() }
        }
        .sheet(item: $controller.pendingInstall) { item in
            InstallScriptView(url: item.url) { controller.pendingInstall = nil }
        }
        // A newly installed/enabled/removed script changes the shared registry;
        // reload the live page so the next page build re-applies the script set
        // immediately, instead of only on the next manual navigation.
        .onReceive(
            NotificationCenter.default.publisher(for: .userscriptsDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            model.reload()
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

            // App actions + per-page script actions (GM_registerMenuCommand).
            // The controller publishes the live command list for the current
            // page; the menu invokes them by id back through the bridge.
            Menu {
                if let onShowNotifications {
                    Button { onShowNotifications() } label: {
                        Label("Notifications…", systemImage: "bell")
                    }
                }
                Button { controller.toggleDevTools() } label: {
                    Label(controller.devToolsEnabled ? "Dev Tools: On" : "Dev Tools",
                          systemImage: controller.devToolsEnabled ? "ladybug.fill" : "ladybug")
                }
                Divider()
                if controller.menuCommands.isEmpty {
                    Text("No script actions").foregroundStyle(.secondary)
                }
                ForEach(controller.menuCommands) { cmd in
                    Button(cmd.label) { controller.invokeMenuCommand(cmd.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }

            // Manage installed userscripts (moved here from the old top bar so
            // the web view gets that whole row back).
            Button { showScripts = true } label: {
                Image(systemName: "doc.text.fill")
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

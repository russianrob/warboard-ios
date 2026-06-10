import Foundation
import WebKit

/// Owns the WKWebView configuration and rebuilds the injected user-script set
/// on every navigation (Approach 1). Pure ordering/selection is delegated to
/// `UserscriptInjectionPlanner`; this type only does the WebKit wiring.
@MainActor
final class UserscriptController: NSObject, ObservableObject {

    /// A GM_registerMenuCommand entry the SwiftUI chrome renders. `id` matches
    /// the JS-side menu index so `invokeMenuCommand(_:)` can call back through
    /// `window.__wbInvokeMenuCommand`.
    struct MenuCommand: Identifiable, Equatable {
        let id: Int
        let label: String
    }

    /// Live menu commands the current page's scripts have registered. Reset on
    /// each navigation rebuild; published so the URL-bar menu re-renders.
    @Published private(set) var menuCommands: [MenuCommand] = []

    private let registry: ScriptRegistry
    private let requireCache: RequireCache
    private let gmBridge: GMBridge

    /// The web view this controller drives. Set in `makeWebView`; used to call
    /// menu-command callbacks back into the page.
    private weak var webView: WKWebView?

    /// Built once; handed to the WKWebView. We mutate its
    /// userContentController per navigation.
    let configuration: WKWebViewConfiguration

    private var userContent: WKUserContentController {
        configuration.userContentController
    }

    init(registry: ScriptRegistry, requireCache: RequireCache, gmBridge: GMBridge) {
        self.registry = registry
        self.requireCache = requireCache
        self.gmBridge = gmBridge

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // share Torn login cookie jar
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.configuration = config
        super.init()

        // GM message handlers are registered ONCE (they outlive navigations);
        // only user scripts are torn down/rebuilt per navigation.
        gmBridge.register(on: config.userContentController)

        // GM_registerMenuCommand → surface the command in the chrome menu.
        gmBridge.onRegisterMenuCommand = { [weak self] _, name, id in
            Task { @MainActor in self?.addMenuCommand(name: name, id: id) }
        }
    }

    /// Convenience for SwiftUI hosts: build a controller from the default,
    /// process-wide registry/cache/bridge dependencies.
    override convenience init() {
        self.init(registry: ScriptRegistry(),
                  requireCache: RequireCache(root: RequireCache.defaultRoot()),
                  gmBridge: GMBridge())
    }

    private func addMenuCommand(name: String, id: Int) {
        menuCommands.removeAll { $0.id == id }
        menuCommands.append(MenuCommand(id: id, label: name))
    }

    /// Invoke a script's registered menu command by id (calls the JS hook the
    /// bootstrap installs as `window.__wbInvokeMenuCommand`).
    func invokeMenuCommand(_ id: Int) {
        webView?.evaluateJavaScript("window.__wbInvokeMenuCommand(\(id))",
                                    completionHandler: nil)
    }

    /// Maps the planner's platform-free timing to WebKit's enum.
    private func injectionTime(_ t: InjectionTiming) -> WKUserScriptInjectionTime {
        switch t {
        case .documentStart: return .atDocumentStart
        case .documentEnd:   return .atDocumentEnd
        }
    }

    /// Rebuild the WKUserScript set for `url`. Called from
    /// decidePolicyFor BEFORE allowing the navigation, so WebKit applies the
    /// new scripts to the page about to load.
    func rebuildUserScripts(for url: URL) {
        // New page → the previous page's menu commands no longer apply.
        menuCommands.removeAll()

        // 1. Enabled scripts whose @match/@include match and aren't @excluded,
        //    in install order. Selection lives in the registry (MatchMatcher).
        let scripts = registry.enabledScripts(matching: url)

        // 2. Resolve @require sources from the on-disk cache. A cache miss means
        //    the lib isn't available; the planner drops that script's body.
        var requireSources: [String: String] = [:]
        for script in scripts {
            for req in script.requires where requireSources[req] == nil {
                if let src = requireCache.read(forURL: req) {
                    requireSources[req] = src
                }
            }
        }

        // 3. The GM bootstrap, carrying this navigation's per-script storage
        //    snapshots (sync GM_getValue) + GM_info, built by the bridge.
        let bootstrap = gmBridge.bootstrapSource(for: scripts, url: url)

        // 4. Pure ordering.
        let planned = UserscriptInjectionPlanner.plan(
            for: url,
            scripts: scripts,
            requireSources: requireSources,
            bootstrapSource: bootstrap
        )

        // 5. Apply. removeAllUserScripts clears the PREVIOUS navigation's set;
        //    GM message handlers (registered in init) are untouched.
        userContent.removeAllUserScripts()
        for p in planned {
            let ws = WKUserScript(
                source: p.source,
                injectionTime: injectionTime(p.timing),
                forMainFrameOnly: p.mainFrameOnly,
                in: .page                       // MAIN world: unsafeWindow === window
            )
            userContent.addUserScript(ws)
        }
    }
}

extension UserscriptController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Only main-frame, real-URL navigations trigger a rebuild; subframes
        // and about:blank keep the current set. (Scripts are main-frame-only.)
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.scheme == "https" || url.scheme == "http" {
            rebuildUserScripts(for: url)
        }
        decisionHandler(.allow)
    }
}

extension UserscriptController {
    /// Build the WKWebView the Browser tab displays. The controller is the
    /// navigation delegate (drives the per-navigation rebuild) and must be
    /// retained by the caller for the web view's lifetime.
    func makeWebView() -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        self.webView = wv
        return wv
    }
}

extension UserscriptController: WKUIDelegate {
    /// target=_blank / window.open links (Torn chat profile/item links) open
    /// no window by default in WKWebView — load them in the same view so they
    /// don't look unclickable.
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

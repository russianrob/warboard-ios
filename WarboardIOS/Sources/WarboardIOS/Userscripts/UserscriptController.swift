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

    /// A `.user.js` URL the Browser tab navigated to, captured so SwiftUI can
    /// present the install-confirmation sheet. `Identifiable` drives
    /// `.sheet(item:)`; nil-ed when the sheet is dismissed.
    struct PendingInstall: Identifiable {
        let id = UUID()
        let url: URL
    }

    /// Set when a main-frame navigation targets a `.user.js`; the navigation is
    /// cancelled and BrowserView shows the install sheet instead.
    @Published var pendingInstall: PendingInstall?

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
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        self.configuration = config
        super.init()

        // GM message handlers are registered ONCE (they outlive navigations);
        // only user scripts are torn down/rebuilt per navigation.
        gmBridge.register(on: config.userContentController)

        // Link-tap diagnostics: a capture-phase click probe reports every
        // anchor tap to native, where WebDiag forwards it to the warboard
        // log stream. Registered ONCE alongside the GM handlers.
        WebDiagBridge.install(on: config.userContentController)

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
        //    GM message handlers (registered in init) are untouched. The
        //    click-probe is a user script too, so re-add it after the wipe.
        userContent.removeAllUserScripts()
        userContent.addUserScript(WebDiagBridge.probeUserScript())
        userContent.addUserScript(Self.linkFixerUserScript())
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

    /// Torn intercepts `target="_blank"` link clicks before WebKit can open a
    /// new window, so those links do nothing in a single-web-view browser.
    /// This capture-phase listener opens them in-place instead. Re-injected
    /// every navigation (it's cleared by removeAllUserScripts above).
    private static func linkFixerUserScript() -> WKUserScript {
        let src = """
        (function () {
          if (window.__wbLinkFixer) return;
          window.__wbLinkFixer = true;
          document.addEventListener('click', function (e) {
            var t = e.target;
            var a = (t && t.closest) ? t.closest('a[target="_blank"]') : null;
            if (a && a.href && /^https?:/i.test(a.href)) {
              e.preventDefault();
              window.location.assign(a.href);
            }
          }, true);
        })();
        """
        return WKUserScript(source: src, injectionTime: .atDocumentStart,
                            forMainFrameOnly: false, in: .page)
    }
}

extension UserscriptController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            WebDiag.log("nav", [
                "url": url.absoluteString,
                "type": navigationAction.navigationType.rawValue,
                "mainFrame": navigationAction.targetFrame?.isMainFrame ?? false,
            ])
        }

        // A main-frame hit on a `.user.js` is an install request, not a page to
        // render: cancel the load and hand the URL to the install sheet. Done
        // before the rebuild so the cancelled nav never re-plans scripts.
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.path.lowercased().hasSuffix(".user.js") {
            decisionHandler(.cancel)
            pendingInstall = PendingInstall(url: url)
            return
        }

        // Only main-frame, real-URL navigations trigger a rebuild; subframes
        // and about:blank keep the current set. (Scripts are main-frame-only.)
        if navigationAction.targetFrame?.isMainFrame == true,
           let url = navigationAction.request.url,
           url.scheme == "https" || url.scheme == "http" {
            rebuildUserScripts(for: url)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebDiag.log("didFinish", ["url": webView.url?.absoluteString ?? "nil"])
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        WebDiag.log("didFail", [
            "url": webView.url?.absoluteString ?? "nil",
            "error": error.localizedDescription,
        ])
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

/// Receives the capture-phase click probe's messages from the page and
/// forwards them to `WebDiag`. A standalone `NSObject` (not the
/// `UserscriptController`) so the plain `WKScriptMessageHandler` retain
/// chain stays separate from the reply-style GM bridge. Registered ONCE
/// in `.page` alongside the GM handlers.
final class WebDiagBridge: NSObject, WKScriptMessageHandler {
    static let messageHandlerName = "wbdiag"

    /// Capture-phase document click listener. Resolves the clicked element's
    /// nearest `<a>` and posts its href/target/class to native; reports
    /// `noAnchor` when the tap didn't land inside a link. mainFrameOnly:false
    /// so taps in Torn's iframes (chat panel) are captured too.
    private static let probeSource = """
    (function () {
      document.addEventListener('click', function (e) {
        try {
          var tag = (e.target && e.target.tagName) ? String(e.target.tagName) : '';
          var a = e.target && e.target.closest ? e.target.closest('a') : null;
          if (a) {
            window.webkit.messageHandlers.wbdiag.postMessage({
              href: a.href || '',
              target: a.target || '',
              cls: a.className ? String(a.className) : '',
              prevented: false,
              tag: tag
            });
          } else {
            window.webkit.messageHandlers.wbdiag.postMessage({ noAnchor: true, tag: tag });
          }
        } catch (err) {}
      }, true);
    })();
    """

    /// The capture-phase click-probe user script. Re-added by
    /// `UserscriptController.rebuildUserScripts` after every
    /// `removeAllUserScripts()`, since that call also clears this probe.
    static func probeUserScript() -> WKUserScript {
        WKUserScript(
            source: probeSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false,
            in: .page
        )
    }

    /// Install the receiving message handler and the initial click probe.
    /// The handler outlives per-navigation rebuilds; the probe is re-added
    /// on each rebuild via `probeUserScript()`.
    static func install(on userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(
            forName: messageHandlerName, contentWorld: .page)
        let bridge = WebDiagBridge()
        userContentController.add(bridge, contentWorld: .page, name: messageHandlerName)
        userContentController.addUserScript(probeUserScript())
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        WebDiag.log("click", body)
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
        WebDiag.log("newwindow", ["url": navigationAction.request.url?.absoluteString ?? "nil"])
        if navigationAction.request.url != nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

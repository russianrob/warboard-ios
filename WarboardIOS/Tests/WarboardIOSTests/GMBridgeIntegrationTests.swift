import XCTest
@testable import WarboardIOS

#if canImport(WebKit)
import WebKit

/// Mac-only: exercises the real bootstrap + GMBridge through a WKWebView.
/// Cannot run on the Linux CI box (no WebKit); runs on macOS via xcodebuild test.
final class GMBridgeIntegrationTests: XCTestCase {

    private func makeWebView(bridge: GMBridge,
                             bootstrapSource: String) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let ucc = cfg.userContentController
        ucc.addScriptMessageHandler(bridge, contentWorld: .page, name: "gmBridge")
        ucc.addUserScript(WKUserScript(source: bootstrapSource,
                                       injectionTime: .atDocumentStart,
                                       forMainFrameOnly: true,
                                       in: .page))
        return WKWebView(frame: .zero, configuration: cfg)
    }

    /// Minimal `Userscript` test factory — the committed model has no
    /// `.fixture(id:)`, so build one inline with the real 20-field init.
    private func fixture(id: String) -> Userscript {
        Userscript(
            id: id,
            name: id,
            namespace: nil,
            version: "1.0",
            description: nil,
            matches: [],
            includes: [],
            excludes: [],
            requires: [],
            connects: [],
            grants: ["GM_getValue", "GM_setValue", "unsafeWindow"],
            runAt: .documentStart,
            icon: nil,
            downloadURL: nil,
            updateURL: nil,
            enabled: true,
            order: 0,
            source: "",
            wildcardConnectGranted: false)
    }

    func testSyncSetThenGetRoundTrip() throws {
        let store = GMStore()
        let bridge = GMBridge()
        bridge.activeScripts["smoke"] = .init(scriptID: "smoke",
                                              connects: [],
                                              wildcardConnectGranted: false,
                                              store: store)
        let source = GMBootstrap.source(
            scriptID: "smoke",
            infoJSON: GMBridge.infoJSON(for: fixture(id: "smoke"),
                                        engineVersion: "1.0"),
            snapshotLiteral: GMSnapshot.objectLiteral(from: [:]))
        let web = makeWebView(bridge: bridge, bootstrapSource: source)

        let loaded = expectation(description: "loaded")
        let nav = NavWaiter { loaded.fulfill() }
        web.navigationDelegate = nav
        web.loadHTMLString("<html><body>hi</body></html>",
                           baseURL: URL(string: "https://www.torn.com/"))
        wait(for: [loaded], timeout: 5)

        // GM_setValue then synchronous GM_getValue in the same page.
        let eval = expectation(description: "eval")
        web.evaluateJavaScript(
            "GM_setValue('k', 42); GM_getValue('k', 0)") { result, _ in
            XCTAssertEqual(result as? Int, 42)
            eval.fulfill()
        }
        wait(for: [eval], timeout: 5)
    }

    func testUnsafeWindowIsWindow() throws {
        let bridge = GMBridge()
        bridge.activeScripts["smoke"] = .init(scriptID: "smoke",
                                              connects: [],
                                              wildcardConnectGranted: false,
                                              store: GMStore())
        let source = GMBootstrap.source(scriptID: "smoke", infoJSON: "{}",
                                        snapshotLiteral: "{}")
        let web = makeWebView(bridge: bridge, bootstrapSource: source)
        let loaded = expectation(description: "loaded")
        let nav = NavWaiter { loaded.fulfill() }
        web.navigationDelegate = nav
        web.loadHTMLString("<html><body></body></html>",
                           baseURL: URL(string: "https://www.torn.com/"))
        wait(for: [loaded], timeout: 5)

        let eval = expectation(description: "eval")
        web.evaluateJavaScript("unsafeWindow === window") { result, _ in
            XCTAssertEqual(result as? Bool, true)
            eval.fulfill()
        }
        wait(for: [eval], timeout: 5)
    }

    private final class NavWaiter: NSObject, WKNavigationDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { onFinish() }
    }
}
#endif

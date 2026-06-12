import Foundation
import WebKit

/// Owns the WebExtension runtime: the manifest, the storage, the native message
/// relay, and the hidden background host. `UserscriptController` calls
/// `install(on:)` once (to register the relay + start the background host) and
/// `contentWorldScripts(for:)` per navigation (to inject the shim + ReTorn's
/// matching content scripts into the isolated "retorn" content world).
final class ExtensionRuntime {
    static let shared = ExtensionRuntime()

    private let manifest: ExtManifest?
    private let storage = ExtStorage()
    private let relay: ExtMessageRelay
    private let backgroundHost: ExtBackgroundHost?
    private static let worldName = "retorn"
    /// The one bundled extension's id (the on/off flag key + catalog id).
    static let retornID = "retorn"

    /// A bundled extension, surfaced to the in-app extension manager.
    struct ExtensionInfo: Identifiable {
        let id: String
        let name: String
        let version: String
        let attribution: String
    }

    /// The installed (bundled) extensions, for the Scripts-screen manager.
    var installedExtensions: [ExtensionInfo] {
        guard let manifest = manifest else { return [] }
        return [ExtensionInfo(id: Self.retornID, name: "ReTorn",
                              version: manifest.version, attribution: "Heasleys4hemp")]
    }

    /// `tabs.create` → open a URL in the app browser. Set by the webview host.
    var onOpenURL: ((String) -> Void)? {
        get { relay.onOpenURL }
        set { relay.onOpenURL = newValue }
    }

    /// `runtime.openOptionsPage` (the in-page "Options" button) → present an
    /// extension page in a sheet. Set by the app (ContentView).
    var onOpenExtPage: ((String) -> Void)? {
        get { relay.onOpenExtPage }
        set { relay.onOpenExtPage = newValue }
    }

    /// A WKWebView config for rendering a visible extension page (options /
    /// popup): the webext:// scheme handler + the shared relay (so the page's
    /// `browser.storage`/`sendMessage` hit the same storage + background host)
    /// + the shim and a jscolor stub injected at document-start in the page world.
    func makeExtensionPageConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: ExtResourceScheme.scheme)
        relay.register(on: config.userContentController, world: .page)
        let version = manifest?.version ?? "0"
        let source = "window.__webext_version='\(version)';" + WebExtShimJS.source + ExtPageExtrasJS.source
        config.userContentController.addUserScript(
            WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        return config
    }

    private init() {
        ExtCrashDiag.install()
        let loaded = ExtManifest.loadReTorn()
        manifest = loaded
        relay = ExtMessageRelay(storage: storage)
        if let loaded = loaded {
            let host = ExtBackgroundHost(relay: relay, version: loaded.version, storage: storage)
            backgroundHost = host
            relay.backgroundHost = host
        } else {
            backgroundHost = nil
        }
    }

    /// Register the relay on the main web view's "retorn" world + start the
    /// background host. (The resource scheme is registered by UserscriptController.)
    func install(on config: WKWebViewConfiguration) {
        relay.register(on: config.userContentController, world: WKContentWorld.world(name: Self.worldName))
        // Only spin up the hidden background host (which loads _background.js and
        // fires onInstalled → seeds storage) when the extension is enabled, so a
        // user with ReTorn toggled off gets no background webview or side effects.
        if ExtensionPrefs.shared.isEnabled(Self.retornID) {
            backgroundHost?.start()
        }
    }

    /// Persist an extension's on/off state and reconcile the background host:
    /// enabling starts it (idempotent — `start()` guards against a second webview).
    /// Page injection is gated separately, so disabling just stops re-injection on
    /// the next navigation (the caller reloads the page to apply it immediately).
    func setExtensionEnabled(_ id: String, _ enabled: Bool) {
        ExtensionPrefs.shared.setEnabled(id, enabled)
        if id == Self.retornID, enabled {
            backgroundHost?.start()
        }
    }

    /// Shim + matching content scripts (+ CSS) for `url`, in the "retorn" world.
    /// Returns nothing when the extension is toggled off in the manager.
    func contentWorldScripts(for url: URL) -> [WKUserScript] {
        guard let manifest = manifest, ExtensionPrefs.shared.isEnabled(Self.retornID) else { return [] }
        let world = WKContentWorld.world(name: Self.worldName)
        let urlString = url.absoluteString
        var scripts: [WKUserScript] = []
        var shimInjected = false

        for cs in manifest.contentScripts where matches(urlString, cs) {
            if !shimInjected {
                scripts.append(WKUserScript(
                    source: "window.__webext_version='\(manifest.version)';" + WebExtShimJS.source,
                    injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
                shimInjected = true
            }
            let timing: WKUserScriptInjectionTime =
                (cs.runAt == "document_start") ? .atDocumentStart : .atDocumentEnd
            for cssPath in cs.css ?? [] {
                if let css = Self.bundledText(ExtManifest.normalized(cssPath)) {
                    scripts.append(WKUserScript(source: Self.cssInjector(css),
                                                injectionTime: timing, forMainFrameOnly: true, in: world))
                }
            }
            for jsPath in cs.js ?? [] {
                if let js = Self.bundledText(ExtManifest.normalized(jsPath)) {
                    scripts.append(WKUserScript(source: js,
                                                injectionTime: timing, forMainFrameOnly: true, in: world))
                }
            }
        }
        return scripts
    }

    /// Main-world (`.page`) injections. ReTorn's `inject_interceptFetch.js` must
    /// run in the page world to patch the page's real `fetch` (so it sees Torn's
    /// own API traffic, CORS-free) and to reach Torn's page globals (getRFC,
    /// Handlebars, $). It dispatches CustomEvents on `document` — mini-profiles,
    /// RFC token, jail refresh, ranked/territory-war filters — which WebKit
    /// delivers to the listeners ReTorn registers in the "retorn" content world.
    /// (The bundled script self-guards against double-injection.) Gated by the
    /// manager toggle, same as the content-world scripts.
    func mainWorldScripts(for url: URL) -> [WKUserScript] {
        guard let manifest = manifest, ExtensionPrefs.shared.isEnabled(Self.retornID),
              let js = Self.bundledText("inject/inject_interceptFetch.js") else { return [] }
        // Inject on exactly the pages where ReTorn's content world (which holds
        // the CustomEvent listeners) runs — i.e. the content script that loads
        // retorn.js — honoring its exclude_matches (api.html, wiki, swagger)
        // rather than a blanket torn.com pattern. No point patching the page's
        // fetch (esp. the API-key page) where nothing listens.
        let urlString = url.absoluteString
        let injectorRuns = manifest.contentScripts.contains { cs in
            (cs.js ?? []).contains { $0.hasSuffix("everywhere/retorn.js") } && matches(urlString, cs)
        }
        guard injectorRuns else { return [] }
        return [WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)]
    }

    private func matches(_ url: String, _ cs: ExtManifest.ContentScript) -> Bool {
        for ex in cs.excludeMatches ?? [] where ExtMatchPattern.matches(ex, url) { return false }
        for pattern in cs.matches where ExtMatchPattern.matches(pattern, url) { return true }
        return false
    }

    static func bundledText(_ relativePath: String) -> String? {
        guard let base = Bundle.main.resourceURL,
              let data = try? Data(contentsOf: base.appendingPathComponent("retorn/\(relativePath)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private static func cssInjector(_ css: String) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: [css]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return "(function(){var s=document.createElement('style');s.textContent=(\(json))[0];(document.head||document.documentElement).appendChild(s);})();"
    }
}

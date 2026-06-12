import Foundation
import WebKit

/// Everything for ONE bundled WebExtension: its manifest, storage (namespaced
/// `webext.<id>.*`), native message relay, and hidden background host (origin
/// `webext://<id>`). `ExtensionRuntime` holds one per bundled extension and
/// fans install + per-navigation injection out to the enabled ones. Each
/// extension lives in its own content world (`world(name: id)`), so their JS
/// (and bundled jQuery/Svelte stacks) never collide with each other or the page.
final class ExtInstance {
    let id: String
    let name: String
    let attribution: String
    let manifest: ExtManifest
    let storage: ExtStorage
    let relay: ExtMessageRelay
    let backgroundHost: ExtBackgroundHost

    /// Bundle-relative scripts injected into the page (main) world.
    private let mainWorldInjects: [String]
    /// If set, main-world injects only run where the content script that loads a
    /// file ending in this suffix runs (honors its exclude_matches); nil = any
    /// matched page.
    private let injectorSuffix: String?

    var isEnabled: Bool { ExtensionPrefs.shared.isEnabled(id) }
    var info: ExtensionRuntime.ExtensionInfo {
        .init(id: id, name: name, version: manifest.version, attribution: attribution)
    }
    private var world: WKContentWorld { .world(name: id) }

    init?(id: String, name: String, attribution: String,
          mainWorldInjects: [String] = [], injectorSuffix: String? = nil) {
        guard let manifest = ExtManifest.load(id: id) else { return nil }
        self.id = id
        self.name = name
        self.attribution = attribution
        self.manifest = manifest
        self.mainWorldInjects = mainWorldInjects
        self.injectorSuffix = injectorSuffix
        self.storage = ExtStorage(id: id)
        self.relay = ExtMessageRelay(storage: storage)
        self.backgroundHost = ExtBackgroundHost(id: id, relay: relay,
                                                version: manifest.version, storage: storage)
        relay.backgroundHost = backgroundHost
    }

    /// Register the relay in this extension's content world + start the bg host
    /// (only when enabled, so a disabled extension spins up nothing).
    func install(on config: WKWebViewConfiguration) {
        relay.register(on: config.userContentController, world: world)
        if isEnabled { backgroundHost.start() }
    }

    func startIfEnabled() { if isEnabled { backgroundHost.start() } }

    /// Shim + matching content scripts (+ CSS) for `url`, in this extension's world.
    func contentWorldScripts(for url: URL) -> [WKUserScript] {
        guard isEnabled else { return [] }
        let urlString = url.absoluteString
        var scripts: [WKUserScript] = []
        var shimInjected = false

        for cs in manifest.contentScripts where matches(urlString, cs) {
            if !shimInjected {
                scripts.append(WKUserScript(
                    source: header + WebExtShimJS.source,
                    injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
                shimInjected = true
            }
            let timing: WKUserScriptInjectionTime =
                (cs.runAt == "document_start") ? .atDocumentStart : .atDocumentEnd
            for cssPath in cs.css ?? [] {
                if let css = bundledText(ExtManifest.normalized(cssPath)) {
                    scripts.append(WKUserScript(source: Self.cssInjector(css),
                                                injectionTime: timing, forMainFrameOnly: true, in: world))
                }
            }
            for jsPath in cs.js ?? [] {
                if let js = bundledText(ExtManifest.normalized(jsPath)) {
                    scripts.append(WKUserScript(source: js,
                                                injectionTime: timing, forMainFrameOnly: true, in: world))
                }
            }
        }
        return scripts
    }

    /// Main-world (`.page`) injects — fetch interceptors etc. that must touch the
    /// page's real fetch/globals; scoped to where this extension's content scripts run.
    func mainWorldScripts(for url: URL) -> [WKUserScript] {
        guard isEnabled, !mainWorldInjects.isEmpty else { return [] }
        let urlString = url.absoluteString
        let runs: Bool
        if let suffix = injectorSuffix {
            runs = manifest.contentScripts.contains { cs in
                (cs.js ?? []).contains { $0.hasSuffix(suffix) } && matches(urlString, cs)
            }
        } else {
            runs = manifest.contentScripts.contains { matches(urlString, $0) }
        }
        guard runs else { return [] }
        return mainWorldInjects.compactMap { path in
            bundledText(path).map {
                WKUserScript(source: $0, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            }
        }
    }

    /// Config for rendering a visible extension page (options/popup) in this
    /// extension's storage/relay context.
    func makePageConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: ExtResourceScheme.scheme)
        relay.register(on: config.userContentController, world: .page)
        config.userContentController.addUserScript(WKUserScript(
            source: header + WebExtShimJS.source + ExtPageExtrasJS.source,
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        return config
    }

    // MARK: - helpers

    /// Sets the extension id + version into the world before the shim runs, so
    /// `getURL` resolves to `webext://<id>/…`.
    private var header: String {
        "window.__webext_id='\(id)';window.__webext_version='\(manifest.version)';"
    }

    private func matches(_ url: String, _ cs: ExtManifest.ContentScript) -> Bool {
        for ex in cs.excludeMatches ?? [] where ExtMatchPattern.matches(ex, url) { return false }
        for pattern in cs.matches where ExtMatchPattern.matches(pattern, url) { return true }
        return false
    }

    private func bundledText(_ relativePath: String) -> String? {
        guard let base = Bundle.main.resourceURL,
              let data = try? Data(contentsOf: base.appendingPathComponent("\(id)/\(relativePath)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private static func cssInjector(_ css: String) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: [css]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return "(function(){var s=document.createElement('style');s.textContent=(\(json))[0];(document.head||document.documentElement).appendChild(s);})();"
    }
}

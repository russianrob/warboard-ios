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
    /// If set, this extension's files are fetched from the warboard server (this
    /// version.json URL) by `RemoteExtStore`; the bundled copy is the seed.
    let remoteSource: URL?
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
    /// When true, bracket this extension's content scripts with diag markers + a
    /// window.onerror capture (→ server log) to find where a script throws/hangs.
    private let debug: Bool

    var isEnabled: Bool { ExtensionPrefs.shared.isEnabled(id) }
    var info: ExtensionRuntime.ExtensionInfo {
        .init(id: id, name: name, version: manifest.version, attribution: attribution,
              optionsPage: manifest.optionsPage)
    }
    private var world: WKContentWorld { .world(name: id) }

    init?(id: String, name: String, attribution: String, remoteSource: URL? = nil,
          mainWorldInjects: [String] = [], injectorSuffix: String? = nil, debug: Bool = false) {
        guard let manifest = ExtManifest.load(id: id) else { return nil }
        self.id = id
        self.name = name
        self.attribution = attribution
        self.remoteSource = remoteSource
        self.manifest = manifest
        self.mainWorldInjects = mainWorldInjects
        self.injectorSuffix = injectorSuffix
        self.debug = debug
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
                if debug {
                    scripts.append(WKUserScript(source: diagSetupJS,
                                                injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
                }
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
                let scriptName = (jsPath as NSString).lastPathComponent
                if debug { scripts.append(diagMarker("before", scriptName, timing)) }
                if let js = bundledText(ExtManifest.normalized(jsPath)) {
                    scripts.append(WKUserScript(source: js,
                                                injectionTime: timing, forMainFrameOnly: true, in: world))
                }
                if debug { scripts.append(diagMarker("after", scriptName, timing)) }
            }
        }
        return scripts
    }

    /// Defines `__wbdiagPost` (posts to the relay's `kind:'diag'`) + captures
    /// uncaught errors/rejections in this content world. Injected after the shim
    /// when `debug`, so before/after markers can bracket each content script.
    private var diagSetupJS: String {
        """
        (function(){
          if (window.__wbdiag) return; window.__wbdiag = 1;
          function p(o){ try{ window.webkit.messageHandlers.webextBridge.postMessage(Object.assign({kind:'diag',ext:'\(id)'},o)); }catch(e){} }
          window.__wbdiagPost = p;
          p({stage:'setup', ver:(window.__webext_version||'?')});
          window.addEventListener('error', function(e){ p({stage:'onerror', msg:String(e.message||'')+' @ '+String(e.filename||'').split('/').pop()+':'+(e.lineno||0)+':'+(e.colno||0)}); }, true);
          window.addEventListener('unhandledrejection', function(e){ var r=e&&e.reason; p({stage:'rejection', msg:String((r&&r.message)||r||'').slice(0,200)}); });
        })();
        """
    }

    private func diagMarker(_ stage: String, _ name: String, _ timing: WKUserScriptInjectionTime) -> WKUserScript {
        let src = "try{window.__wbdiagPost&&window.__wbdiagPost({stage:'\(stage)',n:'\(name)'});}catch(e){}"
        return WKUserScript(source: src, injectionTime: timing, forMainFrameOnly: true, in: world)
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
        if debug {
            config.userContentController.addUserScript(WKUserScript(
                source: pageDiagJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        return config
    }

    /// Captures uncaught errors/rejections on a visible extension PAGE (options/
    /// popup) → relay `kind:'diag'` with `where:'page'`, so a blank options page
    /// reports why instead of failing silently. Debug extensions only.
    private var pageDiagJS: String {
        """
        (function(){
          function p(o){ try{ window.webkit.messageHandlers.webextBridge.postMessage(Object.assign({kind:'diag',ext:'\(id)',where:'page'},o)); }catch(e){} }
          p({stage:'page-setup', ver:(window.__webext_version||'?'), url:String(location.pathname)});
          window.addEventListener('error', function(e){ p({stage:'onerror', msg:String(e.message||'')+' @ '+String(e.filename||'').split('/').pop()+':'+(e.lineno||0)+':'+(e.colno||0)}); }, true);
          window.addEventListener('unhandledrejection', function(e){ var r=e&&e.reason; p({stage:'rejection', msg:String((r&&r.message)||r||'').slice(0,200)}); });
        })();
        """
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
        let base = RemoteExtStore.shared.containerBase(for: id)
        guard let data = try? Data(contentsOf: base.appendingPathComponent("\(id)/\(relativePath)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private static func cssInjector(_ css: String) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: [css]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return "(function(){var s=document.createElement('style');s.textContent=(\(json))[0];(document.head||document.documentElement).appendChild(s);})();"
    }
}

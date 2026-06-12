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

    /// `tabs.create` → open a URL in the app browser. Set by the webview host.
    var onOpenURL: ((String) -> Void)? {
        get { relay.onOpenURL }
        set { relay.onOpenURL = newValue }
    }

    private init() {
        let loaded = ExtManifest.loadReTorn()
        manifest = loaded
        relay = ExtMessageRelay(storage: storage)
        if let loaded = loaded {
            let host = ExtBackgroundHost(relay: relay, version: loaded.version)
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
        backgroundHost?.start()
    }

    /// Shim + matching content scripts (+ CSS) for `url`, in the "retorn" world.
    func contentWorldScripts(for url: URL) -> [WKUserScript] {
        guard let manifest = manifest else { return [] }
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

import Foundation
import WebKit

/// Owns the WebExtension runtime: one `ExtInstance` per bundled extension. The
/// host (`UserscriptController`) calls `install(on:)` once per webview config and
/// `contentWorldScripts(for:)` / `mainWorldScripts(for:)` per navigation; the
/// runtime fans those out to every enabled extension. Each extension is fully
/// isolated (own content world, background host, storage namespace, `webext://<id>`
/// origin), so adding another is just another `ExtInstance` in the catalog below.

/// A presentable extension options page: which extension, which page, title.
/// Top-level + public so it can cross the framework→app boundary (BrowserView's
/// public init parameter and ContentView's `@State` both name it).
public struct ExtOptionsTarget: Identifiable, Equatable {
    public let extId: String
    public let page: String
    public let title: String
    public var id: String { extId }
}

final class ExtensionRuntime {
    static let shared = ExtensionRuntime()
    /// ReTorn's id — used by the app for the (currently ReTorn-only) options entry.
    static let retornID = "retorn"

    /// A bundled extension, surfaced to the in-app extension manager.
    struct ExtensionInfo: Identifiable {
        let id: String
        let name: String
        let version: String
        let attribution: String
        /// Bundle-relative options page (from `options_ui.page`), or nil.
        let optionsPage: String?
    }

    private let instances: [ExtInstance]

    private init() {
        ExtCrashDiag.install()
        // The catalog of bundled extensions. Each loads `<id>/manifest.json`;
        // any that fail to load are dropped (compactMap).
        instances = [
            ExtInstance(id: "retorn", name: "ReTorn", attribution: "Heasleys4hemp",
                        mainWorldInjects: ["inject/inject_interceptFetch.js"],
                        injectorSuffix: "everywhere/retorn.js"),
            ExtInstance(id: "torntools", name: "TornTools", attribution: "Mephiles",
                        remoteSource: URL(string: "https://tornwar.com/ext/torntools/version.json")),
        ].compactMap { $0 }

        // TornTools is bundled but defaults OFF (opt-in) so an untested second
        // extension doesn't disrupt normal browsing until enabled in the manager.
        if !ExtensionPrefs.shared.hasExplicitSetting("torntools") {
            ExtensionPrefs.shared.setEnabled("torntools", false)
        }

        // Updates are user-driven now (no silent at-launch download): the Scripts
        // screen + browser badge call checkExtensionUpdate / installExtensionUpdate.

        // storage.onChanged: a write in ANY context broadcasts to the background
        // world AND the page content world, so listeners react live. Without this
        // TornTools' live toggles (e.g. "Hide Chat") only applied after a refresh.
        // [weak inst] breaks the relay → closure → inst retain cycle.
        for inst in instances {
            let extId = inst.id
            inst.relay.onStorageChanged = { [weak self, weak inst] area, changes in
                inst?.backgroundHost.fireStorageChanged(area: area, changes: changes)
                self?.pushStorageChangedToContent?(extId, area, changes)
            }
        }
    }

    private func instance(_ id: String) -> ExtInstance? { instances.first { $0.id == id } }

    /// The installed (bundled) extensions, for the Scripts-screen manager.
    var installedExtensions: [ExtensionInfo] { instances.map(\.info) }

    /// `tabs.create` → open a URL in the app browser. Forwarded to every relay.
    var onOpenURL: ((String) -> Void)? {
        didSet { instances.forEach { $0.relay.onOpenURL = onOpenURL } }
    }

    /// `runtime.openOptionsPage` → present an extension page. The app receives
    /// `(extensionId, page)` so it knows WHICH extension's options to show; each
    /// relay injects its own extension id.
    var onOpenExtPage: ((String, String) -> Void)? {
        didSet {
            for inst in instances {
                let extId = inst.id
                inst.relay.onOpenExtPage = { [weak self] page in self?.onOpenExtPage?(extId, page) }
            }
        }
    }

    /// Push `storage.onChanged` into the page content world. Set by
    /// `UserscriptController` (which holds the page web view); called with
    /// (extensionId, area, changes) and emits into that extension's content world.
    var pushStorageChangedToContent: ((String, String, [String: [String: Any]]) -> Void)?

    /// The options target for an extension (nil if it's not bundled or declares
    /// no options page).
    func optionsTarget(for id: String) -> ExtOptionsTarget? {
        guard let inst = instance(id), let page = inst.info.optionsPage else { return nil }
        return ExtOptionsTarget(extId: id, page: page, title: "\(inst.name) Options")
    }

    /// Options targets for every ENABLED extension that exposes an options page
    /// (drives the ⋯ menu's per-extension options entries).
    var optionsTargets: [ExtOptionsTarget] {
        instances.compactMap { inst in
            guard ExtensionPrefs.shared.isEnabled(inst.id), let page = inst.info.optionsPage else { return nil }
            return ExtOptionsTarget(extId: inst.id, page: page, title: "\(inst.name) Options")
        }
    }

    /// Register each extension's relay (in its own content world) + start its
    /// background host when enabled. The resource scheme is registered by the host.
    func install(on config: WKWebViewConfiguration) {
        for ext in instances { ext.install(on: config) }
    }

    /// Persist an extension's on/off state and start its background host if it was
    /// just enabled (page injection is gated separately on the next navigation).
    func setExtensionEnabled(_ id: String, _ enabled: Bool) {
        ExtensionPrefs.shared.setEnabled(id, enabled)
        if enabled { instance(id)?.startIfEnabled() }
    }

    /// Cheap update check for one remote-sourced extension (nil if not remote or
    /// up to date). Drives `ExtensionUpdateStore`.
    func checkExtensionUpdate(id: String) async -> String? {
        guard let inst = instance(id), let src = inst.remoteSource else { return nil }
        return await RemoteExtStore.shared.checkForUpdate(id: id, source: src)
    }

    /// Download + install the newest server copy, then hot-swap it in. Returns
    /// the new version. Throws on download failure (nothing applied).
    func installExtensionUpdate(id: String) async throws -> String {
        guard let inst = instance(id), let src = inst.remoteSource else {
            throw RemoteExtStore.RemoteExtError.badSource
        }
        let newVersion = try await RemoteExtStore.shared.installUpdate(id: id, source: src)
        await reloadExtension(id: id)
        return newVersion
    }

    /// Apply a freshly-installed update live: reload the manifest, restart the
    /// background host (re-runs `_background.js` + fires onInstalled→migrate), and
    /// post `.userscriptsDidChange` so the page reloads and re-injects the new
    /// content scripts. The cache is already updated, so even if this is a no-op a
    /// relaunch applies cleanly.
    @MainActor
    func reloadExtension(id: String) {
        guard let inst = instance(id) else { return }
        inst.reloadManifest()
        inst.backgroundHost.restart()
        NotificationCenter.default.post(name: .userscriptsDidChange, object: nil)
    }

    /// Content-world scripts for every enabled extension that matches `url`.
    func contentWorldScripts(for url: URL) -> [WKUserScript] {
        instances.flatMap { $0.contentWorldScripts(for: url) }
    }

    /// Main-world injects for every enabled extension that matches `url`.
    func mainWorldScripts(for url: URL) -> [WKUserScript] {
        instances.flatMap { $0.mainWorldScripts(for: url) }
    }

    /// Config for rendering an extension page (options/popup). Defaults to ReTorn
    /// (the only options entry wired today). Empty config if the id isn't bundled.
    func makeExtensionPageConfig(for id: String = ExtensionRuntime.retornID) -> WKWebViewConfiguration {
        instance(id)?.makePageConfig() ?? WKWebViewConfiguration()
    }
}

import Foundation

/// Public facade the app-target agent chat uses to reach the on-device userscript
/// engine, so `ScriptRegistry` / `LocalInstaller` / `InstalledManifest` / `Userscript`
/// stay `internal` to the `WarboardIOS` framework. The app target only ever needs
/// these two Foundation-typed entry points.
@MainActor
public enum AgentInstallBridge {
    /// The current installed set as `[{filename,name,version,enabled,source}]`,
    /// JSON-ready for the agent message body (`installedScripts`).
    public static func installedManifestJSON() -> [[String: Any]] {
        InstalledManifest.build(from: ScriptRegistry.shared.all()).asJSONBody()
    }

    #if canImport(Darwin)
    /// Install (or update-in-place) a proposed userscript into the on-device
    /// registry so it runs on the next navigation. Throws on a bad `==UserScript==`
    /// header (no `@match`) or an unreachable `@require`.
    public static func install(filename: String, content: String, downloadURL: String) async throws {
        _ = try await LocalInstaller(registry: .shared)
            .install(filename: filename, content: content, downloadURL: downloadURL)
    }
    #endif
}

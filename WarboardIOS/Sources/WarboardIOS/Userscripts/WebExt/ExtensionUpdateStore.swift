import Foundation
import Combine

/// Shared, observable "which extensions have an update available" map. One
/// source of truth for both the Scripts screen (per-row Install button) and the
/// browser-chrome badge dot. Populated by a cheap `version.json` check — never
/// downloads. `@MainActor` so `@Published` mutations are UI-safe.
@MainActor
final class ExtensionUpdateStore: ObservableObject {
    static let shared = ExtensionUpdateStore()
    private init() {}

    /// extension id → available newer version.
    @Published private(set) var available: [String: String] = [:]

    var hasUpdates: Bool { !available.isEmpty }

    /// Re-check every installed extension (remote-sourced ones return a version;
    /// others return nil). Cheap: version.json only.
    func check() async {
        var found: [String: String] = [:]
        for info in ExtensionRuntime.shared.installedExtensions {
            if let v = await ExtensionRuntime.shared.checkExtensionUpdate(id: info.id) {
                found[info.id] = v
            }
        }
        available = found
    }

    func clear(id: String) { available.removeValue(forKey: id) }
}

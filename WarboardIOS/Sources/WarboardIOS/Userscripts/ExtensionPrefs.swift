import Foundation

/// Per-extension enabled flags for the WebExtension runtime, over App-Group
/// UserDefaults (`webext.<id>.enabled`). A missing key means **enabled**, so
/// existing users keep ReTorn on after this update ships. Foundation-only and
/// deliberately placed outside `WebExt/` (which is Linux-excluded) so it builds
/// and unit-tests on Linux.
final class ExtensionPrefs {
    static let shared = ExtensionPrefs()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
    }

    private func key(_ id: String) -> String { "webext.\(id).enabled" }

    /// Default-on: a never-set extension is enabled.
    func isEnabled(_ id: String) -> Bool {
        defaults.object(forKey: key(id)) as? Bool ?? true
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        defaults.set(enabled, forKey: key(id))
    }
}

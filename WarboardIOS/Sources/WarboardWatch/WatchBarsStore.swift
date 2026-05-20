import Foundation
import WidgetKit

/// Single source of truth on the watch for the most recent
/// WatchBarsPayload received from the iPhone. Persists to an App
/// Group-shared UserDefaults so the complication's WidgetKit
/// timeline provider (a separate watchOS process) can read it.
/// Earlier comment claimed UserDefaults.standard worked — that was
/// wrong; the complication was reading an empty defaults store and
/// rendering E0.
final class WatchBarsStore: ObservableObject {
    static let shared = WatchBarsStore()
    private static let key = "warboard.watch.bars-payload.v1"
    static let appGroupSuite = "group.com.tornwar.warboard.watch"
    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? .standard
    }

    @Published private(set) var payload: WatchBarsPayload?

    private init() {
        payload = WatchBarsStore.load()
    }

    func update(_ payload: WatchBarsPayload) {
        self.payload = payload
        WatchBarsStore.persist(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func load() -> WatchBarsPayload? {
        guard let data = defaults().data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchBarsPayload.self, from: data)
    }

    private static func persist(_ payload: WatchBarsPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults().set(data, forKey: key)
    }
}

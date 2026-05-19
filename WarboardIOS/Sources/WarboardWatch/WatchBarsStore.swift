import Foundation
import WidgetKit

/// Single source of truth on the watch for the most recent
/// WatchBarsPayload received from the iPhone. Persists to standard
/// UserDefaults so the value survives watch app restarts and is
/// readable by the complication's WidgetKit timeline provider (the
/// watch widget runs in the same process group as the watch app, so
/// no App Group needed — UserDefaults.standard suffices).
final class WatchBarsStore: ObservableObject {
    static let shared = WatchBarsStore()
    private static let key = "warboard.watch.bars-payload.v1"

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
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchBarsPayload.self, from: data)
    }

    private static func persist(_ payload: WatchBarsPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

import Foundation
import Combine
import WarboardIOS

/// Persists the user's Quick Items list as JSON in App-Group UserDefaults so it
/// survives relaunch (and a future widget could read it). add/remove apply
/// immediately; `@Published items` drives the bar + picker.
@MainActor
final class QuickItemsStore: ObservableObject {
    @Published private(set) var items: [QuickItem] = []

    private let defaults: UserDefaults
    private static let key = "warboard.quickItems"

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([QuickItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func contains(_ id: Int) -> Bool { items.contains { $0.id == id } }

    func add(_ item: QuickItem) {
        guard !contains(item.id) else { return }
        items.append(item)
        save()
    }

    func remove(_ id: Int) {
        items.removeAll { $0.id == id }
        save()
    }

    func toggle(_ item: QuickItem) {
        if contains(item.id) { remove(item.id) } else { add(item) }
    }
}

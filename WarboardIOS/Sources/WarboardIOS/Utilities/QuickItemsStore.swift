import Foundation
import Combine
import WarboardIOS

/// Persists the user's Quick Items as JSON in App-Group UserDefaults so they
/// survive relaunch. There are two independent lists: `personalItems` (shown on
/// the Items page, used from personal stock) and `factionItems` (shown on the
/// faction armoury, used from faction stock). `@Published` so the bar + picker
/// update immediately.
@MainActor
final class QuickItemsStore: ObservableObject {
    @Published private(set) var personalItems: [QuickItem] = []
    @Published private(set) var factionItems: [QuickItem] = []

    private let defaults: UserDefaults
    private static let personalKey = "warboard.quickItems.personal"
    private static let factionKey = "warboard.quickItems.faction"
    private static let legacyKey = "warboard.quickItems" // pre-split single list

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
        // Migrate the old single list into `personal` the first time.
        personalItems = Self.load(defaults, Self.personalKey)
            ?? Self.load(defaults, Self.legacyKey)
            ?? []
        factionItems = Self.load(defaults, Self.factionKey) ?? []
    }

    private static func load(_ d: UserDefaults, _ key: String) -> [QuickItem]? {
        guard let data = d.data(forKey: key),
              let decoded = try? JSONDecoder().decode([QuickItem].self, from: data) else { return nil }
        return decoded
    }

    func items(faction: Bool) -> [QuickItem] { faction ? factionItems : personalItems }

    func contains(_ id: Int, faction: Bool) -> Bool {
        items(faction: faction).contains { $0.id == id }
    }

    func toggle(_ item: QuickItem, faction: Bool) {
        if faction {
            if let i = factionItems.firstIndex(where: { $0.id == item.id }) {
                factionItems.remove(at: i)
            } else {
                factionItems.append(item)
            }
            save(factionItems, Self.factionKey)
        } else {
            if let i = personalItems.firstIndex(where: { $0.id == item.id }) {
                personalItems.remove(at: i)
            } else {
                personalItems.append(item)
            }
            save(personalItems, Self.personalKey)
        }
    }

    private func save(_ items: [QuickItem], _ key: String) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}

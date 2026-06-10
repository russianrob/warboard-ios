import SwiftUI
import WarboardIOS

/// Sheet that lists the user's Torn inventory (fetched with their API key) and
/// lets them tick items on/off the Quick Items bar. Tapping a row toggles it
/// in the store immediately, so this doubles as add + remove.
struct QuickItemsPickerView: View {
    @ObservedObject var store: QuickItemsStore
    @EnvironmentObject private var prefs: PrefsStore
    @Environment(\.dismiss) private var dismiss

    @State private var inventory: [TornAPI.InventoryEntry] = []
    @State private var loading = true
    @State private var search = ""

    private var filtered: [TornAPI.InventoryEntry] {
        guard !search.isEmpty else { return inventory }
        return inventory.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading your inventory…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if inventory.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("Couldn't load your inventory")
                            .font(.headline)
                        Text("Check your API key in the Notifications screen, then try again.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { item in
                        Button {
                            store.toggle(QuickItem(id: item.id, name: item.name))
                        } label: {
                            HStack(spacing: 10) {
                                AsyncImage(url: URL(string: "https://www.torn.com/images/items/\(item.id)/medium.png")) { i in
                                    i.resizable().scaledToFit()
                                } placeholder: { Color.clear }
                                .frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).foregroundStyle(.primary)
                                    Text("×\(item.quantity)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: store.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.contains(item.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                    }
                    .searchable(text: $search, prompt: "Search items")
                }
            }
            .navigationTitle("Quick Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                inventory = await TornAPI.fetchInventory(apiKey: prefs.apiKey)
                    .sorted { $0.name < $1.name }
                loading = false
            }
        }
    }
}

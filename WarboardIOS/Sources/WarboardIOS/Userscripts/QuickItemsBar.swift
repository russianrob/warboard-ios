import SwiftUI

/// A user-curated quick item, identified by its Torn item id. The icon is
/// derived from the id; the name is shown on the pill. Defined in the
/// framework so both the app (which stores/edits the list) and BrowserView
/// (which renders the bar + fires the use) can share it.
public struct QuickItem: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
    public var iconURL: URL? {
        URL(string: "https://www.torn.com/images/items/\(id)/medium.png")
    }
}

/// Horizontal pill bar of quick items (TornPDA-style). Each pill is icon +
/// name; tapping fires `onUse`. A trailing ＋ opens the editor via `onEdit`.
/// When `factionMode` is on (the user is on the faction armoury) the pills get
/// an orange border to signal that a tap uses the faction's copy.
struct QuickItemsBar: View {
    let items: [QuickItem]
    let factionMode: Bool
    let onUse: (QuickItem) -> Void
    let onEdit: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button { onUse(item) } label: { pill(item) }
                        .buttonStyle(.plain)
                }
                Button(action: onEdit) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func pill(_ item: QuickItem) -> some View {
        HStack(spacing: 6) {
            AsyncImage(url: item.iconURL) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "shippingbox.fill")
                    .resizable().scaledToFit().foregroundStyle(.tertiary)
            }
            .frame(width: 22, height: 22)
            Text(item.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .overlay(
            Capsule().strokeBorder(
                factionMode ? Color.orange.opacity(0.8) : Color.clear,
                lineWidth: 1
            )
        )
    }
}

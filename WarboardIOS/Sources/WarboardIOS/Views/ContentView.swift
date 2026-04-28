import SwiftUI

/// Root TabView — same four sections the Android app's bottom-nav
/// surfaces and warboard-mac's sidebar. Each tab gets its own
/// NavigationStack so the navigation bar + title render correctly.
struct ContentView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var access = TabAccessViewModel()

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Status", systemImage: "speedometer") }

            NavigationStack { WarRoomView() }
                .tabItem { Label("War", systemImage: "flame.fill") }

            // Faction tab is gated to roles in the broadcast-roles list
            // (defaults to leader / co-leader / war leader / banker, but
            // can be customised via Settings → Admin → Broadcast roles).
            // Members data is faction-wide leadership info; non-admin
            // members don't need a tab full of others' bars + cooldowns.
            if access.canViewFaction {
                NavigationStack { FactionView() }
                    .tabItem { Label("Faction", systemImage: "person.3.fill") }
            }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        // App-wide shout banner — listens to RealtimeClient.globalToast
        // so any tab shows the broadcast (and the sender sees their own).
        .overlay(alignment: .top) { ShoutToastOverlay() }
        .task { await access.load(prefs: prefs) }
        .onChange(of: prefs.apiKey) { _, _ in Task { await access.load(prefs: prefs) } }
    }
}

/// Decides which top-level tabs the current user can see based on the
/// faction's configured broadcast-roles list. Only the Faction
/// (Members) tab is gated today, but the same model can grow for
/// future admin-only tabs.
@MainActor
final class TabAccessViewModel: ObservableObject {
    @Published var canViewFaction: Bool = false

    func load(prefs: PrefsStore) async {
        guard let auth = prefs.cachedJwt(), !auth.token.isEmpty else {
            canViewFaction = false
            return
        }
        // Owner (137558) always sees every tab — useful for support &
        // debugging across factions whose admins haven't customised the
        // roles list. Otherwise, role must match the broadcast-roles
        // list (case-insensitive).
        if auth.isOwner { canViewFaction = true; return }

        let roles = await WarboardAPI.fetchBroadcastRoles(
            baseUrl: prefs.baseUrl, jwt: auth.token
        )
        let myRole = auth.factionPosition.lowercased()
        let allowed = roles.map { $0.lowercased() }
        canViewFaction = !myRole.isEmpty && allowed.contains(myRole)
    }
}

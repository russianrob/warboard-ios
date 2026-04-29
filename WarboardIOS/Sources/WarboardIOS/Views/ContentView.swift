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

            // Faction tab is always visible — members need the vault
            // submit form to request money. The pending-requests list +
            // Send/Cancel buttons + Members panel are admin-gated
            // INSIDE FactionView (see canManageVault / canViewMembers).
            NavigationStack { FactionView() }
                .tabItem { Label("Faction", systemImage: "person.3.fill") }

            // Owner-only OC Manager — Missing / Unused / Payouts. Ported
            // from the discontinued oc-spawn-ios as a self-contained
            // module under OCManager/. Hidden for everyone except
            // RussianRob (auth.isOwner) so non-owner installs never
            // see the tab nor execute any of its networking.
            if access.canManageOC {
                NavigationStack { ManagerView() }
                    .tabItem { Label("OC", systemImage: "person.3.sequence.fill") }
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
    /// Strictly owner-only — RussianRob (137558). The OC Manager tab
    /// performs in-app loan/retrieve via an embedded WKWebView using
    /// the user's torn.com session, which is owner-bench-tested only.
    /// Other admins keep using the userscript.
    @Published var canManageOC: Bool = false

    func load(prefs: PrefsStore) async {
        guard let auth = prefs.cachedJwt(), !auth.token.isEmpty else {
            canViewFaction = false
            canManageOC = false
            return
        }
        canManageOC = auth.isOwner
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

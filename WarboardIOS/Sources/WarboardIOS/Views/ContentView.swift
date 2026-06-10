import SwiftUI
import WarboardIOS

/// Top-tab navigation — same five sections that the Android app's
/// bottom-nav surfaces, but positioned at the TOP of the screen on
/// iPhone. Two reasons it's not a default `TabView`:
///   1. SwiftUI's TabView is hardwired to the bottom on iPhone; there's
///      no first-party way to move it up without third-party hacks or
///      iOS 18-only sidebarAdaptable styling that doesn't apply on
///      iPhone form factors.
///   2. The bottom tab bar overlays embedded WebView content (Chat tab
///      → Torn's right-side chat panel), clipping the input box. Moving
///      tabs up frees the bottom safe area for that content.
///
/// State preservation: all tab content lives in a ZStack with opacity
/// gating, so each tab's NavigationStack + ViewModel stays mounted
/// when the user switches away (matches TabView's behaviour for
/// poll timers, Socket.IO connections, etc.).
struct ContentView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var access = TabAccessViewModel()
    @State private var selected: WBTab = .war

    var body: some View {
        VStack(spacing: 0) {
            TopTabBar(selected: $selected, canManageOC: access.canManageOC)
            ZStack {
                NavigationStack { DashboardView() }
                    .opacity(selected == .status ? 1 : 0)
                    .allowsHitTesting(selected == .status)

                NavigationStack { WarRoomView() }
                    .opacity(selected == .war ? 1 : 0)
                    .allowsHitTesting(selected == .war)

                NavigationStack { BrowserView() }
                    .opacity(selected == .browser ? 1 : 0)
                    .allowsHitTesting(selected == .browser)

                // Faction tab is always visible — members need the vault
                // submit form to request money. Admin tools inside are
                // gated by FactionView itself.
                NavigationStack { FactionView() }
                    .opacity(selected == .faction ? 1 : 0)
                    .allowsHitTesting(selected == .faction)

                NavigationStack { ScriptsView() }
                    .opacity(selected == .scripts ? 1 : 0)
                    .allowsHitTesting(selected == .scripts)

                // Owner-only OC Manager. Mount only when allowed so
                // non-owner installs don't pay for its networking; the
                // top tab bar hides the OC button for them too.
                if access.canManageOC {
                    NavigationStack { ManagerView() }
                        .opacity(selected == .oc ? 1 : 0)
                        .allowsHitTesting(selected == .oc)
                }

                NavigationStack { SettingsView() }
                    .opacity(selected == .settings ? 1 : 0)
                    .allowsHitTesting(selected == .settings)
            }
        }
        // App-wide shout banner — listens to RealtimeClient.globalToast
        // so any tab shows the broadcast (and the sender sees their own).
        .overlay(alignment: .top) { ShoutToastOverlay() }
        .task { await access.load(prefs: prefs) }
        .onChange(of: prefs.apiKey) { _, _ in Task { await access.load(prefs: prefs) } }
        .onChange(of: access.canManageOC) { _, canShow in
            // If the user lands here on the OC tab but loses access mid-
            // session, bounce them back to War so they're not stuck on
            // an invisible tab.
            if !canShow && selected == .oc { selected = .war }
        }
    }
}

/// Top tabs identified by stable enum so opacity gating + segment
/// rendering stay in sync.
enum WBTab: String, CaseIterable, Identifiable {
    case status, war, browser, faction, scripts, oc, settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .status:   return "Status"
        case .war:      return "War"
        case .browser:  return "Browser"
        case .faction:  return "Faction"
        case .scripts:  return "Scripts"
        case .oc:       return "OC"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .status:   return "speedometer"
        case .war:      return "flame.fill"
        case .browser:  return "globe"
        case .faction:  return "person.3.fill"
        case .scripts:  return "doc.text.fill"
        case .oc:       return "person.3.sequence.fill"
        case .settings: return "gear"
        }
    }
}

/// Custom top tab bar. Mirrors the visual weight of iOS's standard
/// bottom tab bar (icon over label, accent tint on the selected tab,
/// thin divider below) but pinned to the top so embedded WebView
/// content can reach the home-indicator area without being clipped.
private struct TopTabBar: View {
    @Binding var selected: WBTab
    let canManageOC: Bool

    var body: some View {
        let visible = WBTab.allCases.filter { $0 != .oc || canManageOC }
        HStack(spacing: 0) {
            ForEach(visible) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(selected == tab ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
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

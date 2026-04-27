import SwiftUI

/// Root TabView — same four sections the Android app's bottom-nav
/// surfaces and warboard-mac's sidebar. Each tab gets its own
/// NavigationStack so the navigation bar + title render correctly.
struct ContentView: View {
    @EnvironmentObject private var prefs: PrefsStore

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Status", systemImage: "speedometer") }

            NavigationStack { WarRoomView() }
                .tabItem { Label("War", systemImage: "flame.fill") }

            NavigationStack { FactionView() }
                .tabItem { Label("Faction", systemImage: "person.3.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

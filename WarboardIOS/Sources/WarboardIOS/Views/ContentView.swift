import SwiftUI
import WarboardIOS

/// App shell: a full-screen in-app Torn browser hosting the userscript
/// engine. Script management is reached from the browser's URL bar, so the
/// shell adds no chrome of its own — the web view owns the whole screen.
///
/// The watch / widget data pipeline is app-level (BarReporter in
/// WarboardIOSApp pushes to WatchSyncController every cycle regardless of
/// which view is mounted), so this shell does not affect the watch.
struct ContentView: View {
    @State private var showNotifications = false

    var body: some View {
        BrowserView(onShowNotifications: { showNotifications = true })
            // App-wide shout banner — listens to RealtimeClient.globalToast
            // so a broadcast surfaces over the browser.
            .overlay(alignment: .top) { ShoutToastOverlay() }
            .sheet(isPresented: $showNotifications) {
                NavigationStack { NotificationSettingsView() }
            }
    }
}

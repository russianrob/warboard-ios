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
    @State private var showItemPicker = false
    @State private var pickerFaction = false
    @State private var showWarRoom = false
    @State private var showOCManager = false
    @State private var showWarPayouts = false
    @State private var extOptionsTarget: ExtOptionsTarget?
    @StateObject private var quickItems = QuickItemsStore()

    var body: some View {
        BrowserView(
            personalItems: quickItems.personalItems,
            factionItems: quickItems.factionItems,
            onEditQuickItems: { faction in
                pickerFaction = faction
                showItemPicker = true
            },
            onShowNotifications: { showNotifications = true },
            onShowWarRoom: { showWarRoom = true },
            onShowOCManager: { showOCManager = true },
            onShowWarPayouts: { showWarPayouts = true },
            onShowExtOptions: { extOptionsTarget = $0 }
        )
        // App-wide shout banner — listens to RealtimeClient.globalToast
        // so a broadcast surfaces over the browser.
        .overlay(alignment: .top) { ShoutToastOverlay() }
        .sheet(isPresented: $showNotifications) {
            NavigationStack { NotificationSettingsView() }
        }
        .sheet(isPresented: $showItemPicker) {
            QuickItemsPickerView(store: quickItems, faction: pickerFaction)
        }
        .fullScreenCover(isPresented: $showWarRoom) {
            NavigationStack { WarRoomView() }
        }
        .fullScreenCover(isPresented: $showOCManager) {
            NavigationStack { ManagerView() }
        }
        .fullScreenCover(isPresented: $showWarPayouts) {
            NavigationStack { WarPayoutsView() }
        }
        .fullScreenCover(item: $extOptionsTarget) { target in
            NavigationStack { ExtPageView(extId: target.extId, page: target.page, title: target.title) }
        }
    }
}

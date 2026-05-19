import SwiftUI

@main
struct WarboardWatchApp: App {
    @StateObject private var store = WatchBarsStore.shared
    @StateObject private var session = WatchSession.shared

    init() {
        // Activate the WC session as early as possible so we receive
        // the iPhone's first applicationContext while the watch app is
        // still in the background-launch window.
        _ = WatchSession.shared
    }

    var body: some Scene {
        WindowGroup {
            StatusView()
                .environmentObject(store)
        }
    }
}

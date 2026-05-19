import SwiftUI

@main
struct WarboardWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var store = WatchBarsStore.shared
    @StateObject private var session = WatchSession.shared

    init() {
        _ = WatchSession.shared
    }

    var body: some Scene {
        WindowGroup {
            StatusView()
                .environmentObject(store)
        }
    }
}

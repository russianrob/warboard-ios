import Foundation
import WatchKit
import UserNotifications
import WidgetKit

/// Watch-side application delegate. Two responsibilities:
///   1. Register for APNs on launch and POST the hex device token to
///      tornwar.com/api/watch/subscribe so the existing 5-min status
///      poller will fan out bars/cooldowns to this watch.
///   2. Receive incoming background pushes, decode the `bars`
///      userInfo payload into a WatchBarsPayload, and forward it into
///      WatchBarsStore (which persists + reloads the complication).
///
/// The watch app gets its API key + auth credentials from the iPhone
/// via WCSession applicationContext (see WatchSession.swift) — the
/// watch never holds the user's API key beyond what's needed to POST
/// the token. Once registered server-side, the API key is purged from
/// watch memory.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    static let serverBase = URL(string: "https://tornwar.com")!

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().requestAuthorization(options: []) { _, _ in
            DispatchQueue.main.async {
                WKApplication.shared().registerForRemoteNotifications()
            }
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        // Subscribe credentials are delivered by the iPhone via
        // WCSession (key "watchSubscribe":{token, apiKey}) — held by
        // WatchSession.lastSubscribeCreds. If they aren't here yet
        // we stash the device token and retry once they arrive.
        WatchSession.shared.recordDeviceToken(hex)
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("[WatchAppDelegate] APNs register failed: \(error.localizedDescription)")
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        // Server pushes the bars payload under the "bars" key. Same
        // shape as WatchBarsPayload — decode through the dictionary
        // initializer so silent pushes update the cache + complication
        // without any UI prompt.
        guard let bars = userInfo["bars"] as? [String: Any],
              let payload = WatchBarsPayload.from(context: bars) else {
            return .noData
        }
        await MainActor.run {
            WatchBarsStore.shared.update(payload)
        }
        return .newData
    }
}

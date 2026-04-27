import SwiftUI
import UIKit
import UserNotifications

@main
struct WarboardIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// AppDelegate exists for the bits SwiftUI's lifecycle doesn't expose
/// natively — most importantly, APNs device-token registration. The
/// SwiftUI App protocol can't surface
/// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
/// without a UIKit bridge.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Request notification permission on first launch. iOS shows
        // the system prompt the first time we ask; subsequent calls
        // resolve silently against the prior answer.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            if let err = err {
                NSLog("[Warboard] Notification authorization error: \(err.localizedDescription)")
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data,
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NSLog("[Warboard] APNs device token: \(token.prefix(16))…")
        TornwarApnsClient.register(token: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error,
    ) {
        NSLog("[Warboard] APNs register failed: \(error.localizedDescription)")
    }

    /// Remote notification arrived while the app is in the foreground.
    /// Show it as a banner anyway (default would suppress).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void,
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

/// HTTP client for warboard's `/api/apns/subscribe` endpoint. Mirrors
/// the Android side's `WarboardMessagingService.registerToken` but
/// targets APNs instead of FCM. Server-side the storage shape is the
/// same — just a different `platform` discriminator.
enum TornwarApnsClient {
    static func register(token: String) {
        let prefs = UserDefaults.standard
        guard let apiKey = prefs.string(forKey: "torn_api_key"), !apiKey.isEmpty else {
            NSLog("[Warboard] Skipping APNs register — no Torn API key in prefs yet")
            return
        }
        let baseRaw = prefs.string(forKey: "warboard_base_url") ?? "https://tornwar.com"
        let base = baseRaw.hasSuffix("/") ? String(baseRaw.dropLast()) : baseRaw
        guard let url = URL(string: "\(base)/api/apns/subscribe") else { return }

        let bundleId = Bundle.main.bundleIdentifier ?? "com.tornwar.warboard"
        let body: [String: Any] = [
            "key":        apiKey,
            "token":      token,
            "platform":   "ios",
            "appBundle":  bundleId,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                NSLog("[Warboard] APNs register failed: \(err.localizedDescription)")
                return
            }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Warboard] APNs register POST → HTTP \(code)")
        }.resume()
    }
}

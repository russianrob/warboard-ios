import SwiftUI
import UIKit
import UserNotifications
import WarboardIOS   // framework module: BrowserRouter (.onOpenURL routing)

/// Top-level scene. TabView root mirrors the Android warboard-native
/// app's bottom navigation (Status / War / Faction / Settings). The
/// AppDelegate exists only to surface the APNs device-token callback
/// — SwiftUI's lifecycle doesn't expose that natively.
@main
struct WarboardIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var prefs: PrefsStore
    @StateObject private var chainTicker: ChainTickerViewModel
    @StateObject private var barReporter = BarReporter()
    @StateObject private var inspectClient = InspectClient()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let p = PrefsStore()
        _prefs = StateObject(wrappedValue: p)
        _chainTicker = StateObject(wrappedValue: ChainTickerViewModel(prefs: p))
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(prefs)
                .environmentObject(chainTicker)
                .overlay(alignment: .top) {
                    if prefs.inspectEnabled {
                        Text("🔴 REMOTE INSPECT ON")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }
                .task {
                    chainTicker.start()
                    barReporter.bind(prefs: prefs)
                    barReporter.start()
                    inspectClient.bind(prefs: prefs)
                    inspectClient.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Pause the bar reporter when the app is
                    // backgrounded so we're not burning the user's
                    // Torn API budget while they're not looking,
                    // and resume on .active so any tab being open
                    // keeps the faction's Members view fresh.
                    if phase == .active {
                        barReporter.start()
                        inspectClient.start()
                    } else {
                        barReporter.stop()
                        inspectClient.stop()
                    }
                }
                .onChange(of: prefs.inspectEnabled) { _, on in
                    if on { inspectClient.start() } else { inspectClient.stop() }
                }
                .onOpenURL { url in
                    // Default-browser / shared-link / Universal-Link opens land
                    // here → show them in the in-app browser tab. Non-web schemes
                    // are ignored. (Requires the web-browser entitlement to be the
                    // system default browser; also works for shared http(s) URLs.)
                    guard url.scheme == "http" || url.scheme == "https" else { return }
                    BrowserRouter.shared.open(url)
                }
        }
    }
}

/// Bridges the bits SwiftUI's lifecycle doesn't expose — primarily
/// APNs device-token registration. Foreground-banner presentation
/// is also forced here so server-pushed alerts surface even when the
/// app is in front (default would suppress them).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Web-view JS notifications (userscripts' browser.notifications.create,
        // TornTools, ReTorn) post a Foundation WBExtNotify event from the WebExt
        // module, which can't see NotificationManager. Fire it natively here.
        NotificationCenter.default.addObserver(forName: Notification.Name("WBExtNotify"), object: nil, queue: .main) { note in
            let info = note.userInfo
            let title = (info?["title"] as? String) ?? "Warboard"
            let body = (info?["body"] as? String) ?? ""
            let id = (info?["id"] as? String) ?? UUID().uuidString
            NotificationManager.shared.fire(title: title, body: body, category: .generic, id: id)
        }
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
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NSLog("[Warboard] APNs device token: \(token.prefix(16))…")
        TornwarApnsClient.register(token: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("[Warboard] APNs register failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

/// HTTP client for warboard's `/api/apns/subscribe` endpoint. Mirrors
/// the Android side's FCM subscribe — same storage shape, different
/// `platform` discriminator.
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
            "key":       apiKey,
            "token":     token,
            "platform":  "ios",
            "appBundle": bundleId,
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

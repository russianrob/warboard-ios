import Foundation
import WatchConnectivity

/// Watch-side WCSession receiver. Two responsibilities:
///   1. Mirror iPhone-pushed BarsCache via applicationContext (the
///      foreground / live channel).
///   2. Receive (and persist) the (apiKey, playerId) subscribe
///      credentials the iPhone sends so the watch can POST its APNs
///      device token to /api/watch/subscribe — that's how the watch
///      gets enrolled into the server's 5-min poll fan-out.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    /// Cached most-recent (token, apiKey) credentials. Set by either
    /// channel (WCSession arrives, or APNs registers) and consumed by
    /// trySubscribeIfReady when both halves are present.
    private var lastDeviceToken: String?
    private var lastApiKey: String?
    private var lastJwt: String?
    private var lastPlayerName: String?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Called by WatchAppDelegate.didRegisterForRemoteNotifications.
    func recordDeviceToken(_ hex: String) {
        lastDeviceToken = hex
        trySubscribeIfReady()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchSession] activation failed: \(error.localizedDescription)")
            return
        }
        // Drain whatever applicationContext was last received before
        // our delegate hooked up — important for first launch.
        let ctx = session.receivedApplicationContext
        process(context: ctx)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        process(context: applicationContext)
    }

    private func process(context: [String: Any]) {
        // The iPhone packs two things into a single applicationContext:
        // the bars payload AND the watch-subscribe credentials. We
        // peel them apart here.
        if let payload = WatchBarsPayload.from(context: context) {
            DispatchQueue.main.async { WatchBarsStore.shared.update(payload) }
        }
        if let sub = context["watchSubscribe"] as? [String: Any] {
            if let apiKey = sub["apiKey"] as? String, !apiKey.isEmpty {
                lastApiKey = apiKey
            }
            if let jwt = sub["jwt"] as? String, !jwt.isEmpty {
                lastJwt = jwt
            }
            if let name = sub["playerName"] as? String {
                lastPlayerName = name
            }
            trySubscribeIfReady()
        }
    }

    /// POST our device token + apiKey to /api/watch/subscribe so the
    /// server's status poller will fan out to this watch.
    private func trySubscribeIfReady() {
        guard let token = lastDeviceToken,
              let apiKey = lastApiKey,
              let jwt = lastJwt else { return }
        let url = URL(string: "https://tornwar.com/api/watch/subscribe")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Bearer JWT — matches the iPhone app's auth scheme so the
        // server's requireAuth middleware accepts the request.
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["token": token, "apiKey": apiKey]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                print("[WatchSession] subscribe failed: \(err.localizedDescription)")
                return
            }
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                print("[WatchSession] subscribed to /api/watch/subscribe")
            } else if let http = resp as? HTTPURLResponse {
                print("[WatchSession] subscribe http \(http.statusCode)")
            }
        }.resume()
    }
}

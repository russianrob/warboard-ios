import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// iPhone-side WCSession owner. Holds the activated session and exposes
/// a single `push(payload:)` entry point that mirrors the latest
/// BarsCache snapshot to the paired Apple Watch via
/// updateApplicationContext (last-write-wins, persists across watch
/// app launches — ideal for a "current state" payload).
///
/// Why updateApplicationContext over transferUserInfo: context replaces
/// the previously-queued value, so we never stack outdated snapshots
/// in the queue when the watch is unreachable. transferUserInfo would
/// queue indefinitely.
final class WatchSyncController: NSObject {
    static let shared = WatchSyncController()

    private override init() {
        super.init()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    /// Push the latest bars/cooldowns + (when available) the credentials
    /// the watch needs to subscribe to /api/watch/subscribe. Cheap to
    /// call — silently no-op if no watch is paired.
    func push(payload: WatchBarsPayload) {
        #if canImport(WatchConnectivity)
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired else { return }
        var context = payload.asContextDictionary()
        // Piggy-back the subscribe credentials onto every push. The
        // watch's WatchSession reads "watchSubscribe" and POSTs to
        // /api/watch/subscribe once it also has its APNs token. This
        // pairing is idempotent server-side — re-POSTing the same
        // (token, apiKey) just updates the row's `updatedAt`.
        // PrefsStore is the single source of truth for apiKey on iOS;
        // read directly from the App Group-shared UserDefaults so we
        // don't need a singleton wiring change. Field name mirrors
        // PrefsStore.kApiKey.
        let suite = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard
        let apiKey = suite.string(forKey: "warboard.apiKey") ?? ""
        let jwt = suite.string(forKey: "warboard.jwt") ?? ""
        if !apiKey.isEmpty && !jwt.isEmpty {
            context["watchSubscribe"] = [
                "apiKey": apiKey,
                "jwt": jwt,
                "playerName": suite.string(forKey: "warboard.playerName") ?? "",
            ]
        }
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("[WatchSync] updateApplicationContext failed: \(error.localizedDescription)")
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchSyncController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchSync] activation failed: \(error.localizedDescription)")
        }
    }
    // iOS-only required stubs. The watch never deactivates the iPhone's
    // session, so these don't need real implementations beyond
    // re-activating after a session switch (e.g. paired-watch change).
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
#endif

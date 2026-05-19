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

    /// Push the latest bars/cooldowns to the watch. Cheap to call — if
    /// the session isn't activated or no watch is paired, the write is
    /// silently dropped.
    func push(payload: WatchBarsPayload) {
        #if canImport(WatchConnectivity)
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired else { return }
        do {
            try session.updateApplicationContext(payload.asContextDictionary())
        } catch {
            // Logged but not fatal — next bar tick will retry.
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

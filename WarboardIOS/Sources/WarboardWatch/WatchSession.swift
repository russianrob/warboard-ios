import Foundation
import WatchConnectivity

/// Watch-side WCSession receiver. Owns the session, listens for
/// updateApplicationContext deliveries from the iPhone, and forwards
/// the decoded payload into WatchBarsStore (which persists + reloads
/// the complication timelines).
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchSession] activation failed: \(error.localizedDescription)")
            return
        }
        // applicationContext that arrived before our delegate was set
        // is still readable via the session's `receivedApplicationContext`
        // property — drain it here so first-launch picks up state.
        let ctx = session.receivedApplicationContext
        if let payload = WatchBarsPayload.from(context: ctx) {
            DispatchQueue.main.async { WatchBarsStore.shared.update(payload) }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = WatchBarsPayload.from(context: applicationContext) else { return }
        DispatchQueue.main.async { WatchBarsStore.shared.update(payload) }
    }
}

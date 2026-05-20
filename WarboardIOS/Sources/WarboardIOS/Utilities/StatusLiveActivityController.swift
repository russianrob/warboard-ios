import Foundation
import ActivityKit

/// Start / update / end controller for the always-on Status Live
/// Activity. Different lifecycle from the chain LA — this one is
/// driven entirely by user intent (Dashboard's Start / Stop button)
/// and doesn't react to war state.
///
/// Update model:
///   - Foreground: BarReporter calls `update(...)` after each Torn
///     dashboard fetch (~60 s while app is open).
///   - Background (v0.4.63+): server polls Torn every ~5 min for each
///     registered Status-LA subscriber and pushes via APNs to the LA
///     push token, so the lock-screen surface stays fresh even when
///     the app is closed. Subscribe on start() — send (token, apiKey)
///     to `/api/live-activity/status/subscribe`. Unsubscribe on stop().
@available(iOS 16.2, *)
@MainActor
final class StatusLiveActivityController {
    static let shared = StatusLiveActivityController()
    private init() {}

    private var current: Activity<StatusActivityAttributes>?
    /// Long-lived task observing the current activity's pushTokenUpdates
    /// async sequence. Apple may rotate the LA push token over the
    /// activity's lifetime (especially on backgrounding) and we have
    /// to re-register with the server when it changes, else the next
    /// server push goes to a dead token.
    private var pushTokenTask: Task<Void, Never>?
    /// Cached so reSubscribe (token rotation) can re-POST without the
    /// caller having to pass them again.
    private var lastBaseUrl: String = ""
    private var lastJwt: String = ""
    private var lastApiKey: String = ""

    /// True when an activity exists and ActivityKit reports it as
    /// active. Used by the Dashboard button to flip its label between
    /// "Start Live Activity" and "Stop Live Activity".
    var isActive: Bool {
        guard let a = current else { return false }
        return a.activityState == .active
    }

    /// Start the activity if one isn't already running. Requests a
    /// `.token` pushType so the server can deliver background bars
    /// updates via APNs. No-op when the user has Live Activities
    /// disabled in Settings.
    func start(playerName: String,
               initialState: StatusActivityAttributes.ContentState,
               baseUrl: String = "",
               jwt: String = "",
               apiKey: String = "") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        lastBaseUrl = baseUrl
        lastJwt = jwt
        lastApiKey = apiKey

        // Adopt an existing same-attributes activity if iOS persisted
        // one across launches. If it was created with pushType: nil
        // (pre-v0.4.63), end it and start a fresh one with .token
        // so server background pushes can land.
        if let existing = Activity<StatusActivityAttributes>.activities.first(where: { $0.activityState == .active }) {
            if existing.pushToken != nil {
                current = existing
                Task { await existing.update(ActivityContent(state: initialState, staleDate: nil)) }
                startPushTokenObserver(for: existing)
                return
            } else {
                Task { await existing.end(nil, dismissalPolicy: .immediate) }
            }
        }
        do {
            let attrs = StatusActivityAttributes(playerName: playerName)
            let content = ActivityContent(state: initialState, staleDate: nil)
            // Try with pushType: .token first (enables server APNs
            // push). If that fails (some iOS 16.2-17.1 builds reject
            // .token), fall back to pushType: nil so the LA still
            // starts — it just won't get the 5-min server pushes,
            // only foreground bar tick updates.
            let activity: Activity<StatusActivityAttributes>
            do {
                activity = try Activity.request(attributes: attrs, content: content, pushType: .token)
            } catch {
                print("[StatusLA] .token rejected (\(error.localizedDescription)) — retrying without pushType")
                activity = try Activity.request(attributes: attrs, content: content, pushType: nil)
            }
            current = activity
            startPushTokenObserver(for: activity)
        } catch {
            print("[StatusLA] Activity.request failed: \(error.localizedDescription)")
            current = nil
        }
    }

    /// Push a fresh state into the active activity. No-op when no
    /// activity is running. Called by BarReporter after each Torn
    /// dashboard fetch.
    func update(_ state: StatusActivityAttributes.ContentState) {
        guard let a = current, a.activityState == .active else { return }
        Task { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// End the activity immediately (no dismissalPolicy delay). User-
    /// triggered via the Dashboard Stop button. Also un-registers
    /// with the server so the poller stops pushing to the now-dead
    /// token.
    func stop() {
        pushTokenTask?.cancel()
        pushTokenTask = nil
        if !lastBaseUrl.isEmpty, !lastJwt.isEmpty {
            Task { await Self.unregisterWithServer(baseUrl: lastBaseUrl, jwt: lastJwt) }
        }
        guard let a = current else { return }
        Task { await a.end(nil, dismissalPolicy: .immediate) }
        current = nil
    }

    /// Adopt any previously-persisted activity on app launch so the
    /// `isActive` flag is accurate when the Dashboard renders.
    /// Idempotent. Doesn't re-start push-token observation — that
    /// happens lazily on the next start() call.
    func adoptExisting() {
        if let existing = Activity<StatusActivityAttributes>.activities
            .first(where: { $0.activityState == .active }) {
            current = existing
        }
    }

    // MARK: - Server registration

    /// Observe pushTokenUpdates on the activity. On every token
    /// (initial + any rotation), POST it to the server with the
    /// stored apiKey so the 5-min poller can push fresh bars while
    /// the iOS app is backgrounded.
    private func startPushTokenObserver(for activity: Activity<StatusActivityAttributes>) {
        pushTokenTask?.cancel()
        pushTokenTask = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                guard let self else { return }
                let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                guard !self.lastBaseUrl.isEmpty,
                      !self.lastJwt.isEmpty,
                      !self.lastApiKey.isEmpty else { continue }
                await Self.registerWithServer(
                    baseUrl: self.lastBaseUrl,
                    jwt: self.lastJwt,
                    apiKey: self.lastApiKey,
                    token: hex
                )
            }
        }
    }

    private static func registerWithServer(baseUrl: String, jwt: String, apiKey: String, token: String) async {
        guard let url = URL(string: baseUrl + "/api/live-activity/status/subscribe") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["token": token, "apiKey": apiKey]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    private static func unregisterWithServer(baseUrl: String, jwt: String) async {
        guard let url = URL(string: baseUrl + "/api/live-activity/status/unsubscribe") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
        req.httpBody = "{}".data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}

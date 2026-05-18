import Foundation
import ActivityKit

/// Start / update / end controller for the always-on Status Live
/// Activity. Different lifecycle from the chain LA — this one is
/// driven entirely by user intent (Dashboard's Start / Stop button)
/// and doesn't react to war state.
///
/// Update model: foreground-only for v1. `BarReporter` calls
/// `update(...)` after each successful Torn dashboard fetch (every
/// 60s while the app is foregrounded). When the user backgrounds
/// the app, the activity keeps showing the last-known values and
/// the cooldown chips continue to count down via
/// `Text(timerInterval:)` against their absolute deadlines.
@available(iOS 16.2, *)
@MainActor
final class StatusLiveActivityController {
    static let shared = StatusLiveActivityController()
    private init() {}

    private var current: Activity<StatusActivityAttributes>?

    /// True when an activity exists and ActivityKit reports it as
    /// active. Used by the Dashboard button to flip its label between
    /// "Start Live Activity" and "Stop Live Activity".
    var isActive: Bool {
        guard let a = current else { return false }
        return a.activityState == .active
    }

    /// Start the activity if one isn't already running. No-op when
    /// the user has Live Activities disabled in Settings, or when
    /// ActivityKit reports the previous instance still active.
    func start(playerName: String, initialState: StatusActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Adopt an existing same-attributes activity if iOS persisted
        // one across launches (e.g. user opens the app after the LA
        // has been running on the lock screen for hours).
        if let existing = Activity<StatusActivityAttributes>.activities.first(where: { $0.activityState == .active }) {
            current = existing
            Task { await existing.update(ActivityContent(state: initialState, staleDate: nil)) }
            return
        }
        do {
            let attrs = StatusActivityAttributes(playerName: playerName)
            let content = ActivityContent(state: initialState, staleDate: nil)
            current = try Activity.request(attributes: attrs, content: content, pushType: nil)
        } catch {
            // ActivityKit rejects when user has disabled LAs, system
            // is out of activity budget, or background restrictions
            // apply. Silent — caller will see isActive stay false.
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
    /// triggered via the Dashboard Stop button.
    func stop() {
        guard let a = current else { return }
        Task { await a.end(nil, dismissalPolicy: .immediate) }
        current = nil
    }

    /// Adopt any previously-persisted activity on app launch so the
    /// `isActive` flag is accurate when the Dashboard renders.
    /// Idempotent.
    func adoptExisting() {
        if let existing = Activity<StatusActivityAttributes>.activities
            .first(where: { $0.activityState == .active }) {
            current = existing
        }
    }
}

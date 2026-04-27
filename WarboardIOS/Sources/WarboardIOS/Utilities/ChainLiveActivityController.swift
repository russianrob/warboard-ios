import Foundation
import ActivityKit

/// Manages the lifecycle of the chain-break Live Activity from the
/// app side. The WarRoomViewModel calls `sync(...)` after every poll;
/// we lazily start an activity when there's a war + chain ≥ 1, push a
/// new ContentState when anything changed, and end the activity when
/// the war ends or there's no chain to track. iOS 16.1+ only — wrapped
/// in availability checks so older devices simply skip the calls.
@MainActor
final class ChainLiveActivityController {
    static let shared = ChainLiveActivityController()
    private init() {}

    private var current: Activity<ChainActivityAttributes>?

    /// Update — or start, or end — the chain Live Activity to match
    /// the war room's current state. Idempotent: calling this on every
    /// poll with the same data is a no-op (Activity.update sends a push
    /// to the system but the widget only re-renders on actual changes).
    func sync(warId: String,
              enemyName: String,
              chain: Int,
              timeoutDeadlineMs: Int64,
              cooldownDeadlineMs: Int64,
              myScore: Int,
              enemyScore: Int,
              warEnded: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // System / user has disabled live activities.
            current = nil
            return
        }

        let state = ChainActivityAttributes.ContentState(
            chain: chain,
            timeoutDeadlineMs: timeoutDeadlineMs,
            cooldownDeadlineMs: cooldownDeadlineMs,
            myScore: myScore,
            enemyScore: enemyScore
        )

        // End conditions — war over, or there's no chain to surface.
        // Don't start an activity for chain == 0 (between chains) since
        // there's nothing to count down to.
        let shouldHaveActivity = !warEnded && chain >= 1
            && (timeoutDeadlineMs > 0 || cooldownDeadlineMs > 0)

        if !shouldHaveActivity {
            if let active = current {
                Task { await active.end(nil, dismissalPolicy: .immediate) }
                current = nil
            }
            return
        }

        let attrs = ChainActivityAttributes(warId: warId, enemyName: enemyName)
        if let active = current,
           active.attributes.warId == warId,
           active.activityState == .active {
            Task { await active.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            do {
                let activity = try Activity<ChainActivityAttributes>.request(
                    attributes: attrs,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                current = activity
            } catch {
                NSLog("[Warboard] Failed to start chain activity: \(error.localizedDescription)")
            }
        }
    }

    /// End any active activity. Called when the user signs out / clears
    /// their API key, or when the war room view explicitly tears down.
    func end() {
        guard #available(iOS 16.1, *), let active = current else { return }
        Task { await active.end(nil, dismissalPolicy: .immediate) }
        current = nil
    }
}

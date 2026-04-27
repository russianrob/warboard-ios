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
    /// Track the most recent (chain, deadline) we pushed so we can
    /// reject staler deadline values from a slower data source. The
    /// war room's /api/poll goes through warboard's chain cache which
    /// can be 5+ s behind /v2/faction direct (what the chain ticker
    /// uses) — without this guard a stale war-room write right after
    /// a fresh ticker write would push the displayed deadline back
    /// up by several seconds.
    private var lastChain: Int = -1
    private var lastTimeoutDeadlineMs: Int64 = 0
    private var lastCooldownDeadlineMs: Int64 = 0

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

        // Freshness guard — when chain count is unchanged, only accept
        // a deadline if it's lower (= fresher) than what we last
        // displayed. Prevents a stale source (warboard cache) from
        // bumping the live activity countdown back up after a fresher
        // source (Torn direct) already displayed a smaller deadline.
        var effectiveTimeout = timeoutDeadlineMs
        var effectiveCooldown = cooldownDeadlineMs
        if chain == lastChain {
            if effectiveTimeout > 0 && lastTimeoutDeadlineMs > 0 {
                effectiveTimeout = min(effectiveTimeout, lastTimeoutDeadlineMs)
            }
            if effectiveCooldown > 0 && lastCooldownDeadlineMs > 0 {
                effectiveCooldown = min(effectiveCooldown, lastCooldownDeadlineMs)
            }
        }
        lastChain = chain
        lastTimeoutDeadlineMs = effectiveTimeout
        lastCooldownDeadlineMs = effectiveCooldown

        let state = ChainActivityAttributes.ContentState(
            chain: chain,
            timeoutDeadlineMs: effectiveTimeout,
            cooldownDeadlineMs: effectiveCooldown,
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
            // Reset freshness guard so a brand-new chain doesn't
            // inherit the prior min deadline.
            lastChain = -1
            lastTimeoutDeadlineMs = 0
            lastCooldownDeadlineMs = 0
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

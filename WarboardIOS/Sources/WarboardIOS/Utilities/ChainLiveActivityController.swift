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
    private init() {
        // Adopt any activity left over from a prior app launch so our
        // first sync() call can end it. Without this, an activity that
        // was alive when the app died (or the user force-quit) lingers
        // on the lock screen indefinitely because our `current`
        // reference is nil → the chain==0 branch's `if let active`
        // guard is false → no end call ever fires.
        if #available(iOS 16.1, *) {
            for a in Activity<ChainActivityAttributes>.activities
            where a.activityState == .active {
                current = a
                break
            }
        }
    }

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

    /// Wall-clock timestamp of the moment we last ended an activity
    /// because `chain` reached 0. Used as a grace window: any sync()
    /// call within 90 s afterwards that reports chain ≥ 1 is treated
    /// as stale data from a lagged source (typically warboard's
    /// /api/poll, which caches Torn responses ~5-15 s behind the
    /// direct /v2/faction reading) and is ignored. Without this guard
    /// the lagged source can re-start the activity moments after we
    /// killed it, then drag through another 30 s tick before settling
    /// on chain==0 and ending again — net effect: the lock-screen
    /// banner flashes back into existence and lingers ~30s instead
    /// of disappearing on the chain break.
    private var lastBrokeAtMs: Int64 = 0
    private static let stalePostBreakWindowMs: Int64 = 90_000

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

        // Stale-data rejection: if the chain just broke (we ended an
        // activity within the last 90 s on chain==0), ignore any sync
        // that says chain ≥ 1. It's almost certainly the lagged
        // warboard /api/poll source still serving its cached pre-break
        // value while Torn-direct already reads 0.
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if chain >= 1
            && lastBrokeAtMs > 0
            && (nowMs - lastBrokeAtMs) < Self.stalePostBreakWindowMs {
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

        // End conditions — war over, chain == 0 (between chains), OR
        // the displayed timeout has already elapsed in wall-clock time.
        // Without the elapsed check, the Dynamic Island / lock-screen
        // widget visibly sits at "0:00" between the moment the chain
        // breaks (deadline past) and the next /api/poll cycle (~15 s)
        // when chain finally reports as 0. Killing the activity the
        // instant the deadline passes hides the dead 0:00 immediately.
        let timeoutElapsed = effectiveTimeout > 0 && effectiveTimeout <= nowMs
        let cooldownElapsed = effectiveCooldown > 0 && effectiveCooldown <= nowMs
        // If we still have a live cooldown (chain hit cooldown but
        // hasn't broken yet), keep the activity to show the cooldown
        // bar. Only end if BOTH timer dimensions are dead.
        let anyTimerLive = (effectiveTimeout > 0 && !timeoutElapsed)
            || (effectiveCooldown > 0 && !cooldownElapsed)
        let shouldHaveActivity = !warEnded && chain >= 1 && anyTimerLive

        if !shouldHaveActivity {
            // Treat THIS call as the moment of the break only when
            // chain==0 (true break) — not when warEnded or timer
            // expiry triggered the end via a different path. Keeps
            // the stale-data guard scoped to actual chain breaks.
            if chain == 0 { lastBrokeAtMs = nowMs }
            endAllActivities()
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
        guard #available(iOS 16.1, *) else { return }
        endAllActivities()
    }

    /// End every running ChainActivityAttributes activity, not just
    /// our `current` reference. Catches orphaned activities (started
    /// in a previous app launch we lost the reference to) and any
    /// duplicate activities iOS may have spawned across writer races.
    /// Pushes a final ContentState before dismissal so the widget
    /// stops showing the pre-break countdown during the brief
    /// dismissal animation — without a final push, iOS occasionally
    /// freezes the last `update` content for the whole dismissal.
    @available(iOS 16.1, *)
    private func endAllActivities() {
        let zeroState = ChainActivityAttributes.ContentState(
            chain: 0,
            timeoutDeadlineMs: 0,
            cooldownDeadlineMs: 0,
            myScore: 0,
            enemyScore: 0
        )
        let finalContent = ActivityContent(
            state: zeroState,
            staleDate: Date().addingTimeInterval(-1)
        )
        for activity in Activity<ChainActivityAttributes>.activities {
            Task {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
        current = nil
    }
}

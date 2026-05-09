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
        //
        // BUT: if the adopted activity was created with pushType: nil
        // (older app version, or the .token request failed and fell back),
        // it has no push token and can never receive APNs Live Activity
        // updates. End it immediately so the next sync() call creates a
        // fresh activity with pushType: .token. iOS exposes
        // `activity.pushToken` (singular, iOS 16.1) which is nil for
        // .nil-pushType activities and Data for .token activities.
        if #available(iOS 16.1, *) {
            for a in Activity<ChainActivityAttributes>.activities
            where a.activityState == .active {
                if a.pushToken == nil {
                    // Stale .nil-pushType activity from an older build.
                    // End it without adopting; next sync() creates fresh.
                    Task { await a.end(nil, dismissalPolicy: .immediate) }
                    continue
                }
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

    /// Long-lived task watching the current activity's pushTokenUpdates
    /// async sequence. Each token (initial issue + any subsequent
    /// rotation iOS performs) gets POSTed to the warboard server's
    /// /api/live-activity/chain/subscribe so the chain monitor can fan
    /// out APNs Live Activity pushes when chain state changes —
    /// fixing the "0:00 forever in the background" symptom that local-
    /// only activities suffered from.
    private var pushTokenTask: Task<Void, Never>?
    /// Most recent (warId, baseUrl, jwt) we registered against — kept
    /// so we can fire the matching unsubscribe POST from endAllActivities.
    private var lastRegistration: (warId: String, baseUrl: String, jwt: String)?

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
              warEnded: Bool,
              baseUrl: String = "",
              jwt: String = "") {
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
        // BUT: only clamp to a previous deadline that is still in the
        // future. If the prior deadline already elapsed, clamping would
        // lock the widget to a past timestamp and `Text(timerInterval:)`
        // would render "0:00" indefinitely even after a fresh Torn-
        // direct read returned a real future deadline.
        var effectiveTimeout = timeoutDeadlineMs
        var effectiveCooldown = cooldownDeadlineMs
        if chain == lastChain {
            if effectiveTimeout > 0 && lastTimeoutDeadlineMs > nowMs {
                effectiveTimeout = min(effectiveTimeout, lastTimeoutDeadlineMs)
            }
            if effectiveCooldown > 0 && lastCooldownDeadlineMs > nowMs {
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
            // v0.4.50: also (re-)POST the current push token here. Without
            // this the iOS app only registers in the "create new activity"
            // branch — meaning if the server forgets the token (storage
            // wipe, restart, etc.) the app never re-registers it for the
            // existing activity, and APNs pushes go to a server that has
            // no record. Idempotent on server side (upsert).
            if #available(iOS 16.2, *) {
                if pushTokenTask == nil || pushTokenTask?.isCancelled == true {
                    pushTokenTask = makePushTokenWatcher(activity: active, baseUrl: baseUrl, jwt: jwt)
                }
                // Even if the watcher is already running (it'll re-yield on
                // next token rotation), opportunistically read the current
                // pushToken sync and POST it now so the server doesn't have
                // to wait for a rotation event that may never come.
                if let tokenData = active.pushToken {
                    let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                    let bu = baseUrl, jw = jwt, wid = warId
                    Task { await Self.postLiveActivitySubscribe(baseUrl: bu, jwt: jw, warId: wid, token: hex) }
                }
            }
        } else {
            // v0.4.51: end every other live activity of this attribute
            // type before creating a new one, so the lock screen never
            // accumulates duplicate stale chain banners. Common cause:
            // an old activity from a previous warId or from a previous
            // build (with pushType: nil) that didn't get cleaned up by
            // init()'s pushToken==nil filter (because it has a token,
            // it's just not the right one).
            for stale in Activity<ChainActivityAttributes>.activities
            where stale.activityState == .active {
                Task { await stale.end(nil, dismissalPolicy: .immediate) }
            }

            // Try .token first (APNs push fanout from the warboard server,
            // works while backgrounded/terminated). If that throws — most
            // commonly because the app's aps-environment entitlement isn't
            // set up or Push Notifications isn't enabled on the App ID —
            // fall back to .nil so the user still gets a local-only
            // activity. Without this fallback the activity silently fails
            // to start and the user sees no island at all.
            let content = ActivityContent(state: state, staleDate: nil)
            var startedActivity: Activity<ChainActivityAttributes>? = nil
            do {
                startedActivity = try Activity<ChainActivityAttributes>.request(
                    attributes: attrs, content: content, pushType: .token)
            } catch {
                NSLog("[Warboard] Live Activity push-token request failed (\(error.localizedDescription)); falling back to local-only.")
                do {
                    startedActivity = try Activity<ChainActivityAttributes>.request(
                        attributes: attrs, content: content, pushType: nil)
                } catch {
                    NSLog("[Warboard] Live Activity local-only request also failed: \(error.localizedDescription)")
                }
            }
            if let activity = startedActivity {
                current = activity
                // Watch for the activity's push token (only fires when the
                // request used .token). Cancel any prior watcher first.
                // pushTokenUpdates is iOS 16.2+ (Activity.request itself
                // is 16.1, hence the inner check).
                pushTokenTask?.cancel()
                if #available(iOS 16.2, *) {
                    pushTokenTask = makePushTokenWatcher(activity: activity, baseUrl: baseUrl, jwt: jwt)
                }
            }
        }
    }

    /// Spawn the long-lived async iterator over the activity's push
    /// token updates. Each token (initial + rotations) is hex-encoded
    /// and POSTed to /api/live-activity/chain/subscribe with the warId
    /// + JWT auth. Survives token rotations Apple may do during the
    /// activity's lifetime.
    @available(iOS 16.2, *)
    private func makePushTokenWatcher(activity: Activity<ChainActivityAttributes>,
                                      baseUrl: String,
                                      jwt: String) -> Task<Void, Never>? {
        guard !baseUrl.isEmpty, !jwt.isEmpty else { return nil }
        let warId = activity.attributes.warId
        return Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                if Task.isCancelled { return }
                let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                await Self.postLiveActivitySubscribe(baseUrl: baseUrl, jwt: jwt, warId: warId, token: hex)
                await MainActor.run {
                    self?.lastRegistration = (warId: warId, baseUrl: baseUrl, jwt: jwt)
                }
            }
        }
    }

    /// POST the activity push token to the server. Best-effort —
    /// network failures are logged via NSLog but don't propagate; the
    /// activity continues showing its locally-pushed countdown.
    private static func postLiveActivitySubscribe(baseUrl: String, jwt: String, warId: String, token: String) async {
        guard let url = URL(string: baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/live-activity/chain/subscribe") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "warId": warId,
            "token": token,
        ])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                NSLog("[Warboard] Live Activity subscribe got HTTP \(http.statusCode)")
            }
        } catch {
            NSLog("[Warboard] Live Activity subscribe failed: \(error.localizedDescription)")
        }
    }

    /// POST unsubscribe so the server stops trying to push to a token
    /// Apple has invalidated. Best-effort.
    private static func postLiveActivityUnsubscribe(baseUrl: String, jwt: String, warId: String) async {
        guard let url = URL(string: baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/live-activity/chain/unsubscribe") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["warId": warId])
        do { _ = try await URLSession.shared.data(for: req) } catch { /* best-effort */ }
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
        // Stop watching for token rotations on the activity we're killing
        // and tell the server to drop our token so it stops pushing to a
        // dead address. Both are best-effort.
        pushTokenTask?.cancel()
        pushTokenTask = nil
        if let reg = lastRegistration {
            Task.detached {
                await Self.postLiveActivityUnsubscribe(
                    baseUrl: reg.baseUrl, jwt: reg.jwt, warId: reg.warId)
            }
        }
        lastRegistration = nil

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

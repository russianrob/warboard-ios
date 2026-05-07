import Foundation
import Combine
import SocketIO

/// War Room state holder. Polls `/api/faction/<fid>/war` + `/api/poll`
/// every 15 s. Mirrors the Android `WarRoomViewModel` shape so future
/// features (heatmap, scout report, engines) plug in symmetrically.
@MainActor
final class WarRoomViewModel: ObservableObject {
    enum State: Equatable {
        case noKey, loading, noWar, active(WarSnapshot)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var poll: WarPoll?
    @Published private(set) var lastPolledAt: Date?
    /// Scout report — loaded on demand when the Report sub-tab opens.
    @Published private(set) var scoutReport: ScoutReport?
    @Published private(set) var scoutLoading = false
    /// Post-war report — loaded on demand when the user opens the
    /// modal from the war-ended banner.
    @Published private(set) var postWarReport: PostWarReport?
    @Published private(set) var postWarLoading = false
    @Published private(set) var postWarError: String?
    /// Both faction heatmaps. Refreshed each war-poll tick.
    @Published private(set) var ourHeatmap:  [Int: [Int: HeatmapCell]] = [:]
    @Published private(set) var theirHeatmap: [Int: [Int: HeatmapCell]] = [:]
    /// FFScouter battle-stat estimates per enemy id (server-cached 30 min).
    @Published private(set) var enemyStats: [String: Int64] = [:]
    /// FFS player-flights data per traveling enemy.
    @Published private(set) var travelInfo: [String: TravelInfo] = [:]
    /// Last shout result — nil = no shout sent yet, .ok = success snackbar.
    @Published var shoutResult: String?

    /// Bound at .task time from the View — see `bind(prefs:)`. The VM
    /// can't take prefs at init because @StateObject is constructed
    /// before @EnvironmentObject is available. Until binding lands the
    /// VM stays in the .loading state and the polling loop is a no-op.
    private var prefs: PrefsStore?
    private var auth: AuthRepository?
    private var task: Task<Void, Never>?
    /// Per-enemy releaseAtMs from the previous tick — drives the
    /// monotonic guard so a stale poll can't bump release times forward.
    private var lastReleaseAtMs: [String: Int64] = [:]
    /// Chain-alert latches — only fire each threshold notification once
    /// per chain "life" (cleared when chain count flips, mirrors the
    /// userscript's chainAlertFired/chainPanicFired latches).
    private var chainAlertFired = false
    private var chainPanicFired = false
    private var lastChainCountForAlerts: Int?
    /// Wall-clock deadlines stamped at fetch time so ChainBar can
    /// compute remaining = (deadline - now) per render and tick down
    /// smoothly between the 15 s API polls. Min-of-(prev, new) when
    /// the chain count is unchanged so a stale Torn cache returning a
    /// higher timeout can't bump the displayed countdown back up.
    @Published private(set) var chainTimeoutDeadlineMs: Int64 = 0
    @Published private(set) var chainCooldownDeadlineMs: Int64 = 0
    private var lastChainCountForDeadline: Int?
    /// Post-war stickiness — when /api/faction/<fid>/war goes empty
    /// but poll.warEnded is true, hold the last WarSnapshot active for
    /// 10 min so the VICTORY/DEFEAT banner has a chance to render.
    private var postWarHoldStartMs: Int64 = 0
    private let postWarHoldDurationMs: Int64 = 10 * 60 * 1000
    /// Combine subscription bag for RealtimeClient events. Cancelled
    /// when the VM stops so we don't keep getting events after the
    /// War tab has been left.
    private var realtimeBag = Set<AnyCancellable>()

    init() { }

    func bind(prefs: PrefsStore) {
        self.prefs = prefs
        self.auth = AuthRepository(prefs: prefs)
    }

    /// Wallclock guard against rapid re-fire of start(). SwiftUI's
    /// .onAppear / .task can fire repeatedly when a parent view
    /// re-renders — opening a sheet, dismissing a modal, switching
    /// tabs, scroll-restore on the Chat tab, etc. Each fire used to
    /// cancel the previous Task and immediately run tick() (no initial
    /// sleep), which fires fetchPoll + 2× fetchHeatmap + fetchTravelInfo
    /// + fetchWars in parallel. A storm of .onAppear (e.g. 9 calls in
    /// 91 ms — observed in production logs as "[ws] MrCurly joined war
    /// room war_war_42055 ×9 within 91 ms") therefore spawned a wave of
    /// 50+ HTTP requests per second, blew through the server's per-IP
    /// rate limit, and caused the iOS app to surface "network error"
    /// for every faction member.
    private var lastStartedAt: Date = .distantPast
    private static let startDebounceSec: TimeInterval = 5.0

    func start() {
        // Debounce — see lastStartedAt comment above. If start() was
        // already called within the last 5 seconds, the existing task
        // is still active and there's nothing to do. The Task already
        // running will continue ticking on its 15 s / 60 s schedule.
        let elapsed = Date().timeIntervalSince(lastStartedAt)
        if elapsed < Self.startDebounceSec, task != nil {
            return
        }
        lastStartedAt = Date()
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                // 60s polling fallback when the realtime socket is up
                // (events drive most updates), 15s when it's down.
                let interval: UInt64 = (await RealtimeClient.shared.connected)
                    ? 60_000_000_000
                    : 15_000_000_000
                try? await Task.sleep(nanoseconds: interval)
            }
        }
        subscribeToRealtimeEvents()
    }

    func stop() {
        task?.cancel(); task = nil
        realtimeBag.removeAll()
    }

    /// Wire the RealtimeClient → ViewModel pipe. Most events just
    /// trigger an immediate poll (refresh) — the server's payload is
    /// rich but we'd be re-implementing every parser to apply it
    /// in-place. A refresh round-trip is still ~10x faster than
    /// waiting for the next 60 s poll.
    private func subscribeToRealtimeEvents() {
        realtimeBag.removeAll()
        RealtimeClient.shared.events
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .warUpdate, .warState,
                     .targetCalled, .targetUncalled,
                     .statusUpdate, .statusUpdated, .statusesRefreshed:
                    self.refresh()
                case .warEnded:
                    // Force a refresh so poll.warEnded flips and the
                    // banner appears immediately rather than at the
                    // next scheduled poll.
                    self.refresh()
                case .memberBars, .globalToast,
                     .chatMessage, .chatDeleted:
                    // Not consumed here — FactionViewModel handles
                    // member_bars; toasts are app-wide; chat events
                    // are owned by ChatViewModel scoped to the Chat tab.
                    break
                }
            }
            .store(in: &realtimeBag)
    }

    /// Coalesce rapid realtime-event-driven refreshes. Without this,
    /// one war_update / status_refreshed event = one full tick() = 5-7
    /// HTTP fetches. The server can fire 20+ status events per second
    /// during active war polling (each enemy member status update is
    /// its own event), which compounded to 25+ refresh()/sec → 100+
    /// fetches/sec → server's per-JWT 429 cap → "network error" toast.
    /// This guard fires at most one tick per `refreshDebounceSec`.
    private var lastRefreshAt: Date = .distantPast
    private static let refreshDebounceSec: TimeInterval = 2.0

    func refresh() {
        let elapsed = Date().timeIntervalSince(lastRefreshAt)
        if elapsed < Self.refreshDebounceSec { return }
        lastRefreshAt = Date()
        Task { await tick() }
    }

    func call(_ target: EnemyTarget) async {
        await callTarget(target, action: "call", isDeal: false)
    }
    func uncall(_ target: EnemyTarget) async {
        await callTarget(target, action: "uncall", isDeal: false)
    }
    /// Deal call — multi-hit, 15-min timeout. Triggered from a
    /// long-press (≥0.6s) on the Attack button; the row visually
    /// tints orange while the user is holding to confirm the gesture
    /// is registering.
    func dealCall(_ target: EnemyTarget) async {
        await callTarget(target, action: "call", isDeal: true)
    }

    private func callTarget(_ target: EnemyTarget, action: String, isDeal: Bool = false) async {
        guard case .active(let war) = state,
              let prefs = prefs, let auth = auth,
              let a = await auth.ensureAuth() else { return }
        _ = await WarboardAPI.callTarget(
            baseUrl: prefs.baseUrl, jwt: a.token,
            warId: war.warId, action: action,
            targetId: target.id, targetName: target.name,
            isDeal: isDeal
        )
        await tick()
    }

    /// Anchor for chain-deadline math — set right BEFORE the network
    /// call so we can subtract round-trip lag when stamping deadlines.
    /// `now + chainTimeout * 1000` (post-RTT) drifts ~1-2 s ahead of
    /// what Torn shows because the chainTimeout value Torn returned
    /// was computed when our request landed there, not when we got
    /// the response back. Using the request-start time as the anchor
    /// effectively rewinds the deadline by approximately the RTT.
    private var lastTickRequestStartMs: Int64 = 0

    private func tick() async {
        guard let prefs = prefs, let auth = auth else { return }
        if prefs.apiKey.isEmpty { state = .noKey; return }
        guard let a = await auth.ensureAuth() else { state = .noKey; return }
        // Realtime: connect once we have a JWT, then subscribe to the
        // war's room as soon as we know the warId. Idempotent — the
        // client no-ops when already connected with the same JWT.
        RealtimeClient.shared.connect(baseUrl: prefs.baseUrl, jwt: a.token)
        lastTickRequestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        let warsOptional = await WarboardAPI.fetchWars(
            baseUrl: prefs.baseUrl, factionId: a.factionId, jwt: a.token
        )
        // Transient fetch error (429, 5xx, network) → keep prior state
        // and bail. Without this guard, a runaway-storm 429 would flip
        // the UI to .noWar even though a war is genuinely active.
        guard let wars = warsOptional else { return }
        lastPolledAt = Date()
        // Post-war stickiness — server filters out warEnded wars from
        // the wars endpoint, so when a war ends both the active war
        // AND the banner would silently disappear. Hold the last
        // snapshot in .active state for 10 min after poll.warEnded
        // flips so the VICTORY/DEFEAT banner gets a chance to show.
        let previousActive: WarSnapshot? = {
            if case .active(let w) = state { return w }
            return nil
        }()
        if wars.isEmpty {
            if let prev = previousActive, poll?.warEnded == true {
                if postWarHoldStartMs == 0 {
                    postWarHoldStartMs = Int64(Date().timeIntervalSince1970 * 1000)
                }
                let held = Int64(Date().timeIntervalSince1970 * 1000) - postWarHoldStartMs
                if held < postWarHoldDurationMs {
                    state = .active(prev)
                    // Refresh poll on the held war so warEnded stays current.
                    if let fresh = await WarboardAPI.fetchPoll(
                        baseUrl: prefs.baseUrl, jwt: a.token, warId: prev.warId
                    ) { poll = fresh }
                    return
                }
                postWarHoldStartMs = 0
            } else {
                postWarHoldStartMs = 0
            }
            state = .noWar
            return
        }
        postWarHoldStartMs = 0
        // Server returns both the real war record (warId = numeric Torn
        // ID like "40638") AND a synthetic placeholder (warId =
        // "war_<factionId>", used when no real warId is known yet). Prefer
        // the real one — joining the synthetic room means broadcasts /
        // realtime events emitted to the real war's room never reach us.
        let chosen = wars.first(where: { !$0.warId.hasPrefix("war_") }) ?? wars[0]
        let merged = mergeMonotonic(chosen)
        state = .active(merged)
        RealtimeClient.shared.joinWar(warId: merged.warId, factionId: a.factionId)
        if let fresh = await WarboardAPI.fetchPoll(
            baseUrl: prefs.baseUrl, jwt: a.token, warId: merged.warId
        ) {
            poll = fresh
        }
        // Both faction heatmaps — same endpoint, different factionId.
        // Diverging-color grid in the Heatmap sub-tab consumes both.
        ourHeatmap = await WarboardAPI.fetchHeatmap(
            baseUrl: prefs.baseUrl, jwt: a.token, factionId: a.factionId
        )
        if !merged.enemyFactionId.isEmpty {
            theirHeatmap = await WarboardAPI.fetchHeatmap(
                baseUrl: prefs.baseUrl, jwt: a.token, factionId: merged.enemyFactionId
            )
        }
        // Enemy stats — fetch once per war (server-cached). Travel info
        // refreshes every tick so countdowns stay accurate near landing.
        if enemyStats.isEmpty {
            enemyStats = await WarboardAPI.fetchEnemyStats(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: merged.warId
            )
        }
        travelInfo = await WarboardAPI.fetchTravelInfo(
            baseUrl: prefs.baseUrl, jwt: a.token, warId: merged.warId
        )
        await updateChainDeadlines(merged: merged)
        evaluateChainAlerts(prefs: prefs)
        syncLiveActivity(merged: merged)
    }

    /// Mirror the chain state into the Live Activity so the lock-screen
    /// banner + Dynamic Island show the same countdown the in-app
    /// ChainBar does.
    private func syncLiveActivity(merged: WarSnapshot) {
        let chain = poll?.chainCurrent ?? merged.chainCurrent ?? 0
        let myScore    = poll?.myScore    ?? merged.myScore
        let enemyScore = poll?.enemyScore ?? merged.enemyScore
        let enemyName  = merged.enemyFactionName ?? poll?.enemyFactionName ?? "Enemy"
        ChainLiveActivityController.shared.sync(
            warId: merged.warId,
            enemyName: enemyName,
            chain: chain,
            timeoutDeadlineMs: chainTimeoutDeadlineMs,
            cooldownDeadlineMs: chainCooldownDeadlineMs,
            myScore: myScore,
            enemyScore: enemyScore,
            warEnded: poll?.warEnded == true
        )
    }

    /// Convert the freshly-fetched chain timeout/cooldown seconds into
    /// absolute wall-clock deadlines. ChainBar then derives the live
    /// countdown each render via (deadline - now). Same min-of-(prev,
    /// new) trick as the menu-bar ticker so a stale Torn cache can't
    /// bump the timer back up.
    private func updateChainDeadlines(merged: WarSnapshot) async {
        // Bypass warboard's chain cache (which can be 5+ s stale)
        // and pull chain directly from Torn /v2/faction. Anchor the
        // deadline on the request-start time so we also subtract
        // the network RTT.
        let chainRequestStart = Int64(Date().timeIntervalSince1970 * 1000)
        var chain = poll?.chainCurrent ?? merged.chainCurrent ?? 0
        var toSec = (poll?.chainTimeout  ?? merged.chainTimeout)  ?? 0
        var cdSec = (poll?.chainCooldown ?? merged.chainCooldown) ?? 0
        var anchor = lastTickRequestStartMs > 0
            ? lastTickRequestStartMs
            : Int64(Date().timeIntervalSince1970 * 1000)
        if let prefs = prefs,
           let fresh = await TornAPI.fetchFactionChain(apiKey: prefs.apiKey) {
            chain = fresh.current
            toSec = fresh.timeout
            cdSec = fresh.cooldown
            anchor = chainRequestStart
        }
        let incomingTo = toSec > 0 ? anchor + toSec * 1000 : 0
        let incomingCd = cdSec > 0 ? anchor + cdSec * 1000 : 0
        let countChanged = lastChainCountForDeadline != chain

        if incomingTo == 0 || countChanged || chainTimeoutDeadlineMs == 0 {
            chainTimeoutDeadlineMs = incomingTo
        } else {
            chainTimeoutDeadlineMs = min(chainTimeoutDeadlineMs, incomingTo)
        }
        if incomingCd == 0 || countChanged || chainCooldownDeadlineMs == 0 {
            chainCooldownDeadlineMs = incomingCd
        } else {
            chainCooldownDeadlineMs = min(chainCooldownDeadlineMs, incomingCd)
        }
        lastChainCountForDeadline = chain
    }

    /// Mirrors the userscript's chain alert thresholds (60 s warning,
    /// 30 s panic) — fires a macOS notification per threshold once per
    /// chain "life," clears the latch when the count changes (new hit
    /// → fresh alert window) or the timer recovers above 60 s.
    private func evaluateChainAlerts(prefs: PrefsStore) {
        guard prefs.notifyChain else { return }
        guard case .active(let war) = state else { return }
        let chain = poll?.chainCurrent ?? war.chainCurrent ?? 0
        let to = (poll?.chainTimeout ?? war.chainTimeout) ?? 0
        // Reset latches when count changes (new hit lands) or when the
        // chain breaks (count → 0).
        if lastChainCountForAlerts != chain {
            chainAlertFired = false
            chainPanicFired = false
            lastChainCountForAlerts = chain
        }
        // Recover above 60 s — clear so a later dip retrigggers.
        if to > 60 {
            chainAlertFired = false
            chainPanicFired = false
        }
        // Only alert once chain is genuine (≥10) so the script's "warmup"
        // ticks don't spam notifications.
        guard chain >= 10, to > 0 else { return }
        if to <= 30 && !chainPanicFired {
            chainPanicFired = true
            NotificationManager.shared.fire(
                title: "🚨 Chain dying — \(to)s!",
                body: "Chain \(chain) about to break. Hit now.",
                category: .chainPanic,
                id: "war-\(war.warId)-c\(chain)"
            )
        } else if to <= 60 && !chainAlertFired {
            chainAlertFired = true
            NotificationManager.shared.fire(
                title: "⚠️ Chain breaking",
                body: "Chain \(chain) — \(to)s left. Attack soon.",
                category: .chainBreaking,
                id: "war-\(war.warId)-c\(chain)"
            )
        }
    }

    /// Fire a faction-wide shout — calls /api/broadcast. Server gates
    /// on leader/banker; non-leaders get the rejection in shoutResult.
    func sendShout(_ message: String) {
        Task {
            guard let prefs = prefs, let auth = auth,
                  case .active(let war) = state,
                  let a = await auth.ensureAuth() else { return }
            let result = await WarboardAPI.sendBroadcast(
                baseUrl: prefs.baseUrl, jwt: a.token,
                warId: war.warId, message: message
            )
            switch result {
            case .ok:
                shoutResult = "Shout sent"
                // Local echo — surface OUR own broadcast to the toast
                // overlay immediately. Without this, the sender's toast
                // only appears when Socket.IO happens to be connected at
                // shout time (race on cold-start: tick → ensureAuth →
                // RealtimeClient.connect can lag the shout by seconds).
                RealtimeClient.shared.injectGlobalToast([
                    "message": message,
                    "type": "warning",
                    "senderName": "You",
                ])
            case .error(let msg):    shoutResult = "Shout failed: \(msg)"
            }
        }
    }

    /// Lazy post-war-report fetch — fired when the user taps the
    /// "View Report" button on the war-ended banner.
    func loadPostWarReport() {
        Task {
            guard let prefs = prefs, let auth = auth,
                  case .active(let war) = state,
                  let a = await auth.ensureAuth() else { return }
            postWarLoading = true
            postWarError = nil
            postWarReport = await WarboardAPI.fetchPostWarReport(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: war.warId
            )
            postWarLoading = false
            if postWarReport == nil {
                postWarError = "Couldn't load post-war report."
            }
        }
    }

    /// Lazy scout-report fetch fired when the Report sub-tab opens. The
    /// report endpoint hits FFScouter + Torn API server-side and is
    /// rate-limited to a few requests per minute, so we don't auto-poll.
    func loadScoutReport() {
        Task {
            guard let prefs = prefs, let auth = auth,
                  case .active(let war) = state,
                  let a = await auth.ensureAuth() else { return }
            scoutLoading = true
            scoutReport = await WarboardAPI.fetchScoutReport(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: war.warId
            )
            scoutLoading = false
        }
    }

    /// Same min-of-(prev, new) trick as the Android client — keeps
    /// hospital / jail countdowns from rebounding when Torn's API
    /// returns a stale "still N seconds" value mid-tick.
    private func mergeMonotonic(_ fresh: WarSnapshot) -> WarSnapshot {
        let rebased = fresh.targets.map { t -> EnemyTarget in
            let key = "\(t.id)|\(t.status)"
            guard t.releaseAtMs > 0 else {
                lastReleaseAtMs.removeValue(forKey: key)
                return t
            }
            let previous = lastReleaseAtMs[key] ?? 0
            let winner = previous > 0 ? min(previous, t.releaseAtMs) : t.releaseAtMs
            lastReleaseAtMs[key] = winner
            if winner == t.releaseAtMs { return t }
            return EnemyTarget(
                id: t.id, name: t.name, level: t.level, status: t.status,
                description: t.description, untilSec: t.untilSec,
                releaseAtMs: winner, activity: t.activity,
                calledBy: t.calledBy, calledById: t.calledById,
                calledIsDeal: t.calledIsDeal
            )
        }
        let liveKeys = Set(fresh.targets.map { "\($0.id)|\($0.status)" })
        lastReleaseAtMs = lastReleaseAtMs.filter { liveKeys.contains($0.key) }
        return WarSnapshot(
            warId: fresh.warId, enemyFactionId: fresh.enemyFactionId,
            enemyFactionName: fresh.enemyFactionName,
            myScore: fresh.myScore, enemyScore: fresh.enemyScore,
            warStart: fresh.warStart, warOrigTarget: fresh.warOrigTarget,
            currentTarget: fresh.currentTarget,
            chainCurrent: fresh.chainCurrent, chainTimeout: fresh.chainTimeout,
            chainCooldown: fresh.chainCooldown,
            targets: rebased
        )
    }
}

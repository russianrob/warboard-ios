import Foundation
import Combine

/// Backs the War Payouts screen. Resolves the JWT via `AuthRepository`
/// (same flow as War Room), finds the most-recent ended war from
/// `/api/war/admin-list`, then loads its `dynamic`-mode payout object.
///
/// Loaded on demand from the View's `.onAppear` (`bind` then `start`),
/// with a 60s staleness gate and the OC Manager "keep prior `.ready`
/// data on a transient error" behaviour.
@MainActor
final class WarPayoutsViewModel: ObservableObject {

    enum LoadState<T: Equatable>: Equatable {
        case idle
        case loading
        case ready(T)
        case error(String)
    }

    @Published private(set) var state: LoadState<WarboardAPI.WarPayouts> = .idle

    /// Compute mode — "dynamic" (score-weighted) or "static" (per-hit).
    /// Transient: changing it just re-fetches with the new query param.
    @Published var mode: String = "dynamic"

    /// True while a settings POST + re-fetch is in flight, so the
    /// settings sheet can show progress and disable its Apply button.
    @Published private(set) var applying = false

    private var prefs: PrefsStore?
    private var auth: AuthRepository?
    private var lastFetch: Date?
    /// The war the settings POST + re-fetch target — the most-recent
    /// ended war from `admin-list`. Nil when there's no ended war.
    private var warId: String?

    /// True when the loaded payout is an archived (frozen) war — admin
    /// settings then no-op.
    var currentArchived: Bool {
        if case .ready(let p) = state { return p.isArchived }
        return false
    }

    func bind(prefs: PrefsStore) {
        self.prefs = prefs
        self.auth = AuthRepository(prefs: prefs)
    }

    /// Initial load on appear — only fetches if stale (or never loaded).
    func start() {
        Task { await load(force: false) }
    }

    /// Explicit user refresh (toolbar / pull) — always refetches.
    func refresh() {
        Task { await load(force: true) }
    }

    private func load(force: Bool) async {
        guard let prefs = prefs, let auth = auth else { return }
        if prefs.apiKey.isEmpty {
            state = .error("Set your Torn API key in Settings.")
            return
        }
        let stale = lastFetch.map { Date().timeIntervalSince($0) > 60 } ?? true
        guard force || stale else { return }

        if case .ready = state { /* keep prior data while refetching */ }
        else { state = .loading }

        guard let a = await auth.ensureAuth() else {
            if case .ready = state { /* leave intact */ }
            else { state = .error("Couldn't authenticate. Check your API key in Settings.") }
            return
        }

        do {
            let wars = try await WarboardAPI.fetchPayoutWars(
                baseUrl: prefs.baseUrl, jwt: a.token
            )
            guard let latest = wars.first else {
                // No ended wars — a clean empty state, not an error.
                // An empty payouts object (no members) drives the View's
                // "No completed wars yet" empty state through `.ready`.
                warId = nil
                state = .ready(WarboardAPI.WarPayouts())
                lastFetch = Date()
                return
            }
            warId = latest.warId
            let payouts = try await WarboardAPI.fetchWarPayouts(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: latest.warId, mode: mode
            )
            state = .ready(payouts)
            lastFetch = Date()
        } catch let oc as OCAPIError {
            // 403 is the faction-admin gate — surface the precise reason.
            if case .http(403) = oc {
                if case .ready = state { /* leave intact */ }
                else { state = .error("Admin role required.") }
            } else if oc.isTransient {
                // Keep prior data on screen — refresh retries; flipping to
                // an error placeholder for a single 504 is jarring.
                if case .ready = state { /* leave intact */ }
                else { state = .error(oc.errorDescription ?? "Torn is slow.") }
            } else {
                state = .error(oc.errorDescription ?? "Couldn't load payouts.")
            }
        } catch {
            state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    /// Switch compute mode (Dynamic / Static) and re-fetch. The mode is a
    /// transient query param — no settings POST.
    func setMode(_ m: String) {
        mode = m
        Task { await load(force: true) }
    }

    /// Persist the admin's changed payout settings, then re-fetch so the
    /// recomputed amounts show. Pass nil for any field left unchanged —
    /// only non-nil fields are POSTed. No-op on archived (frozen) wars.
    func apply(lootOverride: Double?, payoutPct: Double?,
               assistWeight: Double?, nonWarWeight: Double?, failedWeight: Double?) async {
        guard let warId, let prefs, let auth else { return }
        // Archived wars are read-only — settings only apply to a war
        // still being computed.
        guard !currentArchived else { return }

        var dict: [String: Double] = [:]
        if let lootOverride { dict["lootOverride"] = lootOverride }
        if let payoutPct { dict["payoutPct"] = payoutPct }
        if let assistWeight { dict["assistWeight"] = assistWeight }
        if let nonWarWeight { dict["nonWarWeight"] = nonWarWeight }
        if let failedWeight { dict["failedWeight"] = failedWeight }

        // Nothing changed — just re-fetch (e.g. a mode-only Apply already
        // refetched via setMode; this keeps the data fresh).
        guard !dict.isEmpty else { await load(force: true); return }

        applying = true
        defer { applying = false }

        guard let a = await auth.ensureAuth() else {
            if case .ready = state { /* keep prior data */ }
            else { state = .error("Couldn't authenticate. Check your API key in Settings.") }
            return
        }
        do {
            try await WarboardAPI.setPayoutSettings(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: warId, settings: dict
            )
            await load(force: true)
        } catch let oc as OCAPIError {
            // Keep prior data on screen if we had it — match load()'s
            // keep-prior-`.ready` behaviour.
            if case .ready = state { /* leave intact */ }
            else { state = .error(oc.errorDescription ?? "Couldn't apply settings.") }
        } catch {
            if case .ready = state { /* leave intact */ }
            else { state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)") }
        }
    }
}

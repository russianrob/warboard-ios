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

    private var prefs: PrefsStore?
    private var auth: AuthRepository?
    private var lastFetch: Date?

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
                state = .ready(WarboardAPI.WarPayouts())
                lastFetch = Date()
                return
            }
            let payouts = try await WarboardAPI.fetchWarPayouts(
                baseUrl: prefs.baseUrl, jwt: a.token, warId: latest.warId
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
}

import Foundation
import SwiftUI

/// App-level loop that pushes our bars + cooldowns to warboard every
/// 60 s while the app is foregrounded, regardless of which tab is
/// active. Without this, bars only get reported when the Status tab
/// is on screen — so a member who opens the app and immediately taps
/// over to the War tab would appear stale to the rest of the faction.
@MainActor
final class BarReporter: ObservableObject {
    static let intervalSeconds: UInt64 = 60

    private var prefs: PrefsStore?
    private var auth: AuthRepository?
    private var task: Task<Void, Never>?

    func bind(prefs: PrefsStore) {
        self.prefs = prefs
        self.auth = AuthRepository(prefs: prefs)
    }

    /// Idempotent — repeated calls do not stack loops. Safe to call
    /// from scenePhase transitions on every .active without cancelling
    /// what's already running.
    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: BarReporter.intervalSeconds * 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        guard let prefs = prefs, !prefs.apiKey.isEmpty else { return }
        guard let auth = auth, let a = await auth.ensureAuth() else { return }

        // Run the bars + attacks fetches concurrently — they're both
        // independent Torn calls on the user's own key, no reason to
        // serialize. attacks is best-effort: if the call fails or there
        // are no fights, we still want bars to push.
        async let snapTask = TornAPI.fetchDashboard(apiKey: prefs.apiKey)
        async let attacksTask = TornAPI.fetchMyAttacks(apiKey: prefs.apiKey)
        let snap = await snapTask
        let attacks = await attacksTask

        if let snap = snap, snap.error == nil {
            await WarboardAPI.reportMyBars(baseUrl: prefs.baseUrl, jwt: a.token, snap: snap)
            // Mirror the snap into the App Group-shared cache so the
            // home-screen Status widget renders the same bars +
            // cooldowns we just pushed to the server. WidgetCenter
            // reload happens inside BarsCache.write.
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let drugDl    = snap.drugSeconds > 0    ? nowMs + Int64(snap.drugSeconds) * 1000    : 0
            let boosterDl = snap.boosterSeconds > 0 ? nowMs + Int64(snap.boosterSeconds) * 1000 : 0
            BarsCache.write(BarsCache.Snapshot(
                energyCurrent: snap.energy.current,
                energyMax:     snap.energy.maximum,
                nerveCurrent:  snap.nerve.current,
                nerveMax:      snap.nerve.maximum,
                drugDeadlineMs:    drugDl,
                boosterDeadlineMs: boosterDl,
                writtenAtMs: nowMs
            ))
            // Also push the bars into the chain Live Activity if one
            // is active — gives the lock-screen / Dynamic Island a
            // near-real-time bars surface during war without paying
            // for a separate APNs push round trip.
            if #available(iOS 16.1, *) {
                ChainLiveActivityController.shared.updateBars(
                    energyCurrent: snap.energy.current,
                    energyMax:     snap.energy.maximum,
                    nerveCurrent:  snap.nerve.current,
                    nerveMax:      snap.nerve.maximum,
                    drugDeadlineMs:    drugDl,
                    boosterDeadlineMs: boosterDl
                )
            }
            // And into the always-on Status Live Activity if user
            // has started one. Same data, different surface — Status
            // LA is independent of war state.
            if #available(iOS 16.2, *) {
                StatusLiveActivityController.shared.update(StatusActivityAttributes.ContentState(
                    energyCurrent: snap.energy.current,
                    energyMax:     snap.energy.maximum,
                    nerveCurrent:  snap.nerve.current,
                    nerveMax:      snap.nerve.maximum,
                    drugDeadlineMs:    drugDl,
                    boosterDeadlineMs: boosterDl,
                    writtenAtMs: nowMs
                ))
            }
        }
        if !attacks.isEmpty {
            await WarboardAPI.reportMyAttacks(baseUrl: prefs.baseUrl, jwt: a.token, attacks: attacks)
        }
    }
}

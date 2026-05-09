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
        guard let snap = await TornAPI.fetchDashboard(apiKey: prefs.apiKey),
              snap.error == nil
        else { return }
        await WarboardAPI.reportMyBars(baseUrl: prefs.baseUrl, jwt: a.token, snap: snap)
    }
}

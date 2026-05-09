import Foundation
import Combine

/// Status tab state holder. Polls /v2/user every 30 s while the tab
/// is on screen and pushes our bars to warboard so the rest of the
/// faction sees us as fresh in their Members tab.
@MainActor
final class DashboardViewModel: ObservableObject {
    enum State: Equatable {
        case noKey, loading, ready(TornAPI.DashboardSnapshot), error(String)
    }

    @Published private(set) var state: State = .loading
    /// True while a fetch is in flight — the toolbar button swaps to a
    /// spinner so the user gets immediate feedback that the tap landed.
    @Published private(set) var refreshing = false

    private var prefs: PrefsStore?
    private var task: Task<Void, Never>?

    func bind(prefs: PrefsStore) {
        self.prefs = prefs
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
    func refresh() async { await tick() }

    private func tick() async {
        refreshing = true
        defer { refreshing = false }
        guard let prefs = prefs else { return }
        if prefs.apiKey.isEmpty { state = .noKey; return }
        guard let snap = await TornAPI.fetchDashboard(apiKey: prefs.apiKey) else {
            state = .error("Couldn't reach Torn API"); return
        }
        if let err = snap.error { state = .error(err); return }
        state = .ready(snap)
    }
}

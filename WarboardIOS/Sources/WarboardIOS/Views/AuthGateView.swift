import SwiftUI

/// Top-level gate. Runs /api/auth at app start (and on key change).
/// Locks the entire app — including the Status tab + chain bar that
/// would otherwise work via direct Torn API calls — when the warboard
/// server's faction gate returns 403. Without this, a non-DF member
/// could install the app, enter their Torn key, and at least see
/// their own bars/cooldowns.
struct AuthGateView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var vm = AuthGateViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .checking:
                LoadingScreen()
            case .noKey:
                NoKeyScreen()
            case .denied(let msg):
                DeniedScreen(message: msg)
            case .badKey(let msg):
                BadKeyScreen(message: msg)
            case .network(let msg):
                NetworkErrorScreen(message: msg) { vm.recheck(prefs: prefs) }
            case .allowed:
                ContentView()
            }
        }
        .onAppear { vm.recheck(prefs: prefs) }
        .onChange(of: prefs.apiKey) { _, _ in vm.recheck(prefs: prefs) }
        .onChange(of: prefs.baseUrl) { _, _ in vm.recheck(prefs: prefs) }
    }
}

@MainActor
final class AuthGateViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case noKey
        case allowed
        case denied(String)
        case badKey(String)
        case network(String)
    }
    @Published private(set) var state: State = .idle
    private var task: Task<Void, Never>?

    func recheck(prefs: PrefsStore) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self = self else { return }
            if prefs.apiKey.isEmpty {
                self.state = .noKey
                return
            }
            self.state = .checking
            let outcome = await WarboardAPI.authenticateOutcome(
                baseUrl: prefs.baseUrl, apiKey: prefs.apiKey
            )
            switch outcome {
            case .success(let auth):
                let cached = CachedAuth(
                    token: auth.token,
                    factionId: auth.player.factionId,
                    factionName: auth.player.factionName,
                    playerId: auth.player.playerId
                )
                prefs.storeJwt(cached)
                self.state = .allowed
            case .denied(let msg):
                prefs.clearJwt()
                self.state = .denied(msg)
            case .badKey(let msg):
                prefs.clearJwt()
                self.state = .badKey(msg)
            case .network(let msg):
                self.state = .network(msg)
            }
        }
    }
}

// MARK: – Screens

private struct LoadingScreen: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Authorising…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoKeyScreen: View {
    var body: some View {
        // Keep the existing Settings flow available so users can paste
        // a key on first launch — wrap in a NavigationStack so the
        // Settings form has a title bar.
        NavigationStack { SettingsView() }
    }
}

private struct DeniedScreen: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("Access Denied")
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Warboard is restricted to faction members. If you think this is a mistake, contact RussianRob.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct BadKeyScreen: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Couldn't Authenticate")
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            NavigationLink("Open Settings") {
                SettingsView()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct NetworkErrorScreen: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Network Error")
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

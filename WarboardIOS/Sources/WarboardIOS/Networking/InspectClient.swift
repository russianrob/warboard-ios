import Foundation
import SwiftUI
import WarboardIOS

/// Owner-only remote-inspect poll loop. Runs ONLY while `PrefsStore.inspectEnabled`
/// is on (default off, owner-gated in Settings). Polls the warboard server for
/// commands the operator has queued, runs them against the live Browser WKWebView
/// (`UserscriptController.current`), and posts the results / screenshots back.
///
/// Inspect + JS-driven drive; the operator stays clear of Torn game-actions.
/// Auth: the app's own owner JWT (server enforces playerId == owner). Idle
/// auto-off uses a persisted wall-clock (`PrefsStore.inspectArmedAt`) so a
/// forgotten toggle can't stay armed across background/foreground/restarts.
/// Spec: docs/superpowers/specs/2026-06-30-remote-inspect-bridge-design.md
@MainActor
final class InspectClient: ObservableObject {
    static let pollSeconds: UInt64 = 2
    static let idleAutoOffSeconds: TimeInterval = 30 * 60

    private var prefs: PrefsStore?
    private var auth: AuthRepository?
    private var task: Task<Void, Never>?

    func bind(prefs: PrefsStore) {
        self.prefs = prefs
        self.auth = AuthRepository(prefs: prefs)
    }

    /// Idempotent. Only starts the loop when the owner toggle is on.
    func start() {
        guard task == nil else { return }
        guard let prefs = prefs, prefs.inspectEnabled else { return }
        if prefs.inspectArmedAt == 0 { prefs.inspectArmedAt = Date().timeIntervalSince1970 }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: InspectClient.pollSeconds * 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        guard let prefs = prefs, prefs.inspectEnabled else { stop(); return }
        guard let auth = auth, let a = await auth.ensureAuth(), a.isOwner else { return }
        // Persisted wall-clock idle auto-off — survives background/foreground/restart.
        let armed = prefs.inspectArmedAt
        if armed > 0, Date().timeIntervalSince1970 - armed > InspectClient.idleAutoOffSeconds {
            prefs.inspectEnabled = false
            prefs.inspectArmedAt = 0
            stop()
            return
        }
        let cmds = await fetchCmds(baseUrl: prefs.baseUrl, jwt: a.token)
        if cmds.isEmpty { return }
        prefs.inspectArmedAt = Date().timeIntervalSince1970
        for c in cmds {
            // Honor a mid-batch toggle-off / cancel before running each command.
            if Task.isCancelled || !prefs.inspectEnabled { break }
            if c.action == "screenshot" {
                if let png = await UserscriptController.current?.snapshotPNG() {
                    await postResult(baseUrl: prefs.baseUrl, jwt: a.token,
                                     body: ["id": c.id, "png": png.base64EncodedString()])
                } else {
                    await postResult(baseUrl: prefs.baseUrl, jwt: a.token,
                                     body: ["id": c.id, "error": "no web view (Browser tab not open)"])
                }
            } else if let js = c.js {
                let r = await UserscriptController.current?.runJS(js)
                var body: [String: String] = ["id": c.id]
                if let v = r?.value { body["result"] = v }
                if let e = r?.error ?? (r == nil ? "no web view (Browser tab not open)" : nil) { body["error"] = e }
                await postResult(baseUrl: prefs.baseUrl, jwt: a.token, body: body)
            } else {
                await postResult(baseUrl: prefs.baseUrl, jwt: a.token,
                                 body: ["id": c.id, "error": "unrecognized command"])
            }
        }
    }

    private struct Cmd: Decodable { let id: String; let js: String?; let action: String? }
    private struct CmdsResponse: Decodable { let cmds: [Cmd] }

    private func fetchCmds(baseUrl: String, jwt: String) async -> [Cmd] {
        guard let url = URL(string: baseUrl + "/api/inspect/cmd") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return (try? JSONDecoder().decode(CmdsResponse.self, from: data))?.cmds ?? []
        } catch { return [] }
    }

    private func postResult(baseUrl: String, jwt: String, body: [String: String]) async {
        guard let url = URL(string: baseUrl + "/api/inspect/result") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20
        _ = try? await URLSession.shared.data(for: req)
    }
}

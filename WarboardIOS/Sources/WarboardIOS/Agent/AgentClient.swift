import Foundation

/// SSE client for the owner-gated in-app agent chat. Opens a streaming
/// `POST <baseUrl>/api/agent/message` and yields decoded `AgentEvent`s as
/// `data:` frames arrive.
///
/// baseUrl + jwt mirror `InspectClient`'s usage exactly: `baseUrl` is the
/// raw `PrefsStore.baseUrl` string (URLs built by string concatenation, no
/// trailing-slash handling — same as InspectClient) and `jwt` is the app's
/// owner JWT (server enforces `playerId == owner`). Header names match
/// InspectClient too (`Authorization` / `Content-Type`).
struct AgentClient {
    let baseUrl: String
    let jwt: String

    func stream(text: String, sessionId: String?, installedScripts: [[String: Any]]) -> AsyncStream<AgentEvent> {
        var body: [String: Any] = ["text": text]
        if let sessionId = sessionId { body["sessionId"] = sessionId }
        if !installedScripts.isEmpty { body["installedScripts"] = installedScripts }
        return openStream(path: "/api/agent/message", body: body)
    }

    /// Run an owner-approved READ-ONLY inspect query on the live page via
    /// `POST <baseUrl>/api/agent/inspect`. The server runs the JS then resumes
    /// the agent, so this streams the continuation exactly like `stream`.
    func inspect(js: String, sessionId: String, installedScripts: [[String: Any]]) -> AsyncStream<AgentEvent> {
        var body: [String: Any] = ["js": js, "sessionId": sessionId]
        if !installedScripts.isEmpty { body["installedScripts"] = installedScripts }
        return openStream(path: "/api/agent/inspect", body: body)
    }

    /// Shared SSE POST: opens `<baseUrl><path>`, decodes `data:` frames into
    /// `AgentEvent`s, and finishes on `.end`, cancellation, or error.
    private func openStream(path: String, body: [String: Any]) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            let task = Task {
                guard let url = URL(string: baseUrl + path) else {
                    continuation.yield(.error("bad server URL"))
                    continuation.finish()
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                // Long-lived stream; a per-turn wall-clock cap is enforced
                // server-side, so this is just an upper safety bound.
                req.timeoutInterval = 600

                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.yield(.error("HTTP \(http.statusCode)"))
                        continuation.finish()
                        return
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        // SSE comment/keepalive lines start with ':' and blank
                        // separator lines never match this prefix — both skipped.
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if let ev = parseAgentSSE(payload) {
                            continuation.yield(ev)
                            if case .end = ev { break }   // stream finished
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        continuation.yield(.error(error.localizedDescription))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Apply + deploy a proposed userscript change via the owner-gated
    /// `POST <baseUrl>/api/agent/deploy`. Returns `(ok, message)` — a short
    /// human-readable confirmation (with the served version when the server
    /// reports one) on success, or an error message to surface on failure.
    func deploy(filename: String, content: String) async -> (ok: Bool, message: String) {
        guard let url = URL(string: baseUrl + "/api/agent/deploy") else {
            return (ok: false, message: "bad server URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["filename": filename, "content": content]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if code == 200, json?["ok"] as? Bool == true {
                var msg = "Deployed \(filename)"
                if let version = json?["version"] as? String, !version.isEmpty {
                    msg += " v\(version)"
                }
                return (ok: true, message: msg)
            }
            return (ok: false, message: json?["error"] as? String ?? "HTTP \(code)")
        } catch {
            return (ok: false, message: error.localizedDescription)
        }
    }
}

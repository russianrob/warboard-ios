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

    func stream(text: String, sessionId: String?) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            let task = Task {
                guard let url = URL(string: baseUrl + "/api/agent/message") else {
                    continuation.yield(.error("bad server URL"))
                    continuation.finish()
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                var body: [String: Any] = ["text": text]
                if let sessionId = sessionId { body["sessionId"] = sessionId }
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
}

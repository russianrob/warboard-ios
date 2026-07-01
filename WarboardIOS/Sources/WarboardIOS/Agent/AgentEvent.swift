import Foundation

/// One decoded Server-Sent-Event frame from `POST /api/agent/message`.
/// The server tags every frame with a `t` discriminator (see the route's
/// normalized event shapes); this enum mirrors that contract 1:1. Unknown
/// / future `t` values decode to `.unknown` (ignored by the view model)
/// rather than dropping the whole frame.
enum AgentEvent: Equatable {
    /// Whether a live page snapshot was captured for this turn.
    case snapshot(Bool)
    /// The Claude session id — keep the latest and echo it back as
    /// `sessionId` on the next turn for conversation continuity.
    case session(String)
    /// Quota status readout.
    case rate(status: String?, resetsAt: Double?)
    /// A chunk of the assistant's reply — append to the current message.
    case delta(String)
    /// The model is thinking (subtle indicator only).
    case thinking
    /// Turn complete.
    case done(ok: Bool, result: String)
    /// Stream finished — stop reading.
    case end
    /// Surface to the user.
    case error(String)
    /// Diagnostic line — logged / ignored, never shown.
    case stderr(String)
    /// A `t` we don't model — safely ignored.
    case unknown
}

/// Decode a single SSE `data:` JSON payload (the text AFTER `data: `) into
/// an `AgentEvent`. Returns `nil` for non-JSON or a JSON object missing the
/// `t` discriminator (e.g. an SSE comment/keepalive should never reach here,
/// but a malformed frame yields `nil` and is skipped by the caller).
func parseAgentSSE(_ dataPayload: String) -> AgentEvent? {
    guard let data = dataPayload.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data),
          let o = obj as? [String: Any],
          let t = o["t"] as? String else { return nil }
    switch t {
    case "snapshot": return .snapshot(o["ok"] as? Bool ?? false)
    case "session":  return .session(o["id"] as? String ?? "")
    case "rate":     return .rate(status: o["status"] as? String,
                                  resetsAt: (o["resetsAt"] as? NSNumber)?.doubleValue)
    case "delta":    return .delta(o["text"] as? String ?? "")
    case "thinking": return .thinking
    case "done":     return .done(ok: o["ok"] as? Bool ?? false,
                                  result: o["result"] as? String ?? "")
    case "end":      return .end
    case "error":    return .error(o["message"] as? String ?? "error")
    case "stderr":   return .stderr(o["text"] as? String ?? "")
    default:         return .unknown
    }
}

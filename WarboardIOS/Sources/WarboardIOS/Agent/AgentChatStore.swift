import Foundation

/// The persisted form of an agent chat: the Claude session id (so the next
/// launch can `--resume` and the agent still remembers the conversation) plus
/// the visible transcript.
struct PersistedChat: Codable {
    var sessionId: String?
    var messages: [ChatMessage]
}

/// Durable storage for the in-app agent chat so a conversation survives an app
/// relaunch — a force-quit, or iOS reclaiming the backgrounded app. Without it
/// the transcript + session id live only in the view model's memory and are
/// wiped on every cold start, so the agent greets each launch as a first
/// message with no memory.
///
/// The agent's own memory lives server-side, keyed by `sessionId`; this store
/// only needs to hold that id plus enough recent transcript to show the user
/// where they left off. So the transcript is capped (oldest messages dropped)
/// to keep the UserDefaults blob small — the session id is always preserved.
/// Backed by the same App-Group `UserDefaults` suite as `QuickItemsStore` /
/// `ExtStorage`.
enum AgentChatStore {
    private static let key = "agentChat.v1"
    private static let maxMessages = 100
    private static let maxBytes = 256 * 1024

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard
    }

    static func load() -> PersistedChat? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedChat.self, from: data)
    }

    static func save(_ chat: PersistedChat) {
        var trimmed = chat
        if trimmed.messages.count > maxMessages {
            trimmed.messages = Array(trimmed.messages.suffix(maxMessages))
        }
        let encoder = JSONEncoder()
        var data = (try? encoder.encode(trimmed)) ?? Data()
        // Drop oldest messages until the blob fits; the session id always stays.
        while data.count > maxBytes && !trimmed.messages.isEmpty {
            trimmed.messages.removeFirst()
            data = (try? encoder.encode(trimmed)) ?? Data()
        }
        defaults.set(data, forKey: key)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}

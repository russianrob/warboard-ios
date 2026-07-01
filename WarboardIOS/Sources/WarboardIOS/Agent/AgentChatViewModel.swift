import Foundation
import Combine

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let role: ChatRole
    var text: String
}

/// A full userscript file the agent proposed this turn, awaiting the user's
/// "Apply & deploy" confirmation.
struct ProposalDraft: Equatable {
    let filename: String
    let content: String
}

/// Drives the in-app agent chat: owns the transcript, streams one turn at a
/// time over `AgentClient`, appends deltas to the in-flight assistant
/// message, and carries the Claude session id forward for continuity.
@MainActor
final class AgentChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var busy: Bool = false
    /// Whether the last turn captured a live page snapshot (from `snapshot`).
    @Published var snapshotOk: Bool = false
    /// Latest quota status (from `rate`); nil until the server reports one.
    @Published var rateStatus: String? = nil
    /// A proposed userscript change awaiting "Apply & deploy" (from `proposal`).
    @Published var pendingProposal: ProposalDraft? = nil
    /// Deploy outcome/progress message; nil = idle.
    @Published var deployStatus: String? = nil
    /// Whether a deploy is in flight.
    @Published var deploying: Bool = false

    /// Latest Claude session id — echoed back on the next turn for continuity.
    private var sessionId: String? = nil
    /// Set by the presenter (ContentView) each time the chat opens, carrying the
    /// current owner JWT. The view model itself is long-lived (owned by
    /// ContentView) so the transcript survives closing/reopening the sheet.
    var client: AgentClient? = nil

    init() {
        if let saved = AgentChatStore.load() {
            messages = saved.messages
            sessionId = saved.sessionId
        }
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy, let client = client else { return }
        input = ""
        busy = true
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: ""))
        let idx = messages.count - 1
        let outgoing = sessionId

        Task { [weak self] in
            guard let self else { return }
            for await ev in client.stream(text: text, sessionId: outgoing) {
                switch ev {
                case .delta(let chunk):
                    if idx < self.messages.count { self.messages[idx].text += chunk }
                case .session(let id):
                    if !id.isEmpty { self.sessionId = id }
                case .snapshot(let ok):
                    self.snapshotOk = ok
                case .rate(let status, _):
                    self.rateStatus = status
                case .proposal(let f, let c):
                    self.pendingProposal = ProposalDraft(filename: f, content: c)
                    self.deployStatus = nil
                case .error(let message):
                    if idx < self.messages.count {
                        let sep = self.messages[idx].text.isEmpty ? "" : "\n"
                        self.messages[idx].text += "\(sep)⚠️ \(message)"
                    }
                case .thinking, .done, .end, .stderr, .unknown:
                    break
                }
            }
            self.busy = false
            self.persist()
        }
    }

    /// Apply the pending proposal by POSTing it to the deploy endpoint, then
    /// surface the outcome via `deployStatus`. Clears the proposal on success.
    func deployProposal() {
        guard let draft = pendingProposal, !deploying, let client = client else { return }
        deploying = true
        deployStatus = "Deploying \(draft.filename)…"

        Task { [weak self] in
            guard let self else { return }
            let result = await client.deploy(filename: draft.filename, content: draft.content)
            if result.ok {
                self.deployStatus = result.message
                self.pendingProposal = nil
            } else {
                self.deployStatus = "Deploy failed: \(result.message)"
            }
            self.deploying = false
        }
    }

    /// Persist the current transcript + session id so the conversation (and the
    /// agent's server-side memory, reached via `--resume`) survives an app
    /// relaunch. Called at the end of each turn.
    private func persist() {
        AgentChatStore.save(PersistedChat(sessionId: sessionId, messages: messages))
    }

    /// Start a fresh conversation: clear the transcript and drop the session id
    /// so the next turn opens a new server-side session.
    func newChat() {
        messages = []
        sessionId = nil
        pendingProposal = nil
        deployStatus = nil
        input = ""
        AgentChatStore.clear()
    }
}

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
    /// A read-only JS query the agent wants to run, awaiting owner approval.
    /// Every query is approved individually — there is no auto-run, so the owner
    /// always sees the exact JS before it touches the page.
    @Published var pendingInspect: String? = nil

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
        // A fresh user turn supersedes any pending card the owner bypassed by
        // typing, so it can't resurface stale after this turn.
        pendingInspect = nil
        pendingProposal = nil
        deployStatus = nil
        messages.append(ChatMessage(role: .user, text: text))
        let outgoing = sessionId
        Task { [weak self] in
            guard let self else { return }
            await self.drive(client.stream(text: text, sessionId: outgoing))
            self.busy = false
            self.persist()
        }
    }

    /// Owner approved the pending inspect query — run it and stream the agent's
    /// continuation.
    func approveInspect() {
        guard let js = pendingInspect, let client = client, let sid = sessionId, !busy else { return }
        pendingInspect = nil
        busy = true
        Task { [weak self] in
            guard let self else { return }
            await self.drive(client.inspect(js: js, sessionId: sid))
            self.busy = false
            self.persist()
        }
    }

    /// Owner declined the pending inspect query — tell the agent so it answers
    /// without the data.
    func declineInspect() {
        guard pendingInspect != nil, let client = client, let sid = sessionId, !busy else { return }
        pendingInspect = nil
        busy = true
        Task { [weak self] in
            guard let self else { return }
            await self.drive(client.stream(text: "(Owner declined to run that inspection query. Answer without it.)", sessionId: sid))
            self.busy = false
            self.persist()
        }
    }

    /// Append a fresh assistant message, stream one turn into it, then — if the
    /// owner enabled "trust this session" — auto-run any inspect query the turn
    /// requested and keep going until the agent stops asking.
    /// Append a fresh assistant message and stream one turn into it. Any inspect
    /// query the turn requests is surfaced as an approval card (via `consume`);
    /// there is no auto-run, so the owner approves each one explicitly.
    private func drive(_ stream: AsyncStream<AgentEvent>) async {
        messages.append(ChatMessage(role: .assistant, text: ""))
        await consume(stream, into: messages.count - 1)
    }

    /// Fold one SSE turn's events into the transcript at `idx`.
    private func consume(_ stream: AsyncStream<AgentEvent>, into idx: Int) async {
        for await ev in stream {
            switch ev {
            case .delta(let chunk):
                if idx < messages.count { messages[idx].text += chunk }
            case .session(let id):
                if !id.isEmpty { sessionId = id }
            case .snapshot(let ok):
                snapshotOk = ok
            case .rate(let status, _):
                rateStatus = status
            case .proposal(let f, let c):
                pendingProposal = ProposalDraft(filename: f, content: c)
                deployStatus = nil
            case .inspectRequest(let js):
                pendingInspect = js
            case .inspectResult:
                break
            case .error(let message):
                if idx < messages.count {
                    let sep = messages[idx].text.isEmpty ? "" : "\n"
                    messages[idx].text += "\(sep)⚠️ \(message)"
                }
            case .thinking, .done, .end, .stderr, .unknown:
                break
            }
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
        pendingInspect = nil
        input = ""
        AgentChatStore.clear()
    }
}

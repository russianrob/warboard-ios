import SwiftUI
import Combine

/// War-chat sub-tab. Faction-scoped, ephemeral — server wipes the
/// buffer when the war ends. Anyone in the faction can post; admins
/// (broadcast roles + owner) can swipe-delete messages.
struct ChatPanel: View {
    let warId: String
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var vm = ChatViewModel()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    @State private var pendingDeleteId: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if vm.messages.isEmpty {
                            Text("No messages yet — say hi.")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(vm.messages) { m in
                                ChatRow(message: m, isAdmin: vm.isAdmin) {
                                    // .swipeActions only works inside SwiftUI
                                    // List; this view uses ScrollView+LazyVStack
                                    // for chat layout, so use long-press →
                                    // confirm-delete dialog instead (matches
                                    // Android UX exactly).
                                    pendingDeleteId = m.id
                                }
                                .id(m.id)
                            }
                        }
                    }
                    .padding(10)
                }
                .onChange(of: vm.messages.last?.id) { _, _ in
                    if let last = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack {
                TextField("Message…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .focused($inputFocused)
                    .onSubmit { send() }
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.sending)
                .buttonStyle(.borderedProminent)
            }
            .padding(8)
        }
        .task { await vm.start(prefs: prefs, warId: warId) }
        .onDisappear { vm.stop() }
        .alert("Chat error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        // Delete confirmation — admin-only path (the long-press handler
        // in ChatRow only fires when isAdmin, but double-checking before
        // the destructive action couldn't hurt).
        .alert("Delete message?", isPresented: Binding(
            get: { pendingDeleteId != nil },
            set: { if !$0 { pendingDeleteId = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeleteId = nil }
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteId {
                    pendingDeleteId = nil
                    Task { await vm.delete(messageId: id, prefs: prefs, warId: warId) }
                }
            }
        } message: {
            Text("This is permanent — the message will be removed for all viewers.")
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await vm.send(text: text, prefs: prefs, warId: warId) }
    }
}

private struct ChatRow: View {
    let message: WarboardAPI.ChatMessage
    let isAdmin: Bool
    /// Fired on long-press by an admin — parent shows the confirm
    /// dialog and dispatches the delete on accept.
    let onLongPress: () -> Void

    private var roleColor: Color {
        switch message.factionPosition.lowercased() {
        case "leader", "co-leader":            return .yellow
        case "war leader":                     return .orange
        case "banker":                         return .green
        default:                               return .secondary
        }
    }
    private var time: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(message.ts) / 1000.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(message.playerName)
                    .font(.caption.bold())
                    .foregroundStyle(roleColor)
                Text(time)
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
            }
            Text(message.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            // Only admins can delete (server enforces too — this just
            // skips firing the confirm dialog for non-admins).
            if isAdmin { onLongPress() }
        }
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [WarboardAPI.ChatMessage] = []
    @Published var sending: Bool = false
    @Published var isAdmin: Bool = false
    @Published var errorMessage: String?

    private var bag = Set<AnyCancellable>()
    private var currentWarId: String?

    func start(prefs: PrefsStore, warId: String) async {
        currentWarId = warId
        // Seed admin gate from cached auth — no extra network call.
        if let auth = prefs.cachedJwt() {
            if auth.isOwner { isAdmin = true }
            else {
                let roles = await WarboardAPI.fetchBroadcastRoles(baseUrl: prefs.baseUrl, jwt: auth.token)
                let p = auth.factionPosition.lowercased()
                isAdmin = !p.isEmpty && roles.map { $0.lowercased() }.contains(p)
            }
        }
        // Initial history fetch.
        if let auth = prefs.cachedJwt() {
            messages = await WarboardAPI.fetchChatHistory(
                baseUrl: prefs.baseUrl, jwt: auth.token, warId: warId
            )
        }
        // Realtime — append on chat_message, remove on chat_deleted.
        bag.removeAll()
        RealtimeClient.shared.events
            .sink { [weak self] event in
                guard let self = self, self.currentWarId == warId else { return }
                switch event {
                case .chatMessage(let payload):
                    if let m = WarboardAPI.parseChatMessage(payload),
                       !self.messages.contains(where: { $0.id == m.id }) {
                        self.messages.append(m)
                    }
                case .chatDeleted(let payload):
                    if let id = payload["msgId"] as? String {
                        self.messages.removeAll { $0.id == id }
                    }
                default: break
                }
            }
            .store(in: &bag)
    }

    func stop() { bag.removeAll(); currentWarId = nil }

    func send(text: String, prefs: PrefsStore, warId: String) async {
        guard let auth = prefs.cachedJwt() else { return }
        sending = true
        let r = await WarboardAPI.sendChatMessage(
            baseUrl: prefs.baseUrl, jwt: auth.token, warId: warId, text: text
        )
        sending = false
        if case .error(let m) = r { errorMessage = m }
        // Optimistic — message will arrive via socket and append; if
        // the socket is offline, refetch once on success.
        if case .ok = r, !RealtimeClient.shared.connected {
            messages = await WarboardAPI.fetchChatHistory(
                baseUrl: prefs.baseUrl, jwt: auth.token, warId: warId
            )
        }
    }

    func delete(messageId: String, prefs: PrefsStore, warId: String) async {
        guard let auth = prefs.cachedJwt() else { return }
        let r = await WarboardAPI.deleteChatMessage(
            baseUrl: prefs.baseUrl, jwt: auth.token, warId: warId, msgId: messageId
        )
        if case .error(let m) = r { errorMessage = m }
        // Optimistic removal — server event will reconcile.
        messages.removeAll { $0.id == messageId }
    }
}

import SwiftUI
import UIKit

/// Owner-only in-app chat with the headless Claude agent running on the
/// warboard server. Reached from the owner-gated Settings section.
///
/// Lifecycle: on appear it arms the remote-inspect loop (`prefs.inspectEnabled
/// = true` — the app root's `onChange` starts `InspectClient`, so the server's
/// per-turn page snapshots work) and disables the idle timer so the screen
/// stays awake mid-turn while foregrounded. The keep-awake is released on
/// disappear. The inspect toggle is left as the user set it (a running turn may
/// still need it); it also auto-disarms after 30 min idle via `InspectClient`.
struct AgentChatView: View {
    @EnvironmentObject private var prefs: PrefsStore
    // Owned by ContentView (long-lived) and passed in, so the transcript
    // survives closing + reopening the sheet.
    @ObservedObject var vm: AgentChatViewModel
    @State private var confirmNewChat = false
    @State private var showProposalCode = false

    var body: some View {
        VStack(spacing: 0) {
            transcript
            statusBar
            if let proposal = vm.pendingProposal {
                proposalCard(proposal)
            }
            if let js = vm.pendingInspect, !vm.busy {
                inspectCard(js)
            }
            if let status = vm.deployStatus {
                deployStatusCaption(status)
            }
            Divider()
            inputBar
        }
        .navigationTitle("Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if vm.messages.isEmpty { vm.newChat() } else { confirmNewChat = true }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(vm.busy)
                .accessibilityLabel("New chat")
            }
        }
        .confirmationDialog("Start a new chat? This clears the current conversation.",
                            isPresented: $confirmNewChat, titleVisibility: .visible) {
            Button("New chat", role: .destructive) { vm.newChat() }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showProposalCode) {
            if let draft = vm.pendingProposal {
                NavigationStack {
                    ScrollView {
                        SelectableText(text: draft.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle(draft.filename)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onAppear {
            prefs.inspectEnabled = true                       // arm the inspect loop (server snapshots)
            UIApplication.shared.isIdleTimerDisabled = true   // keep-awake while chatting
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.role == .user ? "You" : "Agent")
                                .font(.caption2).bold()
                                .foregroundStyle(m.role == .user ? Color.accentColor : Color.secondary)
                            SelectableText(text: m.role == .assistant ? displayText(m.text) : m.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(m.id)
                    }
                }
                .padding()
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: vm.messages.last?.text) { _, _ in
                if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    /// The text to SHOW for a message: hides the agent's machine protocol blocks
    /// so the raw proposed file / inspect JS goes to its card instead of
    /// cluttering (and being copied out of) the chat. `===FILE:` / `===INSPECT===`
    /// are terminal — cut from the marker on; `===SOURCE:` is a mid-message
    /// request the server auto-fulfills — strip just that marker.
    private func displayText(_ raw: String) -> String {
        guard raw.contains("===") else {                       // fast path: no markers
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "…" : t
        }
        var text = raw
        // ===FILE: / ===INSPECT=== are terminal blocks at LINE START; cut from the
        // first one on. `range(of:)` stops in the prose, so a big streamed file is
        // never scanned (avoids O(n^2) over a proposal's deltas).
        if let r = text.range(of: "(?m)^(===FILE:|===INSPECT===)", options: .regularExpression) {
            text = String(text[..<r.lowerBound])
        }
        // ===SOURCE: is a mid-message marker the server auto-fulfills; strip the
        // line-start marker only (keep the agent's answer after it). Runs on the
        // already-truncated prefix, not the whole message.
        text = text.replacingOccurrences(
            of: "(?m)^===SOURCE:[^\\n=]*===",
            with: "",
            options: .regularExpression)
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "…" : result
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if vm.busy {
                ProgressView().scaleEffect(0.7)
                Text("thinking…").font(.caption2).foregroundStyle(Color.secondary)
            }
            Label(vm.snapshotOk ? "snapshot" : "no snapshot",
                  systemImage: vm.snapshotOk ? "camera.viewfinder" : "camera")
                .font(.caption2)
                .foregroundStyle(vm.snapshotOk ? Color.green : Color.secondary)
            Spacer()
            if let r = vm.rateStatus {
                Text("quota: \(r)")
                    .font(.caption2)
                    .foregroundStyle(r == "allowed" ? Color.secondary : Color.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    /// Owner confirmation card for a proposed userscript change. Shown only
    /// while `vm.pendingProposal` is set. The raw file is NOT in the transcript
    /// (kept out of chat); "View file" opens it in a sheet. Styling mirrors
    /// `statusBar` (semantic colors, caption).
    private func proposalCard(_ draft: ProposalDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Proposed change · \(draft.filename)", systemImage: "doc.badge.gearshape")
                .font(.caption).bold()
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Text("The full file is kept out of the chat — apply it, or view the file first.")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            HStack(spacing: 8) {
                Button {
                    vm.deployProposal()
                } label: {
                    HStack(spacing: 6) {
                        if vm.deploying { ProgressView().scaleEffect(0.7) }
                        Text(vm.deploying ? "Deploying…" : "Apply & deploy")
                    }
                    .font(.caption).bold()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(vm.deploying)
                Button { showProposalCode = true } label: {
                    Text("View file").font(.caption)
                }
                .controlSize(.small)
                .disabled(vm.deploying)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    /// Deploy outcome caption: green for success, red for a failure, secondary
    /// for an in-flight "Deploying…" message.
    private func deployStatusCaption(_ status: String) -> some View {
        let color: Color = status.localizedCaseInsensitiveContains("failed") ? Color.red
            : status.hasPrefix("Deployed ") ? Color.green
            : Color.secondary
        return Text(status)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 4)
    }

    /// Owner approval card for a read-only inspect query the agent proposed:
    /// the exact JS + Approve/Decline + a "trust this session" toggle. Gated on
    /// `!vm.busy` so it only shows when a turn isn't actively streaming.
    private func inspectCard(_ js: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Agent wants to inspect the page", systemImage: "magnifyingglass")
                .font(.caption).bold()
                .foregroundStyle(Color.primary)
            Text(js)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .lineLimit(8)
            HStack(spacing: 8) {
                Button { vm.approveInspect() } label: {
                    Text("Approve & run").font(.caption).bold()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(role: .cancel) { vm.declineInspect() } label: {
                    Text("Decline").font(.caption)
                }
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask the agent…", text: $vm.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .disabled(vm.busy)
            Button {
                vm.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(vm.busy || vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

/// A non-editable, self-sizing `UITextView` so message text is reliably
/// selectable — long-press to start a selection, drag the handles, then Copy
/// (or Select All). More robust than SwiftUI `.textSelection` inside a
/// `ScrollView`, where the scroll gesture swallows the long-press needed to
/// begin selecting. `isScrollEnabled = false` lets it grow to fit so the outer
/// ScrollView still handles scrolling.
private struct SelectableText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.adjustsFontForContentSizeCategory = true
        tv.font = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
        tv.textColor = .label
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.setContentHuggingPriority(.required, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
    }
}

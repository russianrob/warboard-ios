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

    var body: some View {
        VStack(spacing: 0) {
            transcript
            statusBar
            if let proposal = vm.pendingProposal {
                proposalCard(proposal)
            }
            if let status = vm.deployStatus {
                deployStatusCaption(status)
            }
            Divider()
            inputBar
        }
        .navigationTitle("Agent")
        .navigationBarTitleDisplayMode(.inline)
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
                            Text(m.text.isEmpty ? "…" : m.text)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
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
    /// while `vm.pendingProposal` is set; the actual file is in the transcript
    /// message above. Styling mirrors `statusBar` (semantic colors, caption).
    private func proposalCard(_ draft: ProposalDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Proposed change · \(draft.filename)", systemImage: "doc.badge.gearshape")
                .font(.caption).bold()
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Text("Review the full file in the message above before deploying.")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
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

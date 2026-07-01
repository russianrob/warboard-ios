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
    @StateObject private var vm: AgentChatViewModel

    init(client: AgentClient) {
        _vm = StateObject(wrappedValue: AgentChatViewModel(client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            statusBar
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

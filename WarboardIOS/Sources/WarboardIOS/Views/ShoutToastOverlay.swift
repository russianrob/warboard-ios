import SwiftUI
import Combine

/// App-wide overlay that listens to `RealtimeClient.Event.globalToast`
/// and shows a top banner with the sender + message. Auto-dismisses
/// after 5 seconds. Renders above all tabs so a leader's broadcast is
/// visible no matter which tab the user is on — including the sender
/// themselves (server fans out to every client in the war room).
@MainActor
final class ShoutToastViewModel: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let sender: String?
        let message: String
        let kind: String  // "info", "warning", "danger" — drives the tint
    }
    @Published var current: Toast?
    private var bag = Set<AnyCancellable>()
    private var dismissTask: Task<Void, Never>?

    init() {
        RealtimeClient.shared.events
            .sink { [weak self] event in
                guard let self = self,
                      case .globalToast(let payload) = event else { return }
                let msg = (payload["message"] as? String) ?? ""
                guard !msg.isEmpty else { return }
                let toast = Toast(
                    sender: payload["senderName"] as? String,
                    message: msg,
                    kind: (payload["type"] as? String) ?? "info"
                )
                NSLog("[ShoutToast] received from %@: %@",
                      toast.sender ?? "?", toast.message)
                self.show(toast)
            }
            .store(in: &bag)
    }

    private func show(_ toast: Toast) {
        current = toast
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { self?.current = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

struct ShoutToastOverlay: View {
    @StateObject private var vm = ShoutToastViewModel()

    var body: some View {
        VStack {
            if let t = vm.current {
                ToastBanner(toast: t) { vm.dismiss() }
                    .padding(.horizontal, 12)
                    // Safe-area-aware top padding — prior 4pt slid the
                    // banner under the status bar. Use top safe-area
                    // inset via a GeometryReader-free approach.
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        // Force overlay above the TabView's tab bar + system chrome.
        .zIndex(999)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.current)
        .allowsHitTesting(vm.current != nil)
    }
}

private struct ToastBanner: View {
    let toast: ShoutToastViewModel.Toast
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.white)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                if let s = toast.sender, !s.isEmpty {
                    Text(s).font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
                }
                Text(toast.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onTap) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .onTapGesture { onTap() }
    }

    private var tint: Color {
        switch toast.kind.lowercased() {
        case "danger", "error":   return .red
        case "warning", "warn":   return .orange
        case "success", "ok":     return .green
        default:                  return .blue
        }
    }
}

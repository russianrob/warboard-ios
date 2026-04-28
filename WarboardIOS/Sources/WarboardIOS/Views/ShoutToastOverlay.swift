import SwiftUI
import Combine

/// Listens to RealtimeClient.globalToast events and presents each as
/// a system alert popup — matches the "Shout sent" confirmation style
/// rather than a sliding banner. User-requested: popup boxes are more
/// intentional / harder to miss than a 5-second top banner.
@MainActor
final class ShoutToastViewModel: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let sender: String?
        let message: String
        let kind: String
    }
    @Published var current: Toast?
    private var bag = Set<AnyCancellable>()

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
                self.current = toast
            }
            .store(in: &bag)
    }

    func dismiss() { current = nil }
}

/// Lives in ContentView's body — presents an alert anchored to the
/// root TabView so it pops even when the user is on a tab other than
/// War Room.
struct ShoutToastOverlay: View {
    @StateObject private var vm = ShoutToastViewModel()

    var body: some View {
        // Invisible content; the alert modifier is what actually
        // surfaces the popup. We spread it across the screen so it
        // attaches to the right view-tree position.
        Color.clear
            .allowsHitTesting(false)
            .alert(
                title,
                isPresented: Binding(
                    get: { vm.current != nil },
                    set: { if !$0 { vm.dismiss() } }
                ),
                presenting: vm.current
            ) { _ in
                Button("OK") { vm.dismiss() }
            } message: { toast in
                Text(toast.message)
            }
    }

    private var title: String {
        guard let t = vm.current else { return "" }
        if let s = t.sender, !s.isEmpty { return "📣 \(s)" }
        return "📣 Faction broadcast"
    }
}

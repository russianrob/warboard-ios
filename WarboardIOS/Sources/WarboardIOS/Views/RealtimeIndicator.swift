import SwiftUI

/// Tiny dot + label that reflects RealtimeClient.shared.connected.
/// Green when Socket.IO is open (broadcasts/status updates arrive
/// instantly), grey when offline (poll-only fallback). Lives in the
/// War Room toolbar so users can tell at a glance whether realtime
/// is plumbed through.
struct RealtimeIndicator: View {
    @State private var connected: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(connected ? "Live" : "Offline")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .task {
            // Mirror RealtimeClient.shared.connected into local @State so
            // SwiftUI re-renders on each transition. RealtimeClient is
            // @MainActor and exposes `connected` as @Published; the for-await
            // loop stays alive until the view detaches.
            connected = RealtimeClient.shared.connected
            for await c in RealtimeClient.shared.$connected.values {
                connected = c
            }
        }
    }
}

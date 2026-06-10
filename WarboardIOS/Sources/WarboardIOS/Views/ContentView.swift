import SwiftUI
import WarboardIOS

/// App shell: a full-screen in-app Torn browser hosting the userscript
/// engine, with a slim top bar offering Scripts (manage installed
/// userscripts). Status, War, Faction, OC, Chat and Settings were retired
/// from navigation; their views stay in the codebase but are no longer
/// reachable from here.
///
/// The watch / widget data pipeline is app-level (BarReporter in
/// WarboardIOSApp pushes to WatchSyncController every cycle regardless of
/// which view is mounted), so dropping the Status screen does not affect
/// the watch.
struct ContentView: View {
    @State private var showScripts = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            BrowserView()
        }
        // App-wide shout banner — listens to RealtimeClient.globalToast
        // so the broadcast surfaces over the browser (and the sender sees
        // their own).
        .overlay(alignment: .top) { ShoutToastOverlay() }
        .sheet(isPresented: $showScripts) {
            NavigationStack { ScriptsView() }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button {
                showScripts = true
            } label: {
                Label("Scripts", systemImage: "doc.text.fill")
                    .font(.subheadline.weight(.medium))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

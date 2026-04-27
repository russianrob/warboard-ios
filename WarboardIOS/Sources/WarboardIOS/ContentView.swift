import SwiftUI

struct ContentView: View {
    @AppStorage("landing_url") private var landingUrl: String = "https://www.torn.com/factions.php?step=your"
    @AppStorage("last_url") private var lastUrl: String = ""

    /// URL the WebView should currently be displaying. Bound into
    /// `TornWebView` so we can drive it from notification taps + the
    /// Home toolbar button.
    @State private var currentUrl: URL = URL(string: "https://www.torn.com/factions.php?step=your")!
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            TornWebView(url: $currentUrl) { newUrl in
                lastUrl = newUrl.absoluteString
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Warboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let u = URL(string: landingUrl) { currentUrl = u }
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel("Home")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                // Restore last visited URL on cold start so users land
                // back where they left off (matches the Android app's
                // behavior).
                if let saved = URL(string: lastUrl), !lastUrl.isEmpty {
                    currentUrl = saved
                } else if let u = URL(string: landingUrl) {
                    currentUrl = u
                }
            }
        }
    }
}

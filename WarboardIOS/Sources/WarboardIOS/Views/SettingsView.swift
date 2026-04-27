import SwiftUI

/// iOS settings — Torn API key (auth on warboard endpoints) + warboard
/// base URL + notification toggles. No Sparkle (TestFlight handles
/// updates) and no menu-bar / dock-tile knobs (not applicable on iOS).
struct SettingsView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @State private var apiKey: String = ""
    @State private var baseUrl: String = ""
    @State private var savedToast: String?

    var body: some View {
        Form {
            Section("Torn API key") {
                SecureField("32-character key", text: $apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("Used for personal data + warboard authentication.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Warboard server") {
                TextField("Base URL", text: $baseUrl)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("Default: https://tornwar.com")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button {
                    prefs.apiKey = apiKey
                    prefs.baseUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    prefs.clearJwt()  // forces re-auth on next request
                    savedToast = "Saved — re-authenticating on next poll"
                } label: {
                    HStack {
                        Spacer(); Text("Save").bold(); Spacer()
                    }
                }
                if let toast = savedToast {
                    Text(toast).foregroundStyle(.green).font(.caption)
                }
            }

            Section("Notifications") {
                Toggle("Chain-breaking alerts (60 s + 30 s thresholds)", isOn: $prefs.notifyChain)
                Toggle("New vault request alerts", isOn: $prefs.notifyVault)
                Text("First-time triggers an iOS permission prompt. Silent if denied — toggle in Settings → Notifications → Warboard.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Section("About") {
                let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
                let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
                LabeledContent("Version") { Text("\(v) (\(b))").foregroundStyle(.secondary) }
                Text("Updates ship via TestFlight — open the TestFlight app to grab new builds.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKey = prefs.apiKey
            baseUrl = prefs.baseUrl
        }
    }
}

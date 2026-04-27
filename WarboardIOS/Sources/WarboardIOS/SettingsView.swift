import SwiftUI

/// Minimal settings sheet — Torn API key (used as auth on warboard
/// endpoints, including the APNs-subscribe call once that's wired)
/// and the warboard base URL (default: tornwar.com).
struct SettingsView: View {
    @AppStorage("torn_api_key") private var tornApiKey: String = ""
    @AppStorage("warboard_base_url") private var warboardBaseURL: String = "https://tornwar.com"
    @AppStorage("landing_url") private var landingUrl: String = "https://www.torn.com/factions.php?step=your"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Warboard")) {
                    SecureField("Torn API key", text: $tornApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Warboard base URL", text: $warboardBaseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section(header: Text("Landing")) {
                    TextField("Default URL", text: $landingUrl)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("Where the app opens on launch (and after you tap a notification with no deep link).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Bundled scripts")) {
                    Text("FactionOps + OC Spawn Assistance — auto-injected on every Torn page load.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

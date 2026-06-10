import SwiftUI

/// Lets the user point the app at a Torn API key and choose which
/// bar/cooldown "ready" alerts to receive. The alerts themselves are
/// scheduled by BarNotificationScheduler off BarReporter's poll, so this
/// screen only edits the inputs (key + per-kind toggles in PrefsStore).
struct NotificationSettingsView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @Environment(\.dismiss) private var dismiss
    @State private var sentTest = false

    var body: some View {
        Form {
            Section {
                TextField("Torn API key", text: $prefs.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("API key")
            } footer: {
                Text("Used to read your bars & cooldowns so the app can alert you. A Limited-Access key is enough. This is the same key the app signed in with.")
            }

            Section {
                Toggle("Energy full", isOn: $prefs.notifyEnergy)
                Toggle("Nerve full", isOn: $prefs.notifyNerve)
                Toggle("Drug cooldown ends", isOn: $prefs.notifyDrug)
                Toggle("Booster cooldown ends", isOn: $prefs.notifyBooster)
                Toggle("Medical cooldown ends", isOn: $prefs.notifyMedical)
            } header: {
                Text("Alerts")
            } footer: {
                Text("Scheduled on your device from each bar's fill-time. Keep the app installed and open it now and then so the alerts stay accurate.")
            }

            Section {
                Button {
                    BarNotificationScheduler.sendTest()
                    sentTest = true
                } label: {
                    Label(sentTest ? "Test sent — check in a few seconds" : "Send a test notification",
                          systemImage: "bell.badge")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

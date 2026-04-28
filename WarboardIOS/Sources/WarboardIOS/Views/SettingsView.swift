import SwiftUI

/// iOS settings — Torn API key (auth on warboard endpoints) + warboard
/// base URL + notification toggles. No Sparkle (TestFlight handles
/// updates) and no menu-bar / dock-tile knobs (not applicable on iOS).
///
/// The Admin section is gated on `cachedAuth.isAdmin` (leader / co-leader
/// / war leader / banker). The PM2 logs sub-section is owner-only
/// (playerId 137558) — server enforces both gates regardless.
struct SettingsView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var admin = AdminSettingsViewModel()
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

            Section("Links") {
                Toggle("Open Torn links in-app", isOn: $prefs.linkOpenInApp)
                Text(prefs.linkOpenInApp
                     ? "Attack / profile links open in an in-app Safari view. Tap ✕ in the corner to return."
                     : "Attack / profile links hand off to your default browser or PDA app.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if let auth = admin.auth, auth.isAdmin {
                AdminSection(admin: admin, prefs: prefs)
            }
            if let auth = admin.auth, auth.isOwner {
                PM2LogsSection(admin: admin, prefs: prefs)
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
            Task { await admin.load(prefs: prefs) }
        }
    }
}

// MARK: — Admin section (leaders/co-leaders/war leaders/bankers)

private struct AdminSection: View {
    @ObservedObject var admin: AdminSettingsViewModel
    let prefs: PrefsStore

    var body: some View {
        Section {
            // ── War goal ──
            if let wid = admin.activeWarId {
                LabeledContent("Active war") {
                    Text("#\(wid)").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Custom war goal", text: $admin.targetField)
                        .keyboardType(.numberPad)
                    Button(admin.savingTarget ? "Saving…" : "Set") {
                        Task { await admin.saveTarget(prefs: prefs) }
                    }
                    .disabled(admin.savingTarget)
                    .buttonStyle(.borderedProminent)
                }
                if admin.currentTarget > 0 {
                    HStack {
                        Text("Current goal: \(admin.currentTarget.formatted())")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") {
                            admin.targetField = "0"
                            Task { await admin.saveTarget(prefs: prefs) }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                Text("Set 0 to clear and fall back to the auto-target.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("No active war — war goal editor available once a war starts.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            // ── Faction API key (server-side, shared) ──
            Text("Faction API key").font(.subheadline.bold())
            if admin.factionKeyStored {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Stored on server" + (admin.factionKeyLast4.isEmpty ? "" : " · ••••\(admin.factionKeyLast4)"))
                        .font(.caption)
                    Spacer()
                    Button(admin.savingFactionKey ? "Removing…" : "Remove") {
                        Task { await admin.removeFactionKey(prefs: prefs) }
                    }
                    .disabled(admin.savingFactionKey)
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            } else {
                SecureField("Paste faction-wide API key", text: $admin.factionKeyField)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Text("Used by warboard for server-side faction polling. Validated against Torn before storing.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button(admin.savingFactionKey ? "Saving…" : "Save key") {
                        Task { await admin.saveFactionKey(prefs: prefs) }
                    }
                    .disabled(admin.savingFactionKey)
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // ── Broadcast roles ──
            Text("Broadcast roles").font(.subheadline.bold())
            TextField("e.g. leader, co-leader, banker", text: $admin.rolesField)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            HStack {
                Text("Comma-separated faction positions allowed to send shouts.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(admin.savingRoles ? "Saving…" : "Save roles") {
                    Task { await admin.saveRoles(prefs: prefs) }
                }
                .disabled(admin.savingRoles)
                .buttonStyle(.bordered)
            }
            if !admin.roles.isEmpty {
                Text("Allowed: \(admin.roles.joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if let s = admin.status {
                Text(s).font(.caption).foregroundStyle(.green)
            }
        } header: {
            Text("Admin — Faction settings")
        } footer: {
            Text("Server enforces leader / co-leader / war leader / banker on these endpoints.")
                .font(.caption2)
        }
    }
}

// MARK: — PM2 logs (owner-only — playerId 137558)

private struct PM2LogsSection: View {
    @ObservedObject var admin: AdminSettingsViewModel
    let prefs: PrefsStore

    var body: some View {
        Section("Server logs (owner)") {
            Button {
                Task { await admin.loadLogs(prefs: prefs) }
            } label: {
                HStack {
                    Text(admin.loadingLogs ? "Fetching…" : "Refresh PM2 logs")
                    Spacer()
                    if admin.loadingLogs { ProgressView() }
                }
            }
            .disabled(admin.loadingLogs)

            if !admin.pm2Out.isEmpty || !admin.pm2Err.isEmpty {
                NavigationLink("View logs") {
                    PM2LogsViewer(out: admin.pm2Out, err: admin.pm2Err)
                }
            }
        }
    }
}

private struct PM2LogsViewer: View {
    let out: String
    let err: String
    @State private var tab: Tab = .out
    enum Tab: String, CaseIterable, Identifiable { case out = "out", err = "err"; var id: String { rawValue } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Stream", selection: $tab) {
                Text("stdout").tag(Tab.out)
                Text("stderr").tag(Tab.err)
            }
            .pickerStyle(.segmented)
            .padding()
            ScrollView {
                Text(tab == .out ? out : err)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
        }
        .navigationTitle("PM2 logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: — Admin VM

@MainActor
final class AdminSettingsViewModel: ObservableObject {
    @Published var auth: CachedAuth?
    @Published var activeWarId: String?
    @Published var currentTarget: Int = 0
    @Published var targetField: String = ""
    @Published var roles: [String] = []
    @Published var rolesField: String = ""
    @Published var factionKeyField: String = ""
    @Published var factionKeyStored: Bool = false
    @Published var factionKeyLast4: String = ""
    @Published var savingTarget = false
    @Published var savingRoles = false
    @Published var savingFactionKey = false
    @Published var pm2Out: String = ""
    @Published var pm2Err: String = ""
    @Published var loadingLogs = false
    @Published var status: String?

    func load(prefs: PrefsStore) async {
        // Re-auth when cached JWT has no factionPosition — old caches
        // (pre-v0.4.7) didn't store the role, which silently hides the
        // Admin section for leaders. Re-authing once writes the new
        // shape into PrefsStore for the rest of the JWT lifetime.
        var a = prefs.cachedJwt()
        if a == nil || (a?.factionPosition.isEmpty ?? true), !prefs.apiKey.isEmpty {
            if let fresh = await WarboardAPI.authenticate(baseUrl: prefs.baseUrl, apiKey: prefs.apiKey) {
                let cached = CachedAuth(
                    token: fresh.token,
                    factionId: fresh.player.factionId,
                    factionName: fresh.player.factionName,
                    playerId: fresh.player.playerId,
                    factionPosition: fresh.player.factionPosition ?? ""
                )
                prefs.storeJwt(cached)
                a = cached
            }
        }
        guard let a = a else { return }
        auth = a
        guard a.isAdmin else { return }
        let wars = await WarboardAPI.fetchWars(
            baseUrl: prefs.baseUrl, factionId: a.factionId, jwt: a.token
        )
        activeWarId = wars.first?.warId
        if let wid = activeWarId,
           let t = await WarboardAPI.fetchWarTarget(baseUrl: prefs.baseUrl, jwt: a.token, warId: wid) {
            currentTarget = t.value
            targetField = String(t.value)
        }
        let r = await WarboardAPI.fetchBroadcastRoles(baseUrl: prefs.baseUrl, jwt: a.token)
        roles = r
        rolesField = r.joined(separator: ", ")
        if let s = await WarboardAPI.fetchFactionKeyStatus(baseUrl: prefs.baseUrl, jwt: a.token) {
            factionKeyStored = s.stored
            factionKeyLast4 = s.last4 ?? ""
        }
    }

    func saveFactionKey(prefs: PrefsStore) async {
        guard let a = prefs.cachedJwt() else { return }
        let key = factionKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { status = "Paste a key first"; return }
        savingFactionKey = true
        let r = await WarboardAPI.setFactionApiKey(
            baseUrl: prefs.baseUrl, jwt: a.token, apiKey: key
        )
        savingFactionKey = false
        switch r {
        case .ok:
            factionKeyStored = true
            factionKeyLast4 = String(key.suffix(4))
            factionKeyField = ""
            status = "Faction key saved"
        case .error(let m):
            status = "Error: \(m)"
        }
    }

    func removeFactionKey(prefs: PrefsStore) async {
        guard let a = prefs.cachedJwt() else { return }
        savingFactionKey = true
        let r = await WarboardAPI.removeFactionApiKey(baseUrl: prefs.baseUrl, jwt: a.token)
        savingFactionKey = false
        switch r {
        case .ok:
            factionKeyStored = false
            factionKeyLast4 = ""
            status = "Faction key removed"
        case .error(let m):
            status = "Error: \(m)"
        }
    }

    func saveTarget(prefs: PrefsStore) async {
        guard let a = prefs.cachedJwt(), let wid = activeWarId else { return }
        let t = Int(targetField.trimmingCharacters(in: .whitespaces)) ?? 0
        savingTarget = true
        let r = await WarboardAPI.setWarTarget(
            baseUrl: prefs.baseUrl, jwt: a.token, warId: wid, target: t
        )
        savingTarget = false
        switch r {
        case .ok:
            currentTarget = t
            status = t == 0 ? "Target cleared" : "Target set to \(t.formatted())"
        case .error(let m):
            status = "Error: \(m)"
        }
    }

    func saveRoles(prefs: PrefsStore) async {
        guard let a = prefs.cachedJwt() else { return }
        let parsed = rolesField
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        savingRoles = true
        let r = await WarboardAPI.setBroadcastRoles(
            baseUrl: prefs.baseUrl, jwt: a.token, roles: parsed
        )
        savingRoles = false
        switch r {
        case .ok:
            roles = parsed
            status = "Broadcast roles saved"
        case .error(let m):
            status = "Error: \(m)"
        }
    }

    func loadLogs(prefs: PrefsStore) async {
        guard let a = prefs.cachedJwt() else { return }
        loadingLogs = true
        if let logs = await WarboardAPI.fetchPM2Logs(baseUrl: prefs.baseUrl, jwt: a.token) {
            pm2Out = logs.out
            pm2Err = logs.err
        } else {
            status = "Couldn't fetch logs"
        }
        loadingLogs = false
    }
}

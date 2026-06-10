import Foundation
import Combine

/// UserDefaults-backed prefs. Mirrors the Android `Prefs` DataStore so
/// the same conceptual fields exist on both clients. v0.1 stores the
/// Torn API key in plain UserDefaults; we'll move to Keychain in v0.2.
final class PrefsStore: ObservableObject {
    private let defaults: UserDefaults
    private static let kApiKey = "warboard.apiKey"
    private static let kBaseUrl = "warboard.baseUrl"
    private static let kJwt = "warboard.jwt"
    private static let kFactionId = "warboard.factionId"
    private static let kFactionName = "warboard.factionName"
    private static let kPlayerId = "warboard.playerId"
    private static let kFactionPosition = "warboard.factionPosition"
    private static let kNotifyChain = "warboard.notify.chain"
    private static let kNotifyVault = "warboard.notify.vault"
    private static let kMenuBarChain = "warboard.menubar.chain"
    private static let kLinkOpenInApp = "warboard.linkOpenInApp"
    private static let kStatsFilterMin = "warboard.statsFilterMin"
    private static let kStatsFilterMax = "warboard.statsFilterMax"
    private static let kHideOnline = "warboard.hideOnline"
    private static let kHideOffline = "warboard.hideOffline"
    private static let kNotifyEnergy = "warboard.notify.energy"
    private static let kNotifyNerve = "warboard.notify.nerve"
    private static let kNotifyDrug = "warboard.notify.drug"
    private static let kNotifyBooster = "warboard.notify.booster"
    private static let kNotifyMedical = "warboard.notify.medical"

    @Published var apiKey: String { didSet { defaults.set(apiKey, forKey: Self.kApiKey) } }
    @Published var baseUrl: String { didSet { defaults.set(baseUrl, forKey: Self.kBaseUrl) } }
    /// macOS notifications opt-ins. Default ON for chain (admins want
    /// to know when their chain is breaking) + vault (banker workflow).
    @Published var notifyChain: Bool { didSet { defaults.set(notifyChain, forKey: Self.kNotifyChain) } }
    @Published var notifyVault: Bool { didSet { defaults.set(notifyVault, forKey: Self.kNotifyVault) } }
    /// Whether the menu-bar status item shows the live chain count.
    @Published var menuBarChain: Bool { didSet { defaults.set(menuBarChain, forKey: Self.kMenuBarChain) } }
    /// Open Torn links (attack / profile) inside an in-app Safari sheet
    /// when true, hand off to the system browser / PDA when false. Default
    /// ON so the user stays in the app — the Safari sheet's close button
    /// drops them back instantly without a tab-switch round trip.
    @Published var linkOpenInApp: Bool { didSet { defaults.set(linkOpenInApp, forKey: Self.kLinkOpenInApp) } }
    /// Target-list filters — mirror the FactionOps userscript v5.1.1
    /// (stats min/max) + v5.1.5 (hide online) + v5.1.12 (hide offline).
    /// Stats fields are stored as raw text so the user's "10M" / "1.5B"
    /// input round-trips through the text field; parsed at filter time.
    @Published var statsFilterMin: String { didSet { defaults.set(statsFilterMin, forKey: Self.kStatsFilterMin) } }
    @Published var statsFilterMax: String { didSet { defaults.set(statsFilterMax, forKey: Self.kStatsFilterMax) } }
    @Published var hideOnline: Bool { didSet { defaults.set(hideOnline, forKey: Self.kHideOnline) } }
    @Published var hideOffline: Bool { didSet { defaults.set(hideOffline, forKey: Self.kHideOffline) } }
    /// Bar/cooldown "ready" alert opt-ins. Scheduled as local notifications
    /// from the user's bar fill-times. All default ON.
    @Published var notifyEnergy: Bool { didSet { defaults.set(notifyEnergy, forKey: Self.kNotifyEnergy) } }
    @Published var notifyNerve: Bool { didSet { defaults.set(notifyNerve, forKey: Self.kNotifyNerve) } }
    @Published var notifyDrug: Bool { didSet { defaults.set(notifyDrug, forKey: Self.kNotifyDrug) } }
    @Published var notifyBooster: Bool { didSet { defaults.set(notifyBooster, forKey: Self.kNotifyBooster) } }
    @Published var notifyMedical: Bool { didSet { defaults.set(notifyMedical, forKey: Self.kNotifyMedical) } }

    /// v0.4.60: switched default to App Group-shared UserDefaults so
    /// the home-screen Status widget can read the same prefs the main
    /// app writes (apiKey, baseUrl, etc. — needed if the widget ever
    /// wants to do its own API call instead of reading the BarsCache).
    /// Falls back to `.standard` only when the App Group container
    /// isn't available (unprovisioned simulator builds, broken
    /// entitlements). Cached prefs from pre-v0.4.60 installs WILL be
    /// lost on the first launch with App Group — acceptable since
    /// users only need to re-enter their Torn API key once.
    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
        self.apiKey = defaults.string(forKey: Self.kApiKey) ?? ""
        self.baseUrl = defaults.string(forKey: Self.kBaseUrl) ?? "https://tornwar.com"
        // Default ON for both notification categories on first run; user
        // can untoggle per category in Settings.
        self.notifyChain = defaults.object(forKey: Self.kNotifyChain) as? Bool ?? true
        self.notifyVault = defaults.object(forKey: Self.kNotifyVault) as? Bool ?? true
        self.menuBarChain = defaults.object(forKey: Self.kMenuBarChain) as? Bool ?? true
        self.linkOpenInApp = defaults.object(forKey: Self.kLinkOpenInApp) as? Bool ?? true
        self.statsFilterMin = defaults.string(forKey: Self.kStatsFilterMin) ?? ""
        self.statsFilterMax = defaults.string(forKey: Self.kStatsFilterMax) ?? ""
        self.hideOnline = defaults.object(forKey: Self.kHideOnline) as? Bool ?? false
        self.hideOffline = defaults.object(forKey: Self.kHideOffline) as? Bool ?? false
        self.notifyEnergy = defaults.object(forKey: Self.kNotifyEnergy) as? Bool ?? true
        self.notifyNerve = defaults.object(forKey: Self.kNotifyNerve) as? Bool ?? true
        self.notifyDrug = defaults.object(forKey: Self.kNotifyDrug) as? Bool ?? true
        self.notifyBooster = defaults.object(forKey: Self.kNotifyBooster) as? Bool ?? true
        self.notifyMedical = defaults.object(forKey: Self.kNotifyMedical) as? Bool ?? true
    }

    // JWT cache helpers — accessed by AuthRepository, not the UI.
    func cachedJwt() -> CachedAuth? {
        guard let token = defaults.string(forKey: Self.kJwt), !token.isEmpty else { return nil }
        return CachedAuth(
            token: token,
            factionId: defaults.string(forKey: Self.kFactionId) ?? "",
            factionName: defaults.string(forKey: Self.kFactionName) ?? "",
            playerId: defaults.string(forKey: Self.kPlayerId) ?? "",
            factionPosition: defaults.string(forKey: Self.kFactionPosition) ?? ""
        )
    }

    func storeJwt(_ auth: CachedAuth) {
        defaults.set(auth.token, forKey: Self.kJwt)
        defaults.set(auth.factionId, forKey: Self.kFactionId)
        defaults.set(auth.factionName, forKey: Self.kFactionName)
        defaults.set(auth.playerId, forKey: Self.kPlayerId)
        defaults.set(auth.factionPosition, forKey: Self.kFactionPosition)
    }

    func clearJwt() {
        for key in [Self.kJwt, Self.kFactionId, Self.kFactionName, Self.kPlayerId, Self.kFactionPosition] {
            defaults.removeObject(forKey: key)
        }
    }
}

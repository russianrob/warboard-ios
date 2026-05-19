import Foundation

/// Codable shape sent over WCSession.updateApplicationContext from the
/// iPhone to the paired Watch. Mirrors BarsCache.Snapshot fields but
/// lives in its own type so the iPhone import boundary stays explicit
/// (BarsCache is iPhone-side; this struct crosses the device boundary).
struct WatchBarsPayload: Codable, Hashable {
    var energyCurrent: Int
    var energyMax: Int
    var nerveCurrent: Int
    var nerveMax: Int
    /// Absolute epoch-ms when the drug cooldown ends. 0 if no active
    /// cooldown at write time.
    var drugDeadlineMs: Int64
    /// Same for booster.
    var boosterDeadlineMs: Int64
    /// When the iPhone produced this payload (epoch ms). Used by the
    /// watch to detect stale data and show a "last synced" hint.
    var writtenAtMs: Int64

    /// Flatten to a [String: Any] dictionary suitable for
    /// WCSession.updateApplicationContext. Keys match the property
    /// names so the watch can decode without an Info.plist mapping.
    func asContextDictionary() -> [String: Any] {
        [
            "energyCurrent": energyCurrent,
            "energyMax": energyMax,
            "nerveCurrent": nerveCurrent,
            "nerveMax": nerveMax,
            "drugDeadlineMs": drugDeadlineMs,
            "boosterDeadlineMs": boosterDeadlineMs,
            "writtenAtMs": writtenAtMs,
        ]
    }

    /// Inverse of asContextDictionary — returns nil when any required
    /// field is missing or wrong-typed.
    static func from(context: [String: Any]) -> WatchBarsPayload? {
        guard
            let eCur = context["energyCurrent"] as? Int,
            let eMax = context["energyMax"] as? Int,
            let nCur = context["nerveCurrent"] as? Int,
            let nMax = context["nerveMax"] as? Int
        else { return nil }
        let drug = (context["drugDeadlineMs"] as? Int64)
            ?? Int64(context["drugDeadlineMs"] as? Int ?? 0)
        let booster = (context["boosterDeadlineMs"] as? Int64)
            ?? Int64(context["boosterDeadlineMs"] as? Int ?? 0)
        let written = (context["writtenAtMs"] as? Int64)
            ?? Int64(context["writtenAtMs"] as? Int ?? 0)
        return WatchBarsPayload(
            energyCurrent: eCur, energyMax: eMax,
            nerveCurrent: nCur, nerveMax: nMax,
            drugDeadlineMs: drug,
            boosterDeadlineMs: booster,
            writtenAtMs: written
        )
    }
}

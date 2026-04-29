import Foundation

/// One row in Torn's `/v2/faction?selections=crimes` response. Built
/// as plain structs (not Decodable) because Torn's actual schema
/// drifts from what their docs claim — e.g. `position` is a string
/// (the role name), not an int; `user` is null for open slots OR
/// `{user_id: ...}` once filled. JSONSerialization parsing tolerates
/// missing / mistyped fields, where Codable would throw "data
/// couldn't be read because it isn't in the correct format."
struct OrganizedCrime: Identifiable, Equatable {
    let id: Int64
    let name: String
    let difficulty: Int
    /// One of: Planning, Recruiting, Ready, Cooldown, Successful, Failure, Expired.
    let status: String
    let createdAt: TimeInterval
    let plannedAt: TimeInterval?
    let readyAt: TimeInterval?
    let executedAt: TimeInterval?
    let slots: [Slot]

    struct Slot: Identifiable, Equatable {
        /// Synthetic — Torn doesn't ship a stable slot id, so we use
        /// position number. Stable per-OC for view diffing.
        var id: Int { positionNumber }
        let positionNumber: Int
        let positionName: String
        let userId: Int64?
        let userJoinedAt: TimeInterval?
        let userProgress: Double?
        /// 0–100. nil while the slot is open.
        let successChance: Double?
        let checkpointPassRate: Double?
        let requiredItemId: Int64?
        let requiredItemAvailable: Bool?

        var isOpen: Bool { userId == nil }
    }

    static func parse(_ root: [String: Any]) -> [OrganizedCrime] {
        guard let arr = root["crimes"] as? [[String: Any]] else { return [] }
        return arr.compactMap(parseCrime)
    }

    private static func parseCrime(_ o: [String: Any]) -> OrganizedCrime? {
        let id: Int64 = (o["id"] as? Int64) ?? Int64((o["id"] as? Int) ?? 0)
        guard id > 0 else { return nil }
        return OrganizedCrime(
            id: id,
            name: (o["name"] as? String) ?? "Unnamed",
            difficulty: (o["difficulty"] as? Int) ?? 0,
            status: (o["status"] as? String) ?? "Unknown",
            createdAt: timestamp(o["created_at"]) ?? 0,
            plannedAt: timestamp(o["planned_at"]),
            readyAt:   timestamp(o["ready_at"]),
            executedAt: timestamp(o["executed_at"]),
            slots: ((o["slots"] as? [[String: Any]]) ?? []).enumerated().map { idx, s in
                parseSlot(s, fallbackPosition: idx + 1)
            }
        )
    }

    private static func parseSlot(_ s: [String: Any], fallbackPosition: Int) -> Slot {
        // `position` could be either a string (role name) OR an int
        // (slot number) depending on Torn schema version. Inspect both
        // and route to the right field.
        let positionRaw = s["position"]
        let positionNumber: Int = {
            if let n = positionRaw as? Int { return n }
            if let n = s["position_number"] as? Int { return n }
            return fallbackPosition
        }()
        let positionName: String = {
            if let str = positionRaw as? String { return str }
            return (s["position_name"] as? String) ?? (s["name"] as? String) ?? "Slot \(positionNumber)"
        }()

        let user = s["user"] as? [String: Any]
        let userId: Int64? = {
            if let u = user {
                let raw = u["id"] ?? u["user_id"]
                if let i = raw as? Int64 { return i }
                if let i = raw as? Int { return Int64(i) }
            }
            // Torn sometimes flattens user_id into the slot itself.
            if let i = s["user_id"] as? Int64 { return i }
            if let i = s["user_id"] as? Int { return Int64(i) }
            return nil
        }()

        let req = (s["required_item"] as? [String: Any]) ?? (s["item_requirement"] as? [String: Any])

        return Slot(
            positionNumber: positionNumber,
            positionName: positionName,
            userId: userId,
            userJoinedAt: timestamp(user?["joined_at"]),
            userProgress: numberDouble(user?["progress"]),
            successChance: numberDouble(s["success_chance"]) ?? numberDouble(s["successChance"]),
            checkpointPassRate: numberDouble(s["checkpoint_pass_rate"]),
            requiredItemId: req.flatMap { ($0["id"] as? Int64) ?? ($0["id"] as? Int).map(Int64.init) },
            requiredItemAvailable: req?["is_available"] as? Bool
        )
    }

    private static func timestamp(_ v: Any?) -> TimeInterval? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return TimeInterval(i) }
        if let s = v as? String, let d = Double(s) { return d }
        return nil
    }

    private static func numberDouble(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String, let d = Double(s) { return d }
        return nil
    }
}

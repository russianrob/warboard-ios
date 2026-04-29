import Foundation

/// Endpoints powering the Manager tab's three audit sub-views — Missing
/// (slot owners without their required item), Unused (loaned items not
/// needed by any current OC), Payouts (completed OCs awaiting payment).
///
/// Mirrors oc-spawn-assistance.user.js's mgr_* helpers exactly so iOS
/// admins see the same lists the userscript surfaces in-browser. All
/// endpoints hit Torn's v2 API directly with the user's stored key —
/// no warboard middleman, since these reads aren't shareable across
/// the faction.
enum ManagerAPI {

    /// Items the userscript hides from the Missing list — usually
    /// because Torn's data is inconsistent for them (e.g. id 226 is
    /// the legacy "Tear Gas Grenade" entry that flags is_available
    /// false even when the user holds it).
    static let blacklistedItemIds: Set<Int64> = [226]

    /// `/v2/faction/?selections=` selections for the armoury endpoint.
    /// `clothing` is intentionally absent (Torn doesn't expose loanable
    /// clothing via this selection); page-AJAX-only category.
    static let armorySelections: [String] = [
        "utilities", "drugs", "medical", "boosters",
        "temporary", "armor", "weapons", "caches",
    ]

    // MARK: — Models

    /// One slot whose required item the assigned member doesn't have
    /// (Torn's slot.item_requirement.is_available == false).
    struct MissingItem: Identifiable, Equatable {
        var id: String { "\(crimeId):\(positionName):\(userId)" }
        let crimeId: Int64
        let crimeName: String
        let difficulty: Int
        let positionName: String
        let userId: Int64
        let userName: String
        let itemId: Int64
        let itemName: String?            // resolved post-fetch
        /// Armoury bucket ("weapons" / "armor" / …) — known only when
        /// the faction has at least one of this item in stock. nil
        /// means "we don't know"; in-app loan needs to widen-search.
        let armoryCategory: String?
    }

    /// One loaned-out item that isn't needed by any active OC for the
    /// user holding it. Tells admins to recall it.
    struct LoanedUnusedItem: Identifiable, Equatable {
        var id: String { "\(itemId):\(userId)" }
        let itemId: Int64
        let itemName: String
        let armoryCategory: String    // "weapons" / "armor" / …
        let userId: Int64
        let userName: String
    }

    /// One completed OC awaiting payment. `executedAt` drives age
    /// shading; `money/respect/hasItems` indicate what's owed.
    struct UnpaidPayout: Identifiable, Equatable {
        let id: Int64
        let name: String
        let difficulty: Int?
        let executedAt: TimeInterval
        let money: Int64
        let respect: Double
        let hasItems: Bool
        let payoutPct: Double?
    }

    /// One armoury entry — one row per (itemID, category). loanedTo
    /// is a comma-separated list of user IDs the API exposes as a
    /// single string.
    struct ArmoryItem: Equatable {
        let itemId: Int64
        let name: String
        let armoryCategory: String
        let available: Int
        let loanedToUserIds: [Int64]
    }

    // MARK: — Endpoints

    /// `/v2/faction/crimes?cat=available` — every Recruiting / Planning
    /// OC, including slot.item_requirement metadata.
    static func fetchAvailableCrimes(apiKey: String) async throws -> [OrganizedCrime] {
        return try await fetchCrimesByCategory(apiKey: apiKey, cat: "available")
    }

    /// `/v2/faction/crimes?cat=successful&filter=executed_at&from=…`
    /// Returns up to 100 successful OCs in the lookback window.
    /// Cap matches the userscript so the UI matches.
    static func fetchUnpaidPayouts(apiKey: String, lookbackDays: Int = 30) async throws -> [UnpaidPayout] {
        guard !apiKey.isEmpty else { throw OCAPIError.noKey }
        let nowSec = Int(Date().timeIntervalSince1970)
        let fromSec = nowSec - (lookbackDays * 86400)
        guard var comps = URLComponents(string: "https://api.torn.com/v2/faction/crimes") else {
            throw OCAPIError.http(0)
        }
        comps.queryItems = [
            URLQueryItem(name: "cat",    value: "successful"),
            URLQueryItem(name: "filter", value: "executed_at"),
            URLQueryItem(name: "from",   value: String(fromSec)),
            URLQueryItem(name: "to",     value: String(nowSec)),
            URLQueryItem(name: "sort",   value: "DESC"),
            URLQueryItem(name: "limit",  value: "100"),
            URLQueryItem(name: "key",    value: apiKey),
            URLQueryItem(name: "comment", value: "oc-spawn-ios"),
        ]
        guard let url = comps.url else { throw OCAPIError.http(0) }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw OCAPIError.http(code) }
        let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        // Torn returns either an array OR a dictionary keyed by id —
        // accept both, same as the userscript.
        let arr: [[String: Any]] = {
            if let a = root["crimes"] as? [[String: Any]] { return a }
            if let d = root["crimes"] as? [String: [String: Any]] {
                return Array(d.values)
            }
            return []
        }()
        var out: [UnpaidPayout] = []
        for c in arr {
            let rewards = (c["rewards"] as? [String: Any]) ?? [:]
            let payout  = (rewards["payout"] as? [String: Any]) ?? [:]
            // Skip already-paid OCs — userscript filter.
            if payout["paid_at"] != nil, !(payout["paid_at"] is NSNull) { continue }
            let money: Int64 = numberInt64(rewards["money"]) ?? 0
            let respect: Double = numberDouble(rewards["respect"]) ?? 0
            let items = rewards["items"] as? [Any] ?? []
            let hasItems = !items.isEmpty
            // Same filter the userscript uses to suppress "nothing to
            // pay" rows that occasionally come back.
            if money <= 0, respect <= 0, !hasItems { continue }
            let id = numberInt64(c["id"]) ?? 0
            guard id > 0 else { continue }
            out.append(UnpaidPayout(
                id: id,
                name: (c["name"] as? String) ?? "Unknown OC",
                difficulty: numberInt(c["difficulty"]),
                executedAt: numberDouble(c["executed_at"]) ?? 0,
                money: money,
                respect: respect,
                hasItems: hasItems,
                payoutPct: numberDouble(payout["percentage"])
            ))
        }
        return out
    }

    /// `/v2/faction/?selections=weapons,armor,…` — armoury holdings
    /// across every loanable selection in one shot.
    static func fetchArmory(apiKey: String) async throws -> [ArmoryItem] {
        guard !apiKey.isEmpty else { throw OCAPIError.noKey }
        guard var comps = URLComponents(string: "https://api.torn.com/v2/faction/") else {
            throw OCAPIError.http(0)
        }
        comps.queryItems = [
            URLQueryItem(name: "selections", value: armorySelections.joined(separator: ",")),
            URLQueryItem(name: "key",        value: apiKey),
            URLQueryItem(name: "comment",    value: "oc-spawn-ios"),
        ]
        guard let url = comps.url else { throw OCAPIError.http(0) }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw OCAPIError.http(code) }
        let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var items: [ArmoryItem] = []
        for sel in armorySelections {
            let rows = (root[sel] as? [[String: Any]]) ?? []
            // Torn confusingly returns "armor" as the selection but
            // category for postType lookup is the same string.
            let category = (sel == "weapons") ? "weapons" : sel
            for it in rows {
                let id = numberInt64(it["ID"]) ?? 0
                guard id > 0 else { continue }
                let name = (it["name"] as? String) ?? "Item #\(id)"
                let avail = numberInt(it["available"])
                    ?? numberInt(it["quantity"])
                    ?? 0
                // loaned_to is a comma-separated string (e.g. "12345,67890")
                // OR null. Parse defensively.
                let loanedTo: [Int64] = {
                    guard let raw = it["loaned_to"] as? String, !raw.isEmpty else { return [] }
                    return raw.split(separator: ",").compactMap { piece in
                        Int64(piece.trimmingCharacters(in: .whitespaces))
                    }
                }()
                items.append(ArmoryItem(
                    itemId: id, name: name, armoryCategory: category,
                    available: avail, loanedToUserIds: loanedTo
                ))
            }
        }
        return items
    }

    /// `/v2/torn/items?ids=…` — resolves item IDs to display names so
    /// Missing rows don't render as "Item #1234". Cheap; a single
    /// request covers up to ~100 ids.
    static func fetchItemNames(apiKey: String, ids: [Int64]) async throws -> [Int64: String] {
        guard !apiKey.isEmpty, !ids.isEmpty else { return [:] }
        let unique = Array(Set(ids))
        guard var comps = URLComponents(string: "https://api.torn.com/v2/torn/items") else {
            throw OCAPIError.http(0)
        }
        comps.queryItems = [
            URLQueryItem(name: "ids",     value: unique.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "key",     value: apiKey),
            URLQueryItem(name: "comment", value: "oc-spawn-ios"),
        ]
        guard let url = comps.url else { throw OCAPIError.http(0) }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw OCAPIError.http(code) }
        let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var out: [Int64: String] = [:]
        // Torn returns either { items: [{id, name, …}] } or
        // { items: { "123": {name, …} } } depending on selection.
        if let arr = root["items"] as? [[String: Any]] {
            for it in arr {
                if let i = numberInt64(it["id"]), let n = it["name"] as? String {
                    out[i] = n
                }
            }
        } else if let dict = root["items"] as? [String: [String: Any]] {
            for (k, v) in dict {
                if let i = Int64(k), let n = v["name"] as? String { out[i] = n }
            }
        }
        return out
    }

    // MARK: — Computations
    //
    // Pure functions (testable, no I/O) that map the raw API responses
    // into the three audit lists. Mirror mgr_getMissingOCItems,
    // mgr_loadUnusedTab, mgr_loadPayoutsTab from the userscript.

    /// Members whose assigned slot lists an item the user doesn't
    /// currently hold. Drops blacklisted item IDs.
    static func missingItems(
        crimes: [OrganizedCrime],
        memberNames: [Int64: String],
        itemNames: [Int64: String],
        armoryCategoryByItem: [Int64: String] = [:]
    ) -> [MissingItem] {
        var out: [MissingItem] = []
        for c in crimes {
            for slot in c.slots {
                guard let uid = slot.userId,
                      let iid = slot.requiredItemId,
                      slot.requiredItemAvailable == false,
                      !blacklistedItemIds.contains(iid)
                else { continue }
                out.append(MissingItem(
                    crimeId: c.id, crimeName: c.name, difficulty: c.difficulty,
                    positionName: slot.positionName,
                    userId: uid,
                    userName: memberNames[uid] ?? "Unknown [\(uid)]",
                    itemId: iid,
                    itemName: itemNames[iid],
                    armoryCategory: armoryCategoryByItem[iid]
                ))
            }
        }
        // Sort by crime difficulty desc → name → position so high-payout
        // OCs surface first (matches the urgency ordering the userscript
        // implies via its "spawn-needed" emphasis on top levels).
        out.sort { lhs, rhs in
            if lhs.difficulty != rhs.difficulty { return lhs.difficulty > rhs.difficulty }
            if lhs.crimeName != rhs.crimeName { return lhs.crimeName < rhs.crimeName }
            return lhs.positionName < rhs.positionName
        }
        return out
    }

    /// Loaned items not needed by ANY current OC the borrower is in.
    /// "Needed" is defined exactly like mgr_getAllOCItemRequirements:
    /// for every assigned slot, the (userId → set of itemIds) map.
    static func unusedLoaned(
        armory: [ArmoryItem],
        crimes: [OrganizedCrime],
        memberNames: [Int64: String]
    ) -> [LoanedUnusedItem] {
        // Build per-user need set.
        var neededByUser: [Int64: Set<Int64>] = [:]
        for c in crimes {
            for slot in c.slots {
                guard let uid = slot.userId, let iid = slot.requiredItemId else { continue }
                neededByUser[uid, default: []].insert(iid)
            }
        }
        // Restrict to items appearing in any OC requirement — same
        // "OC-relevant only" filter the userscript uses to avoid
        // surfacing every loaned weapon as 'unused'.
        let allOcItems = Set(neededByUser.values.flatMap { $0 })

        var out: [LoanedUnusedItem] = []
        for entry in armory {
            // Skip 'temporary' (consumables) — userscript drops them
            // because they're meant to be used and not retrieved.
            if entry.armoryCategory == "temporary" { continue }
            if !allOcItems.contains(entry.itemId) { continue }
            for uid in entry.loanedToUserIds {
                let needs = neededByUser[uid] ?? []
                if !needs.contains(entry.itemId) {
                    out.append(LoanedUnusedItem(
                        itemId: entry.itemId,
                        itemName: entry.name,
                        armoryCategory: entry.armoryCategory,
                        userId: uid,
                        userName: memberNames[uid] ?? "Unknown [\(uid)]"
                    ))
                }
            }
        }
        out.sort { lhs, rhs in
            if lhs.userName != rhs.userName { return lhs.userName < rhs.userName }
            return lhs.itemName < rhs.itemName
        }
        return out
    }

    // MARK: — Helpers (private)

    private static func fetchCrimesByCategory(apiKey: String, cat: String) async throws -> [OrganizedCrime] {
        guard !apiKey.isEmpty else { throw OCAPIError.noKey }
        guard var comps = URLComponents(string: "https://api.torn.com/v2/faction/crimes") else {
            throw OCAPIError.http(0)
        }
        comps.queryItems = [
            URLQueryItem(name: "cat",     value: cat),
            URLQueryItem(name: "key",     value: apiKey),
            URLQueryItem(name: "comment", value: "oc-spawn-ios"),
        ]
        guard let url = comps.url else { throw OCAPIError.http(0) }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw OCAPIError.http(code) }
        let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return OrganizedCrime.parse(root)
    }

    private static func numberInt64(_ v: Any?) -> Int64? {
        if let i = v as? Int64 { return i }
        if let i = v as? Int { return Int64(i) }
        if let d = v as? Double { return Int64(d) }
        if let s = v as? String { return Int64(s) }
        return nil
    }
    private static func numberInt(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let i = v as? Int64 { return Int(i) }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) }
        return nil
    }
    private static func numberDouble(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let i = v as? Int64 { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }
}

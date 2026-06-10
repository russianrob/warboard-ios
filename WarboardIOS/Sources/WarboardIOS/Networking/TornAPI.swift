import Foundation

/// Direct calls to api.torn.com using the user's own API key. Mirrors
/// the Android `TornApi` — Status tab uses fetchDashboard; v0.3 will
/// add fetchFactionChain when we port the chain bar's direct path.
enum TornAPI {
    private static let base = "https://api.torn.com"
    private static let dashboardSelections = "basic,bars,cooldowns,profile,travel"

    struct Bar: Equatable {
        let current: Int
        let maximum: Int
        let fulltime: Int   // seconds until full
    }

    struct DashboardSnapshot: Equatable {
        let playerName: String
        let factionName: String?
        /// Position role inside the faction — "Leader", "Co-leader",
        /// "Banker", "Member", or any custom role the faction defines.
        /// Pulled from /v2/user?selections=profile.faction.position.
        let factionPosition: String?
        let energy: Bar
        let nerve: Bar
        let happy: Bar
        let life: Bar
        let drugSeconds: Int
        let medicalSeconds: Int
        let boosterSeconds: Int
        let travelDestination: String?
        let travelSecondsLeft: Int
        let statusState: String        // "Okay" | "Hospital" | "Jail" | "Traveling" | …
        let statusDescription: String
        let statusSecondsLeft: Int
        let fetchedAt: Date
        let error: String?
    }

    struct FactionChain: Equatable {
        let current: Int
        let max: Int
        let timeout: Int64        // seconds until break
        let cooldown: Int64       // seconds of post-break wait
        let modifier: Double      // respect multiplier at current count
        /// Torn server-side wall-clock when the response was generated
        /// (epoch seconds). Anchor deadlines on this — not requestStart —
        /// to remove network RTT from the displayed countdown so the
        /// chain timer matches Torn's in-game UI exactly.
        let serverTimestamp: Int64
    }

    /// `/v2/faction?selections=chain` — direct Torn fetch with the
    /// user's API key, same path the Android client uses for the chain
    /// bar. Bypasses warboard so the chain ticker works even when the
    /// warboard server is down or rate-limiting us.
    static func fetchFactionChain(apiKey: String) async -> FactionChain? {
        guard !apiKey.isEmpty,
              let url = URL(string: "\(base)/v2/faction?selections=chain&key=\(apiKey)")
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            guard let c = root["chain"] as? [String: Any] else { return nil }
            // Torn v2 returns a top-level "timestamp" (epoch seconds)
            // representing when the response was generated. Falling back
            // to local wall-clock if it's missing keeps the previous
            // behaviour intact for any odd response shape.
            let serverTs = (root["timestamp"] as? Int64)
                ?? Int64((root["timestamp"] as? Int) ?? Int(Date().timeIntervalSince1970))
            return FactionChain(
                current:  (c["current"]  as? Int) ?? 0,
                max:      (c["max"]      as? Int) ?? 0,
                timeout:  (c["timeout"]  as? Int64) ?? Int64((c["timeout"]  as? Int) ?? 0),
                cooldown: (c["cooldown"] as? Int64) ?? Int64((c["cooldown"] as? Int) ?? 0),
                modifier: (c["modifier"] as? Double) ?? Double((c["modifier"] as? Int) ?? 1),
                serverTimestamp: serverTs
            )
        } catch { return nil }
    }

    /// `/user/?selections=basic,bars,cooldowns,profile,travel` (v1).
    /// v1 returns each bar at root level (energy/nerve/happy/life as
    /// top-level keys); the parser pulls them from there. The v2 user
    /// endpoint has a different shape we don't currently support.
    static func fetchDashboard(apiKey: String) async -> DashboardSnapshot? {
        guard !apiKey.isEmpty,
              let url = URL(string: "\(base)/user/?selections=\(dashboardSelections)&key=\(apiKey)")
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let err = root["error"] as? [String: Any] {
                let msg = (err["error"] as? String) ?? "Torn API error"
                return DashboardSnapshot(
                    playerName: "", factionName: nil, factionPosition: nil,
                    energy: Bar(current: 0, maximum: 100, fulltime: 0),
                    nerve:  Bar(current: 0, maximum: 100, fulltime: 0),
                    happy:  Bar(current: 0, maximum: 100, fulltime: 0),
                    life:   Bar(current: 0, maximum: 100, fulltime: 0),
                    drugSeconds: 0, medicalSeconds: 0, boosterSeconds: 0,
                    travelDestination: nil, travelSecondsLeft: 0,
                    statusState: "", statusDescription: "", statusSecondsLeft: 0,
                    fetchedAt: Date(), error: msg
                )
            }
            return parseDashboard(root)
        } catch {
            return nil
        }
    }

    struct InventoryEntry: Identifiable, Equatable {
        let id: Int
        let name: String
        let quantity: Int
        let category: String
    }

    /// `/v2/user?selections=inventory` — the user's item inventory. v1's
    /// inventory selection is deprecated (returns a string), so this uses v2
    /// standalone. Powers the Quick Items picker.
    /// Returns the parsed inventory and, on failure, a human-readable reason so
    /// the picker can show WHY it's empty (key access level, network, etc.).
    static func fetchInventory(apiKey: String) async -> (items: [InventoryEntry], error: String?) {
        // v2 only exposes inventory as a SUB-RESOURCE path (it's not a valid
        // `?selections=` value — that returns "Incorrect category"), and v2 auth
        // is the `Authorization: ApiKey <key>` header.
        guard !apiKey.isEmpty else { return ([], "No API key set") }
        guard let url = URL(string: "\(base)/v2/user/inventory") else { return ([], "Bad URL") }
        var req = URLRequest(url: url)
        req.setValue("ApiKey \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let err = root["error"] as? [String: Any] {
                let msg = (err["error"] as? String) ?? "Torn API error"
                let code = (err["code"] as? Int).map { " (code \($0))" } ?? ""
                return ([], "Torn API: \(msg)\(code)")
            }
            // v2 shape: inventory is an OBJECT { items: [{id, amount, name,
            // faction_owned, ...}], timestamp }, NOT an array; quantity is `amount`.
            let inv = root["inventory"] as? [String: Any] ?? [:]
            let items = inv["items"] as? [[String: Any]] ?? []
            let parsed: [InventoryEntry] = items.compactMap { o in
                guard let name = o["name"] as? String else { return nil }
                let id = (o["id"] as? Int) ?? Int((o["id"] as? String) ?? "") ?? 0
                guard id > 0 else { return nil }
                let qty = (o["amount"] as? Int) ?? (o["quantity"] as? Int) ?? 0
                return InventoryEntry(id: id, name: name, quantity: qty, category: "")
            }
            if parsed.isEmpty {
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let snippet = String(data: data.prefix(160), encoding: .utf8) ?? ""
                return ([], "Empty (HTTP \(status)): \(snippet)")
            }
            // Dedupe by item id (weapons appear once per uid) so the picker
            // shows one pill per item type.
            var seen = Set<Int>()
            return (parsed.filter { seen.insert($0.id).inserted }, nil)
        } catch {
            return ([], "Network: \(error.localizedDescription)")
        }
    }

    /// `/user/?selections=attacks` (v1) — last-100 fights involving the
    /// user (attacks AND defends). Returned as the raw `attacks` map so
    /// the caller can POST it through to warboard untouched (the server
    /// does the parsing + dedupe). Returns an empty dict on error so
    /// reporters never crash on transient failures.
    static func fetchMyAttacks(apiKey: String) async -> [String: Any] {
        guard !apiKey.isEmpty,
              let url = URL(string: "\(base)/user/?selections=attacks&key=\(apiKey)")
        else { return [:] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return root["attacks"] as? [String: Any] ?? [:]
        } catch { return [:] }
    }

    private static func parseDashboard(_ root: [String: Any]) -> DashboardSnapshot {
        // v1 puts each bar at root level — energy / nerve / happy / life
        // are top-level keys, NOT under a "bars" wrapper. Earlier code
        // looked under root["bars"] which is always nil and produced
        // the 0/100 placeholder rendering.
        let cd = root["cooldowns"] as? [String: Any] ?? [:]
        let travel = root["travel"] as? [String: Any] ?? [:]
        let status = root["status"] as? [String: Any] ?? [:]

        let isTraveling = (travel["time_left"] as? Int).map { $0 > 0 } ?? false
        let dest = travel["destination"] as? String
        let timeLeft = (travel["time_left"] as? Int) ?? 0
        let faction = root["faction"] as? [String: Any]
        return DashboardSnapshot(
            playerName: (root["name"] as? String) ?? "",
            factionName: faction?["faction_name"] as? String,
            factionPosition: faction?["position"] as? String,
            energy: bar(root["energy"]),
            nerve:  bar(root["nerve"]),
            happy:  bar(root["happy"]),
            life:   bar(root["life"]),
            drugSeconds:    (cd["drug"]    as? Int) ?? 0,
            medicalSeconds: (cd["medical"] as? Int) ?? 0,
            boosterSeconds: (cd["booster"] as? Int) ?? 0,
            travelDestination: (isTraveling && dest != "Torn") ? dest : nil,
            travelSecondsLeft: timeLeft,
            statusState: (status["state"] as? String) ?? "Okay",
            statusDescription: (status["description"] as? String) ?? "",
            statusSecondsLeft: (status["until"] as? Int).map { max(0, $0 - Int(Date().timeIntervalSince1970)) } ?? 0,
            fetchedAt: Date(), error: nil
        )
    }

    private static func bar(_ raw: Any?) -> Bar {
        let o = (raw as? [String: Any]) ?? [:]
        return Bar(
            current:  (o["current"]  as? Int) ?? 0,
            maximum:  (o["maximum"]  as? Int) ?? 100,
            fulltime: (o["fulltime"] as? Int) ?? 0
        )
    }
}

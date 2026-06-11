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

    /// `/v2/torn?selections=items` — Torn's master item catalog.
    ///
    /// Torn REMOVED the personal-inventory API (every inventory form — v1
    /// `?selections=inventory`, v2 `?selections=inventory`, and the
    /// `/v2/user/inventory` sub-resource — now returns "Incorrect category"
    /// / code 21). So Quick Items is populated from the catalog instead, exactly
    /// like TornPDA does (its own code: "Personal inventory was removed from the
    /// API"). Returns all catalog items (id, name, type); the picker is
    /// searchable so the ~1500-item list stays manageable.
    static func fetchItemCatalog(apiKey: String) async -> (items: [InventoryEntry], error: String?) {
        guard !apiKey.isEmpty else { return ([], "No API key set") }
        guard let url = URL(string: "\(base)/v2/torn?selections=items&key=\(apiKey)") else { return ([], "Bad URL") }
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let err = root["error"] as? [String: Any] {
                let msg = (err["error"] as? String) ?? "Torn API error"
                let code = (err["code"] as? Int).map { " (code \($0))" } ?? ""
                return ([], "Torn API: \(msg)\(code)")
            }
            // v2 catalog shape: { "items": [ {id, name, type, sub_type, ...} ] }.
            let rawItems = root["items"] as? [[String: Any]] ?? []
            // Quick Items is a one-tap "use item" list, so keep only the
            // consumable/usable types and drop weapons (Melee/Primary/Secondary/
            // Temporary), armour (Defensive), collectibles (Collectible/Artifact/
            // Plushie/Flower/Jewelry), cars, clothing, tools, etc.
            let usableTypes: Set<String> = [
                "medical", "drug", "booster", "energy drink",
                "alcohol", "candy", "enhancer", "supply pack",
            ]
            let parsed: [InventoryEntry] = rawItems.compactMap { o in
                guard let name = o["name"] as? String, !name.isEmpty else { return nil }
                let id = (o["id"] as? Int) ?? Int((o["id"] as? String) ?? "") ?? 0
                guard id > 0 else { return nil }
                let type = (o["type"] as? String) ?? ""
                guard usableTypes.contains(type.lowercased()) else { return nil }
                return InventoryEntry(id: id, name: name, quantity: 0, category: type)
            }
            if parsed.isEmpty {
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                return ([], "Empty (HTTP \(status)): \(snippet)")
            }
            var seen = Set<Int>()
            return (parsed.filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }, nil)
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

    /// One incoming attack on the faction, for the War Room's Retaliation tab.
    struct FactionAttack: Identifiable {
        let id: String          // attack id/code — also the List row id
        let attackerId: Int
        let attackerName: String
        let attackerLevel: Int
        let attackerFactionId: Int
        let defenderName: String
        let result: String
        let endedTs: Int        // unix seconds; drives the 5-min retal window
    }

    /// `/v2/faction/attacks` — the faction's recent attack feed (needs faction-AA
    /// key access). Returns the latest page (newest first); the Retaliation tab
    /// filters it to enemy-faction attacks on our members.
    static func fetchFactionAttacks(apiKey: String, limit: Int = 100) async -> (attacks: [FactionAttack], error: String?) {
        guard !apiKey.isEmpty else { return ([], "No API key set") }
        guard let url = URL(string: "\(base)/v2/faction/attacks?key=\(apiKey)&limit=\(limit)&sort=DESC") else { return ([], "Bad URL") }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let err = root["error"] as? [String: Any] {
                let msg = (err["error"] as? String) ?? "Torn API error"
                let code = (err["code"] as? Int).map { " (code \($0))" } ?? ""
                return ([], "Torn API: \(msg)\(code)")
            }
            // v2 returns { "attacks": [ {...} ] } (occasionally an object map).
            let rawList: [[String: Any]]
            if let arr = root["attacks"] as? [[String: Any]] {
                rawList = arr
            } else if let dict = root["attacks"] as? [String: Any] {
                rawList = dict.values.compactMap { $0 as? [String: Any] }
            } else {
                rawList = []
            }
            let parsed: [FactionAttack] = rawList.compactMap { a in
                // Stealthed attacks have no attacker object — can't retaliate.
                guard let attacker = a["attacker"] as? [String: Any] else { return nil }
                let aid = (attacker["id"] as? Int) ?? Int((attacker["id"] as? String) ?? "") ?? 0
                guard aid > 0 else { return nil }
                let aFac = ((attacker["faction"] as? [String: Any])?["id"] as? Int)
                    ?? (a["attacker_faction"] as? Int) ?? 0
                let defender = a["defender"] as? [String: Any]
                let ended = (a["ended"] as? Int) ?? (a["started"] as? Int) ?? 0
                let rowId = (a["id"] as? Int).map(String.init)
                    ?? (a["code"] as? String)
                    ?? "\(aid)-\(ended)"
                return FactionAttack(
                    id: rowId,
                    attackerId: aid,
                    attackerName: (attacker["name"] as? String) ?? "ID \(aid)",
                    attackerLevel: (attacker["level"] as? Int) ?? 0,
                    attackerFactionId: aFac,
                    defenderName: (defender?["name"] as? String) ?? "?",
                    result: (a["result"] as? String) ?? "",
                    endedTs: ended
                )
            }
            return (parsed, nil)
        } catch {
            return ([], "Network: \(error.localizedDescription)")
        }
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

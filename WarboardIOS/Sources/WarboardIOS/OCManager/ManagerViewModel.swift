import Foundation
import Combine

/// Backs the Manager tab + its three audit sub-tabs (Missing, Unused,
/// Payouts). Each sub-tab is loaded on demand the first time it's
/// shown — keeps cold-start cheap and avoids burning the API key budget
/// on lists the user may not look at.
///
/// Available crimes + member roster are shared across Open Slots /
/// Missing / Unused (same Torn endpoints), so they ride a 30 s poll.
/// Armoury + payouts have their own 60 s+ refresh because Torn's
/// data for them lags anyway.
@MainActor
final class ManagerViewModel: ObservableObject {

    enum LoadState<T: Equatable>: Equatable {
        case idle
        case loading
        case ready(T)
        case error(String)
    }

    // Shared (Open Slots / Missing / Unused all read these).
    @Published private(set) var crimes: LoadState<[OrganizedCrime]> = .idle
    @Published private(set) var members: [Int64: OCFactionMember] = [:]

    // Sub-tab specific.
    @Published private(set) var armory: LoadState<[ManagerAPI.ArmoryItem]> = .idle
    @Published private(set) var payouts: LoadState<[ManagerAPI.UnpaidPayout]> = .idle
    @Published private(set) var itemNames: [Int64: String] = [:]

    @Published var lastUpdated: Date?

    /// (itemId, userId) pairs the user has just loaned or retrieved
    /// successfully. Used to hide the row optimistically — Torn's
    /// armoury endpoint can lag 60-90s before reflecting the change,
    /// and we don't want the row to sit there with a green ✓ for
    /// that long. Cleared per-entry after 2 min OR sooner if the
    /// next refresh confirms the change naturally (the row already
    /// won't appear in the projection then, so the entry just ages
    /// out harmlessly).
    @Published private(set) var optimisticallyRemoved: Set<String> = []

    private weak var prefs: PrefsStore?
    private var pollTask: Task<Void, Never>?
    private var lastMembersFetch: Date?
    private var lastArmoryFetch: Date?
    private var lastPayoutsFetch: Date?

    func bind(prefs: PrefsStore) { self.prefs = prefs }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tickShared()
                try? await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        Task {
            await tickShared()
            await refreshArmoryIfStale(force: true)
            await refreshPayoutsIfStale(force: true)
        }
    }

    /// Called from ActionRow on a successful loan/retrieve. Hides the
    /// matching row immediately and triggers a forced refresh so the
    /// authoritative API state catches up. The local hide expires
    /// after 2 min as a safety net in case the API never reflects
    /// (item was already gone, race with another admin, …).
    func markActioned(itemId: Int64, userId: Int64) {
        let key = "\(itemId):\(userId)"
        optimisticallyRemoved.insert(key)
        Task { [weak self] in
            await self?.refreshArmoryIfStale(force: true)
            await self?.tickShared()
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120 * NSEC_PER_SEC)
            self?.optimisticallyRemoved.remove(key)
        }
    }

    /// Called when the Missing/Unused sub-tab appears. Triggers an
    /// armoury + crimes refresh so item-name resolution can fill in
    /// the gaps before the row renders.
    func ensureMissingAndUnusedReady() {
        Task {
            await tickShared()                  // crimes + members
            await refreshArmoryIfStale()        // for Unused
            await resolveMissingItemNames()     // friendly Missing rows
        }
    }

    /// Called when the Payouts sub-tab appears.
    func ensurePayoutsReady() {
        Task { await refreshPayoutsIfStale() }
    }

    // MARK: — Polls

    private func tickShared() async {
        guard let key = prefs?.apiKey, !key.isEmpty else {
            crimes = .error("Set your Torn API key in Settings.")
            return
        }
        if case .ready = crimes { /* keep prior data while refetching */ }
        else { crimes = .loading }
        do {
            let list = try await ManagerAPI.fetchAvailableCrimes(apiKey: key)
            crimes = .ready(list)
            lastUpdated = Date()
        } catch {
            crimes = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
        // Roster every 5 min — names rarely change.
        let stale = lastMembersFetch.map { Date().timeIntervalSince($0) > 300 } ?? true
        if stale, let roster = try? await OCMembersAPI.fetchMembers(apiKey: key) {
            members = Dictionary(uniqueKeysWithValues: roster.map { ($0.id, $0) })
            lastMembersFetch = Date()
        }
    }

    private func refreshArmoryIfStale(force: Bool = false) async {
        guard let key = prefs?.apiKey, !key.isEmpty else { return }
        let stale = lastArmoryFetch.map { Date().timeIntervalSince($0) > 60 } ?? true
        guard force || stale else { return }
        if case .ready = armory { /* keep prior data while refetching */ }
        else { armory = .loading }
        do {
            let items = try await ManagerAPI.fetchArmory(apiKey: key)
            armory = .ready(items)
            lastArmoryFetch = Date()
        } catch {
            armory = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    private func refreshPayoutsIfStale(force: Bool = false) async {
        guard let key = prefs?.apiKey, !key.isEmpty else { return }
        let stale = lastPayoutsFetch.map { Date().timeIntervalSince($0) > 60 } ?? true
        guard force || stale else { return }
        if case .ready = payouts { /* keep prior data while refetching */ }
        else { payouts = .loading }
        do {
            let list = try await ManagerAPI.fetchUnpaidPayouts(apiKey: key)
            payouts = .ready(list)
            lastPayoutsFetch = Date()
        } catch {
            payouts = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    /// Resolve missing-item names (so rows say "Yorkshire Terrier" not
    /// "Item #1234"). Only requests IDs we don't already have cached;
    /// caps at 60 ids per request to stay well under Torn's URL limit.
    private func resolveMissingItemNames() async {
        guard case .ready(let list) = crimes,
              let key = prefs?.apiKey, !key.isEmpty else { return }
        let needed = Set(
            list.flatMap { c in
                c.slots.compactMap { s -> Int64? in
                    guard let iid = s.requiredItemId,
                          s.requiredItemAvailable == false,
                          itemNames[iid] == nil
                    else { return nil }
                    return iid
                }
            }
        )
        guard !needed.isEmpty else { return }
        let ids = Array(needed.prefix(60))
        if let dict = try? await ManagerAPI.fetchItemNames(apiKey: key, ids: ids) {
            for (k, v) in dict { itemNames[k] = v }
        }
    }

    // MARK: — Derived projections

    /// Member-name lookup as a flat dict (id → name) — what the
    /// projections in ManagerAPI expect.
    var memberNameMap: [Int64: String] {
        Dictionary(uniqueKeysWithValues: members.map { ($0.key, $0.value.name) })
    }

    /// itemId → armoury category, derived from the live armoury fetch.
    /// Used to route loan POSTs to the right `type` field. Nil entries
    /// → in-app loan widens its category sweep before giving up.
    var armoryCategoryByItem: [Int64: String] {
        guard case .ready(let items) = armory else { return [:] }
        var out: [Int64: String] = [:]
        for it in items where out[it.itemId] == nil { out[it.itemId] = it.armoryCategory }
        return out
    }

    var missing: [ManagerAPI.MissingItem] {
        guard case .ready(let list) = crimes else { return [] }
        let base = ManagerAPI.missingItems(
            crimes: list,
            memberNames: memberNameMap,
            itemNames: itemNames,
            armoryCategoryByItem: armoryCategoryByItem
        )
        return base.filter { !optimisticallyRemoved.contains("\($0.itemId):\($0.userId)") }
    }

    var unused: [ManagerAPI.LoanedUnusedItem] {
        guard case .ready(let crimeList) = crimes,
              case .ready(let armoryList) = armory else { return [] }
        let base = ManagerAPI.unusedLoaned(
            armory: armoryList,
            crimes: crimeList,
            memberNames: memberNameMap
        )
        return base.filter { !optimisticallyRemoved.contains("\($0.itemId):\($0.userId)") }
    }
}

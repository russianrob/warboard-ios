import Foundation

/// Cached warboard JWT + identity. Mirrors the Android CachedAuth.
struct CachedAuth: Equatable {
    let token: String
    let factionId: String
    let factionName: String
    let playerId: String
    /// Role inside the faction. Lowercased on use to match the
    /// server's LEADER_POSITIONS check (leader / co-leader / war
    /// leader / banker). Empty string means we don't know — gate
    /// admin features off in that case.
    let factionPosition: String

    var isAdmin: Bool {
        let p = factionPosition.lowercased()
        return p == "leader" || p == "co-leader" || p == "war leader" || p == "banker"
    }
    var isOwner: Bool { playerId == "137558" }
}

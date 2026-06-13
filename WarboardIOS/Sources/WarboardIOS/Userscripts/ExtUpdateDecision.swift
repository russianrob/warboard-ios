import Foundation

/// Pure version policy for remote extension updates, kept out of the
/// WebKit-bound `RemoteExtStore` so it is unit-testable on Linux. Mirrors the
/// guards `RemoteExtStore` applies exactly: offer only a strictly-newer version,
/// and refuse when the bundled seed is newer than the server build's
/// `minSeedVersion` floor (so a newer in-app seed is never shadowed by an older
/// server copy).
enum ExtUpdateDecision {
    static func versionToOffer(active: String, remote: String,
                               seed: String, minSeed: String?) -> String? {
        guard VersionCompare.isUpdate(installed: active, remote: remote) else { return nil }
        if let minSeed, VersionCompare.compare(seed, minSeed) == .orderedDescending { return nil }
        return remote
    }
}

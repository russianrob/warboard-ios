import Foundation
import CryptoKit

/// Decides, per launch, whether each WebExtension's files are served from a
/// server-fetched cache (`…/Application Support/webext-remote/<id>/`) or the app
/// bundle (the seed). The cache wins only when it is valid and its version is
/// `>=` the bundled seed's. Updates are user-driven: `checkForUpdate` (cheap,
/// version.json only) surfaces an available version; `installUpdate` downloads +
/// atomic-swaps it and `invalidate`s the memo so a hot-swap re-resolves to it.
final class RemoteExtStore: @unchecked Sendable {
    static let shared = RemoteExtStore()

    private let fm = FileManager.default
    private let defaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard
    private var containerCache: [String: URL] = [:]
    private let lock = NSLock()

    private var remoteDir: URL? {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("webext-remote", isDirectory: true)
    }
    private var bundleBase: URL { Bundle.main.resourceURL ?? URL(fileURLWithPath: "/") }

    /// The directory callers append `"<id>/<path>"` to. The cache container
    /// (`…/webext-remote/`) when that id's cached copy is valid and `>=` the
    /// seed, else the app bundle. Memoized per launch (called on every request).
    func containerBase(for id: String) -> URL {
        lock.lock(); defer { lock.unlock() }
        if let c = containerCache[id] { return c }
        let chosen = resolveContainer(for: id)
        containerCache[id] = chosen
        return chosen
    }

    private func resolveContainer(for id: String) -> URL {
        guard let remoteDir,
              let cacheVer = manifestVersion(at: remoteDir.appendingPathComponent("\(id)/manifest.json"))
        else { return bundleBase }
        let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
        // Cache wins only when cacheVer >= seedVer (a newer bundled seed is never shadowed).
        return VersionCompare.compare(cacheVer, seedVer) != .orderedAscending ? remoteDir : bundleBase
    }

    private func manifestVersion(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let v = obj["version"] as? String else { return nil }
        return v
    }

    // MARK: - Update fetch

    private struct RemoteVersionManifest: Decodable {
        let version: String
        let base: String
        let minSeedVersion: String?
        let files: [Entry]
        struct Entry: Decodable { let path: String; let sha256: String }
    }

    enum RemoteExtError: Error { case badSource, manifestUnavailable, downloadFailed, badStage }

    /// Drop the per-launch memoized container choice for `id` so the next
    /// `containerBase(for: id)` re-resolves (picks a freshly-installed cache).
    func invalidate(id: String) {
        lock.lock(); defer { lock.unlock() }
        containerCache[id] = nil
    }

    /// Cheap: fetch only `version.json` and return the version to OFFER as an
    /// update (or nil). No download. Drives the in-app "check for updates".
    func checkForUpdate(id: String, source: URL) async -> String? {
        guard let (data, resp) = try? await URLSession.shared.data(from: source),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data)
        else { return nil }
        let activeVer = manifestVersion(at: containerBase(for: id).appendingPathComponent("\(id)/manifest.json")) ?? "0"
        let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
        return ExtUpdateDecision.versionToOffer(active: activeVer, remote: man.version,
                                                seed: seedVer, minSeed: man.minSeedVersion)
    }

    /// Heavy: download every file (sha256-verified) into a staging dir and
    /// atomic-swap into `…/webext-remote/<id>/`. On success invalidate the memo
    /// and return the new version. Throws on any failure — the live cache is
    /// untouched until the swap, so a failure never half-installs.
    @discardableResult
    func installUpdate(id: String, source: URL) async throws -> String {
        guard let remoteDir, let scheme = source.scheme, let host = source.host else {
            throw RemoteExtError.badSource
        }
        let origin = "\(scheme)://\(host)" + (source.port.map { ":\($0)" } ?? "")
        let (data, resp) = try await URLSession.shared.data(from: source)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data) else {
            throw RemoteExtError.manifestUnavailable
        }

        let staging = remoteDir.appendingPathComponent("\(id).incoming", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        for f in man.files {
            guard let fileURL = URL(string: origin + man.base + f.path) else {
                try? fm.removeItem(at: staging); throw RemoteExtError.downloadFailed
            }
            let (fdata, fresp) = try await URLSession.shared.data(from: fileURL)
            let sha = SHA256.hash(data: fdata).map { String(format: "%02x", $0) }.joined()
            guard (fresp as? HTTPURLResponse)?.statusCode == 200, sha == f.sha256 else {
                try? fm.removeItem(at: staging); throw RemoteExtError.downloadFailed
            }
            let dest = staging.appendingPathComponent(f.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fdata.write(to: dest)
        }
        guard manifestVersion(at: staging.appendingPathComponent("manifest.json")) != nil else {
            try? fm.removeItem(at: staging); throw RemoteExtError.badStage
        }

        let live = remoteDir.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: remoteDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: live.path) {
            _ = try fm.replaceItemAt(live, withItemAt: staging)
        } else {
            try fm.moveItem(at: staging, to: live)
        }
        defaults.set(man.version, forKey: "webext-remote-version.\(id)")
        invalidate(id: id)
        WebDiag.log("webext-remote-updated", ["id": id, "version": man.version])
        return man.version
    }
}

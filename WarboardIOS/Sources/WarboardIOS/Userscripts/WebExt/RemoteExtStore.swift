import Foundation
import CryptoKit

/// Decides, per launch, whether each WebExtension's files are served from a
/// server-fetched cache (`…/Application Support/webext-remote/<id>/`) or the app
/// bundle (the seed). The cache wins only when it is valid and its version is
/// `>=` the bundled seed's. Also performs the silent background update fetch
/// (`checkAndFetch`), which applies on the NEXT launch — never a live hot-swap.
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

    /// Silent. Fetch `version.json`; if it's newer than the active copy (and the
    /// bundled seed isn't newer than `minSeedVersion`), download every file
    /// (sha256-verified) into a staging dir and atomic-swap into
    /// `…/webext-remote/<id>/`. Any failure discards staging and keeps the last
    /// good copy. Applies on the next launch.
    func checkAndFetch(id: String, source: URL) async {
        guard let remoteDir, let scheme = source.scheme, let host = source.host else { return }
        let origin = "\(scheme)://\(host)" + (source.port.map { ":\($0)" } ?? "")
        do {
            let (data, resp) = try await URLSession.shared.data(from: source)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data) else { return }

            let activeVer = manifestVersion(at: containerBase(for: id).appendingPathComponent("\(id)/manifest.json")) ?? "0"
            guard VersionCompare.isUpdate(installed: activeVer, remote: man.version) else { return }
            let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
            if let minSeed = man.minSeedVersion, VersionCompare.compare(seedVer, minSeed) == .orderedDescending { return }

            let staging = remoteDir.appendingPathComponent("\(id).incoming", isDirectory: true)
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)

            for f in man.files {
                guard let fileURL = URL(string: origin + man.base + f.path) else {
                    try? fm.removeItem(at: staging); return
                }
                let (fdata, fresp) = try await URLSession.shared.data(from: fileURL)
                let sha = SHA256.hash(data: fdata).map { String(format: "%02x", $0) }.joined()
                guard (fresp as? HTTPURLResponse)?.statusCode == 200, sha == f.sha256 else {
                    try? fm.removeItem(at: staging); return
                }
                let dest = staging.appendingPathComponent(f.path)
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fdata.write(to: dest)
            }
            // Validate the staged manifest parses before committing.
            guard manifestVersion(at: staging.appendingPathComponent("manifest.json")) != nil else {
                try? fm.removeItem(at: staging); return
            }

            let live = remoteDir.appendingPathComponent(id, isDirectory: true)
            try fm.createDirectory(at: remoteDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: live.path) {
                _ = try fm.replaceItemAt(live, withItemAt: staging)
            } else {
                try fm.moveItem(at: staging, to: live)
            }
            defaults.set(man.version, forKey: "webext-remote-version.\(id)")
            WebDiag.log("webext-remote-updated", ["id": id, "version": man.version])
        } catch {
            WebDiag.log("webext-remote-fetch-error", ["id": id, "error": "\(error)"])
        }
    }
}

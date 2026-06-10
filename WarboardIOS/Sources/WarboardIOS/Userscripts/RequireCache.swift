import Foundation

/// Content-addressed on-disk cache for `@require` library bodies.
/// One file per `@require` URL, named `sha256(url).js` under `root`.
/// Pure Foundation — no WebKit — so it unit-tests headlessly.
struct RequireCache {
    let root: URL

    /// `root` is where cached `.js` files live. Defaults to
    /// Application Support/Userscripts/requires (created lazily on first store).
    init(root: URL) {
        self.root = root
    }

    static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Userscripts", isDirectory: true)
            .appendingPathComponent("requires", isDirectory: true)
    }

    /// Stable cache key for a `@require` URL = lowercase hex SHA-256 of the URL string.
    func key(forURL url: String) -> String {
        SHA256Pure.hexDigest(url)
    }

    /// On-disk location for a URL's cached body.
    func path(forURL url: String) -> URL {
        root.appendingPathComponent(key(forURL: url) + ".js", isDirectory: false)
    }

    func isCached(forURL url: String) -> Bool {
        FileManager.default.fileExists(atPath: path(forURL: url).path)
    }

    /// Cached JS body for a URL, or nil on a miss / unreadable file.
    func read(forURL url: String) -> String? {
        let p = path(forURL: url)
        guard let data = try? Data(contentsOf: p) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Persist a library body, creating `root` if needed. Atomic write.
    func store(_ body: String, forURL url: String) throws {
        try FileManager.default.createDirectory(at: root,
                                                withIntermediateDirectories: true)
        try Data(body.utf8).write(to: path(forURL: url), options: .atomic)
    }

    /// Drop a single entry (used on script update / cleanup). No-op if absent.
    func remove(forURL url: String) throws {
        let p = path(forURL: url)
        if FileManager.default.fileExists(atPath: p.path) {
            try FileManager.default.removeItem(at: p)
        }
    }
}

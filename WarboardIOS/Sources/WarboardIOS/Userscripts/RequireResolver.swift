import Foundation

/// Resolves a userscript's `@require` libraries: on install/update, fetch
/// each URL and write it to the `RequireCache`; injection then reads the
/// cached bodies. A failed fetch throws `RequireError`, which the installer
/// uses to block enabling the script (spec §3 / error handling).
struct RequireResolver {

    /// Async fetch seam — returns the library's text body or throws.
    /// Production wires this to URLSession; tests stub it.
    typealias Fetch = @Sendable (_ url: String) async throws -> String

    /// A `@require` that could not be made available. Carries the URL so the
    /// UI can show "couldn't load <url>" with a retry, and an underlying cause.
    struct RequireError: Error, Equatable {
        let url: String
        let reason: String
    }

    let cache: RequireCache
    private let fetch: Fetch

    init(cache: RequireCache, fetch: @escaping Fetch) {
        self.cache = cache
        self.fetch = fetch
    }

    /// Fetch + cache every `@require` for `script`. Cached entries are reused
    /// unless `forceRefetch` (set on script update). Throws `RequireError` on
    /// the first URL that fails — caller must NOT enable the script.
    func resolve(_ script: Userscript, forceRefetch: Bool = false) async throws {
        for url in script.requires {
            if !forceRefetch, cache.isCached(forURL: url) { continue }
            let body: String
            do {
                body = try await fetch(url)
            } catch let error as RequireError {
                throw error
            } catch {
                throw RequireError(url: url, reason: "\(error)")
            }
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RequireError(url: url, reason: "empty response")
            }
            do {
                try cache.store(body, forURL: url)
            } catch {
                throw RequireError(url: url, reason: "cache write failed: \(error)")
            }
        }
    }

    /// Cached lib bodies in `@require` order. Skips misses (best-effort) — use
    /// `injectionSourcesStrict` when a miss should abort injection.
    func injectionSources(for script: Userscript) -> [String] {
        script.requires.compactMap { cache.read(forURL: $0) }
    }

    /// Like `injectionSources` but throws `RequireError` on any miss, so the
    /// injection pipeline never runs a script body without its libraries.
    func injectionSourcesStrict(for script: Userscript) throws -> [String] {
        try script.requires.map { url in
            guard let body = cache.read(forURL: url) else {
                throw RequireError(url: url, reason: "not cached")
            }
            return body
        }
    }
}

#if canImport(Darwin)
extension RequireResolver {
    /// Default resolver backed by URLSession. `@require` libs are plain GETs.
    /// Makes a real network call, so it is NOT exercised by `swift test`;
    /// verified by the live factionops/socket.io smoke on a Mac. Apple-only —
    /// the headless Linux test build uses stubbed fetches and never links it.
    static func live(cache: RequireCache,
                     session: URLSession = .shared) -> RequireResolver {
        RequireResolver(cache: cache) { urlString in
            guard let url = URL(string: urlString) else {
                throw RequireError(url: urlString, reason: "invalid URL")
            }
            var request = URLRequest(url: url)
            request.setValue("warboard-ios", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw RequireError(url: urlString, reason: "HTTP \(http.statusCode)")
            }
            return String(decoding: data, as: UTF8.self)
        }
    }
}
#endif

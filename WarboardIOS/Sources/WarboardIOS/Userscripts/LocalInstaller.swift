import Foundation

struct LocalInstaller {
    enum InstallError: Error, Equatable {
        case noMatch
        case parse(String)
    }

    let registry: ScriptRegistry
    let resolver: RequireResolver

    init(registry: ScriptRegistry = ScriptRegistry.shared,
         requireCache: RequireCache = RequireCache(root: RequireCache.defaultRoot()),
         session: URLSession = .shared) {
        self.registry = registry
        self.resolver = RequireResolver.live(cache: requireCache, session: session)
    }

    /// Test seam: inject a resolver with a stub fetch.
    init(registry: ScriptRegistry, resolver: RequireResolver) {
        self.registry = registry
        self.resolver = resolver
    }

    @discardableResult
    func install(filename: String, content: String, downloadURL: String) async throws -> Userscript {
        let meta: ScriptMetadata
        do { meta = try MetadataParser.parse(content) }
        catch { throw InstallError.parse(String(describing: error)) }
        guard !(meta.matches.isEmpty && meta.includes.isEmpty) else { throw InstallError.noMatch }

        var script = ScriptFactory.make(from: meta, source: content, downloadURL: downloadURL)
        try await resolver.resolve(script)
        if let existing = findInstalled(meta: meta, downloadURL: downloadURL) {
            script.id = existing.id
            script.enabled = existing.enabled
            script.order = existing.order
            script.wildcardConnectGranted = existing.wildcardConnectGranted
        }
        try registry.upsert(script)
        return script
    }

    private func findInstalled(meta: ScriptMetadata, downloadURL: String) -> Userscript? {
        let installed = registry.all()
        if let name = meta.name,
           let hit = installed.first(where: { $0.name == name && $0.namespace == meta.namespace }) {
            return hit
        }
        let dl = meta.downloadURL ?? downloadURL
        return installed.first { $0.downloadURL == dl || $0.downloadURL == downloadURL }
    }
}

import XCTest
@testable import WarboardIOS

final class RequireResolverTests: XCTestCase {

    // A Userscript with the two @require URLs factionops uses.
    private func script(requires: [String]) -> Userscript {
        Userscript(
            id: "test-\(UUID().uuidString)",
            name: "Test", namespace: "ns", version: "1.0.0", description: "",
            matches: ["https://www.torn.com/*"], includes: [], excludes: [],
            requires: requires, connects: [], grants: [],
            runAt: .documentIdle, icon: nil, downloadURL: nil, updateURL: nil,
            enabled: false, order: 0, source: "// body", wildcardConnectGranted: false)
    }

    private func makeTempCache() throws -> RequireCache {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RequireResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return RequireCache(root: dir)
    }

    func testResolveFetchesEachRequireAndWritesToCache() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        let recorder = Recorder()
        let resolver = RequireResolver(cache: cache) { url in
            await recorder.append(url)
            return "/* body of \(url) */"
        }
        let s = script(requires: [
            "https://cdn/socket.io.js",
            "https://cdn/pako.js"])

        try await resolver.resolve(s)

        let requested = await recorder.values
        XCTAssertEqual(requested, ["https://cdn/socket.io.js", "https://cdn/pako.js"])
        XCTAssertEqual(cache.read(forURL: "https://cdn/socket.io.js"), "/* body of https://cdn/socket.io.js */")
        XCTAssertEqual(cache.read(forURL: "https://cdn/pako.js"), "/* body of https://cdn/pako.js */")
    }

    func testResolveSkipsAlreadyCachedURLs() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        try cache.store("cached", forURL: "https://cdn/socket.io.js")
        let recorder = Recorder()
        let resolver = RequireResolver(cache: cache) { url in
            await recorder.append(url); return "fresh"
        }
        try await resolver.resolve(script(requires: ["https://cdn/socket.io.js"]))
        // Already cached → not re-fetched, body preserved.
        let fetched = await recorder.values
        XCTAssertEqual(fetched, [])
        XCTAssertEqual(cache.read(forURL: "https://cdn/socket.io.js"), "cached")
    }

    func testForceRefetchOverwritesCacheOnUpdate() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        try cache.store("old", forURL: "https://cdn/lib.js")
        let resolver = RequireResolver(cache: cache) { _ in "new" }
        try await resolver.resolve(script(requires: ["https://cdn/lib.js"]),
                                   forceRefetch: true)
        XCTAssertEqual(cache.read(forURL: "https://cdn/lib.js"), "new")
    }

    func testFetchFailureThrowsRequireErrorAndBlocksEnable() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        struct Boom: Error {}
        let resolver = RequireResolver(cache: cache) { url in
            if url.contains("pako") { throw Boom() }
            return "ok"
        }
        let s = script(requires: ["https://cdn/socket.io.js", "https://cdn/pako.js"])

        do {
            try await resolver.resolve(s)
            XCTFail("expected resolve to throw")
        } catch let err as RequireResolver.RequireError {
            XCTAssertEqual(err.url, "https://cdn/pako.js")
        }
        // The good one may be cached, but the failing one must NOT be.
        XCTAssertFalse(cache.isCached(forURL: "https://cdn/pako.js"))
    }

    func testEmptyContentIsTreatedAsFailure() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        let resolver = RequireResolver(cache: cache) { _ in "   \n  " }
        do {
            try await resolver.resolve(script(requires: ["https://cdn/lib.js"]))
            XCTFail("expected empty body to throw")
        } catch let err as RequireResolver.RequireError {
            XCTAssertEqual(err.url, "https://cdn/lib.js")
        }
    }

    func testInjectionSourcesReturnsCachedBodiesInOrder() async throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        let resolver = RequireResolver(cache: cache) { url in "/* \(url) */" }
        let s = script(requires: ["https://cdn/a.js", "https://cdn/b.js"])
        try await resolver.resolve(s)
        XCTAssertEqual(resolver.injectionSources(for: s),
                       ["/* https://cdn/a.js */", "/* https://cdn/b.js */"])
    }

    func testInjectionSourcesThrowsIfRequireMissing() throws {
        let cache = try makeTempCache()
        defer { try? FileManager.default.removeItem(at: cache.root) }
        let resolver = RequireResolver(cache: cache) { _ in "x" }
        // Never resolved → cache miss → must surface (don't silently inject a script
        // without its lib).
        XCTAssertThrowsError(
            try resolver.injectionSourcesStrict(for: script(requires: ["https://cdn/missing.js"]))
        ) { error in
            guard let err = error as? RequireResolver.RequireError else {
                return XCTFail("wrong error type")
            }
            XCTAssertEqual(err.url, "https://cdn/missing.js")
        }
    }
}

/// Thread-safe ordered recorder for the async fetch stub. Avoids data-race
/// warnings from mutating a captured `var` inside the `@Sendable` closure.
private actor Recorder {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

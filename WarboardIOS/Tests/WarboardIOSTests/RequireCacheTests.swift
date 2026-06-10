import XCTest
@testable import WarboardIOS

final class RequireCacheTests: XCTestCase {

    // MARK: SHA-256 correctness (NIST/`sha256sum` vectors)

    func testSHA256KnownVectors() {
        XCTAssertEqual(
            SHA256Pure.hexDigest(Array("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(
            SHA256Pure.hexDigest([]),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(
            SHA256Pure.hexDigest(Array("https://cdnjs.cloudflare.com/socket.io.js".utf8)),
            "683ffc5f61dac222d780dd31d44ab20315c1e165b88f24297ca9bd79221a3240")
    }

    func testSHA256MultiBlockInput() {
        // 100-byte input crosses the 64-byte SHA block boundary; matches
        // `python3 -c "import hashlib; print(hashlib.sha256(b'a'*100).hexdigest())"`.
        let digest = SHA256Pure.hexDigest(Array(repeating: UInt8(ascii: "a"), count: 100))
        XCTAssertEqual(
            digest,
            "2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e")
    }

    // MARK: cache-key stability

    func testCacheKeyIsSha256OfURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = RequireCache(root: dir)
        let url = "https://cdnjs.cloudflare.com/socket.io.js"
        XCTAssertEqual(cache.key(forURL: url),
                       "683ffc5f61dac222d780dd31d44ab20315c1e165b88f24297ca9bd79221a3240")
        // Stable across calls and instances.
        XCTAssertEqual(RequireCache(root: dir).key(forURL: url),
                       cache.key(forURL: url))
    }

    func testPathForURLLivesUnderRootAndIsKeyed() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = RequireCache(root: dir)
        let url = "https://example.com/lib.js"
        let path = cache.path(forURL: url)
        XCTAssertEqual(path.deletingLastPathComponent().standardizedFileURL,
                       dir.standardizedFileURL)
        XCTAssertEqual(path.lastPathComponent, cache.key(forURL: url) + ".js")
    }

    // MARK: store / read round-trip

    func testStoreThenReadRoundTrips() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = RequireCache(root: dir)
        let url = "https://example.com/socket.io.js"
        let body = "var io = function(){ return {}; };"

        XCTAssertNil(cache.read(forURL: url))   // miss before store
        XCTAssertFalse(cache.isCached(forURL: url))

        try cache.store(body, forURL: url)

        XCTAssertTrue(cache.isCached(forURL: url))
        XCTAssertEqual(cache.read(forURL: url), body)
    }

    func testStoreCreatesRootDirectoryIfMissing() throws {
        let parent = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: parent) }
        // Point the cache at a not-yet-existent subdirectory.
        let root = parent.appendingPathComponent("requires", isDirectory: true)
        let cache = RequireCache(root: root)
        try cache.store("x", forURL: "https://h/lib.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        XCTAssertEqual(cache.read(forURL: "https://h/lib.js"), "x")
    }

    func testRemoveDeletesEntry() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = RequireCache(root: dir)
        let url = "https://example.com/lib.js"
        try cache.store("body", forURL: url)
        XCTAssertTrue(cache.isCached(forURL: url))
        try cache.remove(forURL: url)
        XCTAssertFalse(cache.isCached(forURL: url))
        XCTAssertNil(cache.read(forURL: url))
    }

    // MARK: helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RequireCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

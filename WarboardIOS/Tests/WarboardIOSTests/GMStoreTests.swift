import XCTest
@testable import WarboardIOS

final class JSONValueTests: XCTestCase {
    func testDecodesEveryJSONShape() throws {
        let json = """
        { "s": "hi", "n": 42, "f": 3.5, "b": true, "z": null,
          "arr": [1, "two", false],
          "obj": { "k": "v" } }
        """.data(using: .utf8)!
        let v = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case let .object(d) = v else { return XCTFail("expected object") }
        XCTAssertEqual(d["s"], .string("hi"))
        XCTAssertEqual(d["b"], .bool(true))
        XCTAssertEqual(d["z"], .null)
        XCTAssertEqual(d["arr"], .array([.number(1), .string("two"), .bool(false)]))
        XCTAssertEqual(d["obj"], .object(["k": .string("v")]))
    }

    func testEncodeDecodeRoundTrips() throws {
        let original: JSONValue = .object([
            "name": .string("factionops"),
            "count": .number(7),
            "on": .bool(true),
            "tags": .array([.string("a"), .string("b")])
        ])
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, back)
    }

    func testBoolIsNotCoercedToNumber() throws {
        // JSONSerialization/Codable can confuse true→1; pin the distinction.
        let data = "true".data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), .bool(true))
        let n = "1".data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: n), .number(1))
    }
}

final class GMStoreTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gmstore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmpDir) }

    func testSetGetRoundTripsAndPersists() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "theme", value: .string("dark"))
        XCTAssertEqual(store.get(scriptId: "s1", key: "theme"), .string("dark"))

        // A fresh store over the same dir reloads the value.
        let reopened = GMStore(directory: tmpDir)
        XCTAssertEqual(reopened.get(scriptId: "s1", key: "theme"), .string("dark"))
    }

    func testScriptIdsAreIsolated() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "k", value: .number(1))
        try store.set(scriptId: "s2", key: "k", value: .number(2))
        XCTAssertEqual(store.get(scriptId: "s1", key: "k"), .number(1))
        XCTAssertEqual(store.get(scriptId: "s2", key: "k"), .number(2))
    }

    func testDeleteAndListValues() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "a", value: .string("x"))
        try store.set(scriptId: "s1", key: "b", value: .string("y"))
        XCTAssertEqual(store.listKeys(scriptId: "s1").sorted(), ["a", "b"])

        try store.delete(scriptId: "s1", key: "a")
        XCTAssertEqual(store.listKeys(scriptId: "s1"), ["b"])
        XCTAssertNil(store.get(scriptId: "s1", key: "a"))
    }

    func testSnapshotReturnsWholeDocument() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "a", value: .number(1))
        try store.set(scriptId: "s1", key: "b", value: .bool(false))

        let snap = store.snapshot(scriptId: "s1")
        XCTAssertEqual(snap, ["a": .number(1), "b": .bool(false)])
        // Empty for an unknown script id — bootstrap injects {}.
        XCTAssertEqual(store.snapshot(scriptId: "unknown"), [:])
    }

    func testSnapshotJSONStringIsValidObject() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "name", value: .string("ops"))
        let jsonString = try store.snapshotJSON(scriptId: "s1")
        // Round-trip through Foundation to confirm it's valid JSON the
        // bootstrap can `JSON.parse`.
        let obj = try JSONSerialization.jsonObject(
            with: jsonString.data(using: .utf8)!) as? [String: Any]
        XCTAssertEqual(obj?["name"] as? String, "ops")
    }
}

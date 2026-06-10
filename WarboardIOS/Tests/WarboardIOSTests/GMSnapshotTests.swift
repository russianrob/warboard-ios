import XCTest
@testable import WarboardIOS

final class GMSnapshotTests: XCTestCase {

    private func parse(_ s: String) -> [String: Any] {
        let data = s.data(using: .utf8)!
        return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    func testEmptySnapshotIsEmptyObject() {
        XCTAssertEqual(GMSnapshot.objectLiteral(from: [:]), "{}")
    }

    func testScalarValuesArePreservedAsRawJSON() {
        // Stored values are already JSON-encoded strings, per GMStore.
        let raw = ["count": "5", "ratio": "1.5", "on": "true", "nothing": "null"]
        let obj = parse(GMSnapshot.objectLiteral(from: raw))
        XCTAssertEqual(obj["count"] as? Int, 5)
        XCTAssertEqual(obj["ratio"] as? Double, 1.5)
        XCTAssertEqual(obj["on"] as? Bool, true)
        XCTAssertTrue(obj["nothing"] is NSNull)
    }

    func testStringValueRoundTrips() {
        // A GM string value "hi" is stored as the JSON string "\"hi\"".
        let raw = ["greeting": "\"hi\""]
        let obj = parse(GMSnapshot.objectLiteral(from: raw))
        XCTAssertEqual(obj["greeting"] as? String, "hi")
    }

    func testObjectValueRoundTrips() {
        let raw = ["cfg": "{\"a\":1,\"b\":[2,3]}"]
        let obj = parse(GMSnapshot.objectLiteral(from: raw))
        let cfg = obj["cfg"] as? [String: Any]
        XCTAssertEqual(cfg?["a"] as? Int, 1)
        let b = cfg?["b"] as? [Any]
        XCTAssertEqual(b?.count, 2)
    }

    func testKeysWithQuotesAndUnicodeAreEscaped() {
        let raw = ["wei\"rd": "1", "ключ": "2"]
        let s = GMSnapshot.objectLiteral(from: raw)
        // Must be valid JSON that re-parses to the same keys.
        let obj = parse(s)
        XCTAssertEqual(obj["wei\"rd"] as? Int, 1)
        XCTAssertEqual(obj["ключ"] as? Int, 2)
    }

    func testCorruptStoredValueFallsBackToJSONNull() {
        // If a stored value isn't valid JSON, emit null rather than break the literal.
        let raw = ["bad": "not json {{"]
        let obj = parse(GMSnapshot.objectLiteral(from: raw))
        XCTAssertTrue(obj["bad"] is NSNull)
    }

    func testDeterministicKeyOrdering() {
        let raw = ["b": "1", "a": "2", "c": "3"]
        // Sorted keys → stable output (snapshot diffs / test stability).
        XCTAssertEqual(GMSnapshot.objectLiteral(from: raw),
                       "{\"a\":2,\"b\":1,\"c\":3}")
    }
}

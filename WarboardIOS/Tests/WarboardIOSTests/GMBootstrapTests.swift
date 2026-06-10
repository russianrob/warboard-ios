import XCTest
@testable import WarboardIOS

final class GMBootstrapTests: XCTestCase {

    // MARK: body (the embedded gm-bootstrap.js)

    func testBootstrapBodyIsLoadedAndNonEmpty() {
        XCTAssertFalse(GMBootstrap.body.isEmpty,
                       "gm-bootstrap.js must be bundled and loadable")
    }

    func testBootstrapBodyDefinesTheGMSurface() {
        let body = GMBootstrap.body
        // Spot-check that the real bootstrap (not a fallback stub) is present.
        for symbol in ["GM_getValue", "GM_setValue", "GM_xmlhttpRequest",
                       "unsafeWindow", "__WB_SCRIPT_CONTEXT__", "gmBridge"] {
            XCTAssertTrue(body.contains(symbol),
                          "bootstrap should reference \(symbol)")
        }
    }

    // MARK: jsString (JS string-literal escaping)

    func testJSStringWrapsInQuotes() {
        XCTAssertEqual(GMBootstrap.jsString("abc"), "\"abc\"")
    }

    func testJSStringEscapesQuotesBackslashesAndControls() {
        XCTAssertEqual(GMBootstrap.jsString("a\"b"), "\"a\\\"b\"")
        XCTAssertEqual(GMBootstrap.jsString("a\\b"), "\"a\\\\b\"")
        XCTAssertEqual(GMBootstrap.jsString("a\nb"), "\"a\\nb\"")
    }

    func testJSStringEmpty() {
        XCTAssertEqual(GMBootstrap.jsString(""), "\"\"")
    }

    // MARK: source composition

    func testSourcePrependsContextThenBody() {
        let src = GMBootstrap.source(scriptID: "abc",
                                     infoJSON: "{}",
                                     snapshotLiteral: "{}")
        XCTAssertTrue(src.hasPrefix("var __WB_SCRIPT_CONTEXT__ = {"),
                      "source must begin with the context var declaration")
        XCTAssertTrue(src.hasSuffix(GMBootstrap.body),
                      "the bootstrap body must be appended verbatim after the context")
    }

    func testSourceEmbedsScriptIDInfoAndStore() {
        let src = GMBootstrap.source(scriptID: "script-7",
                                     infoJSON: "{\"version\":\"1.0\"}",
                                     snapshotLiteral: "{\"a\":1}")
        XCTAssertTrue(src.contains("\"scriptId\":\"script-7\""))
        XCTAssertTrue(src.contains("\"info\":{\"version\":\"1.0\"}"))
        XCTAssertTrue(src.contains("\"store\":{\"a\":1}"))
    }

    func testSourceEscapesScriptIDWithQuotes() {
        let src = GMBootstrap.source(scriptID: "we\"ird",
                                     infoJSON: "{}",
                                     snapshotLiteral: "{}")
        XCTAssertTrue(src.contains("\"scriptId\":\"we\\\"ird\""),
                      "a script id with a quote must be JS-escaped")
    }

    // MARK: end-to-end — the composed context prefix is valid, parseable JSON

    func testComposedContextLiteralIsValidJSON() throws {
        let snapshot = GMSnapshot.objectLiteral(from: ["count": "5", "name": "\"bob\""])
        let src = GMBootstrap.source(scriptID: "id\"x",
                                     infoJSON: "{\"name\":\"factionops\"}",
                                     snapshotLiteral: snapshot)
        // Extract the JSON object literal between `= ` and the trailing `;`.
        guard let eq = src.range(of: "var __WB_SCRIPT_CONTEXT__ = "),
              let semi = src.range(of: ";\n", range: eq.upperBound..<src.endIndex) else {
            return XCTFail("could not locate the context literal")
        }
        let literal = String(src[eq.upperBound..<semi.lowerBound])
        let data = literal.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["scriptId"] as? String, "id\"x")
        let info = obj["info"] as? [String: Any]
        XCTAssertEqual(info?["name"] as? String, "factionops")
        let store = obj["store"] as? [String: Any]
        XCTAssertEqual(store?["count"] as? Int, 5)
        XCTAssertEqual(store?["name"] as? String, "bob")
    }
}

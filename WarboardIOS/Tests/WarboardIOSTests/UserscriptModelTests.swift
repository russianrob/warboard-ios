import XCTest
@testable import WarboardIOS

final class UserscriptModelTests: XCTestCase {
    func testRunAtDecodesTampermonkeyTokens() throws {
        XCTAssertEqual(RunAt(token: "document-start"), .documentStart)
        XCTAssertEqual(RunAt(token: "document-end"), .documentEnd)
        XCTAssertEqual(RunAt(token: "document-idle"), .documentIdle)
        XCTAssertEqual(RunAt(token: "bogus"), .documentIdle)
        XCTAssertEqual(RunAt(token: nil), .documentIdle)
    }

    func testRunAtRoundTripsItsRawToken() throws {
        for value in [RunAt.documentStart, .documentEnd, .documentIdle] {
            XCTAssertEqual(RunAt(token: value.token), value)
        }
    }

    func testUserscriptCodableRoundTrip() throws {
        let script = Userscript(
            id: "11111111-1111-1111-1111-111111111111",
            name: "factionops",
            namespace: "RussianRob",
            version: "1.2.6",
            description: "war overlay",
            matches: ["https://*.torn.com/factions.php*"],
            includes: ["*://www.torn.com/loader.php*"],
            excludes: ["https://www.torn.com/logout*"],
            requires: ["https://cdn.socket.io/4.7.5/socket.io.min.js"],
            connects: ["tornwar.com", "*"],
            grants: ["GM_getValue", "GM_setValue", "unsafeWindow"],
            runAt: .documentIdle,
            icon: "https://www.torn.com/favicon.ico",
            downloadURL: "https://greasyfork.org/scripts/1/factionops.user.js",
            updateURL: "https://greasyfork.org/scripts/1/factionops.meta.js",
            enabled: true,
            order: 3,
            source: "// ==UserScript==\n// @name factionops\n// ==/UserScript==\n",
            wildcardConnectGranted: true
        )
        let data = try JSONEncoder().encode(script)
        let decoded = try JSONDecoder().decode(Userscript.self, from: data)
        XCTAssertEqual(decoded, script)
    }
}

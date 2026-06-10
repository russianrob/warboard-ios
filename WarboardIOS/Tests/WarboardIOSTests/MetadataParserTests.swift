import XCTest
@testable import WarboardIOS

final class MetadataParserTests: XCTestCase {

    private let factionops = """
    // ==UserScript==
    // @name         factionops
    // @namespace    RussianRob
    // @version      1.2.6
    // @description  war overlay
    // @match        https://*.torn.com/factions.php*
    // @match        https://www.torn.com/loader.php?sid=*
    // @include      *://www.torn.com/profiles.php*
    // @exclude      https://www.torn.com/logout*
    // @require      https://cdn.socket.io/4.7.5/socket.io.min.js
    // @require      https://example.com/lib.js
    // @connect      tornwar.com
    // @connect      api.torn.com
    // @connect      *
    // @grant        GM_getValue
    // @grant        GM_setValue
    // @grant        unsafeWindow
    // @run-at       document-end
    // @icon         https://www.torn.com/favicon.ico
    // @downloadURL  https://greasyfork.org/scripts/1/factionops.user.js
    // @updateURL    https://greasyfork.org/scripts/1/factionops.meta.js
    // ==/UserScript==
    (function(){ console.log("body"); })();
    """

    func testParsesAllRepeatedKeysIntoArrays() throws {
        let m = try MetadataParser.parse(factionops)
        XCTAssertEqual(m.name, "factionops")
        XCTAssertEqual(m.namespace, "RussianRob")
        XCTAssertEqual(m.version, "1.2.6")
        XCTAssertEqual(m.description, "war overlay")
        XCTAssertEqual(m.matches, [
            "https://*.torn.com/factions.php*",
            "https://www.torn.com/loader.php?sid=*",
        ])
        XCTAssertEqual(m.includes, ["*://www.torn.com/profiles.php*"])
        XCTAssertEqual(m.excludes, ["https://www.torn.com/logout*"])
        XCTAssertEqual(m.requires, [
            "https://cdn.socket.io/4.7.5/socket.io.min.js",
            "https://example.com/lib.js",
        ])
        XCTAssertEqual(m.connects, ["tornwar.com", "api.torn.com", "*"])
        XCTAssertEqual(m.grants, ["GM_getValue", "GM_setValue", "unsafeWindow"])
        XCTAssertEqual(m.runAt, .documentEnd)
        XCTAssertEqual(m.icon, "https://www.torn.com/favicon.ico")
        XCTAssertEqual(m.downloadURL, "https://greasyfork.org/scripts/1/factionops.user.js")
        XCTAssertEqual(m.updateURL, "https://greasyfork.org/scripts/1/factionops.meta.js")
    }

    func testRunAtDefaultsToDocumentIdleWhenAbsent() throws {
        let src = """
        // ==UserScript==
        // @name minimal
        // @match https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.runAt, .documentIdle)
    }

    func testValueMayContainSpacesAndIsTrimmed() throws {
        let src = """
        // ==UserScript==
        // @name   a script   with   spaces
        // @match  https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.name, "a script   with   spaces")
    }

    func testKeyWithNoValueIsIgnored() throws {
        let src = """
        // ==UserScript==
        // @name nogrant
        // @match https://www.torn.com/*
        // @grant
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.grants, [])
    }

    func testLeadingBlankAndCodeLinesBeforeBlockAreSkipped() throws {
        let src = """

        const x = 1; // not metadata
        // ==UserScript==
        // @name late
        // @match https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.name, "late")
    }

    func testThrowsWhenNoOpeningMarker() throws {
        let src = "// @name orphan\n// @match https://www.torn.com/*\n"
        XCTAssertThrowsError(try MetadataParser.parse(src)) { err in
            XCTAssertEqual(err as? MetadataParseError, .missingBlock)
        }
    }

    func testThrowsWhenNoClosingMarker() throws {
        let src = """
        // ==UserScript==
        // @name unterminated
        // @match https://www.torn.com/*
        """
        XCTAssertThrowsError(try MetadataParser.parse(src)) { err in
            XCTAssertEqual(err as? MetadataParseError, .unterminatedBlock)
        }
    }
}

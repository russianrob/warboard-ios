import XCTest
@testable import WarboardIOS

final class MatchMatcherIncludeExcludeTests: XCTestCase {

    func testIncludeGlobMatchesWholeURL() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "*://www.torn.com/profiles.php*",
            url: "https://www.torn.com/profiles.php?XID=1"))
        XCTAssertFalse(MatchMatcher.matchesIncludePattern(
            pattern: "*://www.torn.com/profiles.php*",
            url: "https://www.torn.com/factions.php"))
    }

    func testIncludeBareStarMatchesEverything() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(pattern: "*",
            url: "https://anything.example/x?y=1#z"))
    }

    func testIncludeRegexLiteral() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "/^https:\\/\\/www\\.torn\\.com\\/factions\\.php/",
            url: "https://www.torn.com/factions.php?step=your"))
        XCTAssertFalse(MatchMatcher.matchesIncludePattern(
            pattern: "/^https:\\/\\/www\\.torn\\.com\\/factions\\.php/",
            url: "https://www.torn.com/profiles.php"))
    }

    func testIncludeRegexIsUnanchoredSubstring() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "/loader\\.php/",
            url: "https://www.torn.com/loader.php?sid=attack"))
    }

    func testExcludeBeatsMatch() {
        let script = makeScript(
            matches: ["https://*.torn.com/*"],
            includes: [],
            excludes: ["https://www.torn.com/logout*"])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/factions.php", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/logout.php", script: script))
    }

    func testExcludeBeatsInclude() {
        let script = makeScript(
            matches: [],
            includes: ["*://www.torn.com/*"],
            excludes: ["/admin/"])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/index.php", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/admin/panel", script: script))
    }

    func testMatchOrIncludeUnion() {
        let script = makeScript(
            matches: ["https://www.torn.com/factions.php*"],
            includes: ["*://www.torn.com/profiles.php*"],
            excludes: [])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/factions.php", script: script))
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/profiles.php?XID=1", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/items.php", script: script))
    }

    func testNoMatchOrIncludeNeverRuns() {
        let script = makeScript(matches: [], includes: [], excludes: [])
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/x", script: script))
    }

    private func makeScript(matches: [String], includes: [String], excludes: [String]) -> Userscript {
        Userscript(
            id: "00000000-0000-0000-0000-000000000000",
            name: "t", namespace: nil, version: nil, description: nil,
            matches: matches, includes: includes, excludes: excludes,
            requires: [], connects: [], grants: [], runAt: .documentIdle,
            icon: nil, downloadURL: nil, updateURL: nil,
            enabled: true, order: 0, source: "", wildcardConnectGranted: false)
    }
}

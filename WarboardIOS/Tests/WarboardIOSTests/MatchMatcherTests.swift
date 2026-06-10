import XCTest
@testable import WarboardIOS

final class MatchMatcherTests: XCTestCase {

    private func matches(_ pattern: String, _ url: String) -> Bool {
        MatchMatcher.matchesMatchPattern(pattern: pattern, url: url)
    }

    func testHostWildcardSubdomain() {
        XCTAssertTrue(matches("https://*.torn.com/*", "https://www.torn.com/factions.php"))
        XCTAssertTrue(matches("https://*.torn.com/*", "https://torn.com/factions.php"))
        XCTAssertTrue(matches("https://*.torn.com/*", "https://api.torn.com/v2/user"))
        XCTAssertFalse(matches("https://*.torn.com/*", "https://eviltorn.com/x"))
        XCTAssertFalse(matches("https://*.torn.com/*", "https://torn.com.evil.com/x"))
    }

    func testSchemeWildcardMatchesHttpAndHttps() {
        XCTAssertTrue(matches("*://www.torn.com/*", "http://www.torn.com/x"))
        XCTAssertTrue(matches("*://www.torn.com/*", "https://www.torn.com/x"))
        XCTAssertFalse(matches("*://www.torn.com/*", "ftp://www.torn.com/x"))
    }

    func testExactSchemeIsHonored() {
        XCTAssertFalse(matches("https://www.torn.com/*", "http://www.torn.com/x"))
        XCTAssertTrue(matches("http://www.torn.com/*", "http://www.torn.com/x"))
    }

    func testPathGlobAndQueryString() {
        XCTAssertTrue(matches("https://www.torn.com/factions.php*",
                              "https://www.torn.com/factions.php?step=your"))
        XCTAssertTrue(matches("https://www.torn.com/factions.php*",
                              "https://www.torn.com/factions.php"))
        XCTAssertFalse(matches("https://www.torn.com/factions.php*",
                               "https://www.torn.com/profiles.php"))
    }

    func testPathStarMatchesEmptyPath() {
        XCTAssertTrue(matches("https://www.torn.com/*", "https://www.torn.com/"))
        XCTAssertTrue(matches("https://www.torn.com/*", "https://www.torn.com"))
    }

    func testHostIsAnchoredNotSubstring() {
        XCTAssertFalse(matches("https://www.torn.com/*", "https://www.torn.com.evil.com/x"))
        XCTAssertFalse(matches("https://www.torn.com/*", "https://evil.www.torn.com/x"))
    }

    func testPathWildcardInMiddle() {
        XCTAssertTrue(matches("https://www.torn.com/loader.php?sid=*",
                              "https://www.torn.com/loader.php?sid=attack&user2ID=1"))
        XCTAssertFalse(matches("https://www.torn.com/loader.php?sid=*",
                               "https://www.torn.com/loader.php?mode=x"))
    }

    func testSpecialRegexCharsInPathAreEscaped() {
        XCTAssertTrue(matches("https://www.torn.com/a.b.php",
                              "https://www.torn.com/a.b.php"))
        XCTAssertFalse(matches("https://www.torn.com/a.b.php",
                               "https://www.torn.com/aXbYphp"))
    }

    func testMalformedPatternNeverMatches() {
        XCTAssertFalse(matches("not-a-valid-pattern", "https://www.torn.com/x"))
        XCTAssertFalse(matches("https://www.torn.com", "https://www.torn.com/x"))
    }
}

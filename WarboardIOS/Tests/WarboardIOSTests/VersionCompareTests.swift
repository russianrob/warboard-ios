import XCTest
@testable import WarboardIOS

final class VersionCompareTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertEqual(VersionCompare.compare("1.2.3", "1.2.4"), .orderedAscending)
        XCTAssertEqual(VersionCompare.compare("1.2.4", "1.2.3"), .orderedDescending)
    }

    func testEqual() {
        XCTAssertEqual(VersionCompare.compare("2.0.0", "2.0.0"), .orderedSame)
    }

    func testDifferentComponentCounts() {
        // "1.2" == "1.2.0"; "1.2.1" > "1.2"
        XCTAssertEqual(VersionCompare.compare("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(VersionCompare.compare("1.2.1", "1.2"), .orderedDescending)
    }

    func testNumericNotLexical() {
        // The bug the user hit with -wbN suffixes: 10 must beat 9.
        XCTAssertEqual(VersionCompare.compare("1.2.9", "1.2.10"), .orderedAscending)
    }

    func testIsUpdateAvailable() {
        XCTAssertTrue(VersionCompare.isUpdate(installed: "1.2.3", remote: "1.2.4"))
        XCTAssertFalse(VersionCompare.isUpdate(installed: "1.2.4", remote: "1.2.4"))
        XCTAssertFalse(VersionCompare.isUpdate(installed: "1.2.5", remote: "1.2.4"))
    }

    func testNonNumericTiebreak() {
        // A pure-numeric component always outranks a missing one
        // (missing is treated as "0", and 0 < anything-positive numeric).
        XCTAssertEqual(VersionCompare.compare("1.0.0", "1.0"), .orderedSame)
        XCTAssertEqual(VersionCompare.compare("1.0.1", "1.0"), .orderedDescending)
    }
}

import XCTest
@testable import WarboardIOS

final class _HarnessSmokeTests: XCTestCase {
    func testHarnessCompilesAndRuns() {
        XCTAssertTrue(_HarnessSmoke.ready)
    }
}

import XCTest
@testable import WarboardIOS

final class ExtUpdateDecisionTests: XCTestCase {
    func test_offersStrictlyNewerVersion() {
        XCTAssertEqual(
            ExtUpdateDecision.versionToOffer(active: "9.0.6", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"),
            "9.0.6.1")
    }
    func test_noUpdateWhenEqual() {
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.6.1", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"))
    }
    func test_noUpdateWhenRemoteOlder() {
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.7", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"))
    }
    func test_refusesWhenSeedNewerThanMinSeed() {
        // Server build's floor is 9.0.6 but our bundled seed is 9.1.0 (newer) →
        // don't shadow the newer seed with an older server copy.
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.5", remote: "9.0.6", seed: "9.1.0", minSeed: "9.0.6"))
    }
    func test_nilMinSeedSkipsFloor() {
        XCTAssertEqual(
            ExtUpdateDecision.versionToOffer(active: "9.0.6", remote: "9.0.6.1", seed: "9.0.6", minSeed: nil),
            "9.0.6.1")
    }
}

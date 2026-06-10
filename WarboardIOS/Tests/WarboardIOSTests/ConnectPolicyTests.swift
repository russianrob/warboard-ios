import XCTest
@testable import WarboardIOS

final class ConnectPolicyTests: XCTestCase {

    // Tampermonkey @connect matches a host if the connect entry equals the
    // host OR is a domain suffix of it (e.g. "torn.com" allows "api.torn.com").
    func testExactAndSuffixMatch() {
        let policy = ConnectPolicy(connects: ["api.tornwar.com", "ffscouter.com"])
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://api.tornwar.com/v1/x")!),
                       .allowed)
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://ffscouter.com/a")!),
                       .allowed)
        // suffix: connect "ffscouter.com" also covers "www.ffscouter.com"
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://www.ffscouter.com/a")!),
                       .allowed)
    }

    func testSuffixDoesNotMatchUnrelatedHost() {
        let policy = ConnectPolicy(connects: ["torn.com"])
        // "eviltorn.com" is NOT a subdomain of "torn.com"
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://eviltorn.com/x")!),
                       .blocked)
    }

    func testTornAlwaysAllowedEvenWithoutConnect() {
        let policy = ConnectPolicy(connects: [])
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://www.torn.com/api")!),
                       .allowed)
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://api.torn.com/v2/x")!),
                       .allowed)
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://torn.com/")!),
                       .allowed)
    }

    func testWildcardNeedsConsentThenAllows() {
        let ungranted = ConnectPolicy(connects: ["*"], wildcardConnectGranted: false)
        XCTAssertEqual(ungranted.decision(forURL: URL(string: "https://anything.example/x")!),
                       .needsWildcardConsent)
        let granted = ConnectPolicy(connects: ["*"], wildcardConnectGranted: true)
        XCTAssertEqual(granted.decision(forURL: URL(string: "https://anything.example/x")!),
                       .allowed)
    }

    func testHostlessOrNonHTTPURLBlocked() {
        let policy = ConnectPolicy(connects: ["*"], wildcardConnectGranted: true)
        // file:// and data: have no usable host for an allowlist decision
        XCTAssertEqual(policy.decision(forURL: URL(string: "data:text/plain,hi")!),
                       .blocked)
    }

    func testCaseInsensitiveHost() {
        let policy = ConnectPolicy(connects: ["FFScouter.com"])
        XCTAssertEqual(policy.decision(forURL: URL(string: "https://FFSCOUTER.COM/a")!),
                       .allowed)
    }
}

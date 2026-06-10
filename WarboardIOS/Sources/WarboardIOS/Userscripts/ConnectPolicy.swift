import Foundation

struct ConnectPolicy {
    enum Decision: Equatable {
        case allowed
        case blocked
        case needsWildcardConsent
    }

    let connects: [String]
    let wildcardConnectGranted: Bool

    init(connects: [String], wildcardConnectGranted: Bool = false) {
        self.connects = connects
        self.wildcardConnectGranted = wildcardConnectGranted
    }

    func decision(forURL url: URL) -> Decision {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty else {
            return .blocked
        }

        if Self.hostMatches(host, suffix: "torn.com") {
            return .allowed
        }

        let entries = connects.map { $0.lowercased() }

        for entry in entries where entry != "*" {
            if Self.hostMatches(host, suffix: entry) {
                return .allowed
            }
        }

        if entries.contains("*") {
            return wildcardConnectGranted ? .allowed : .needsWildcardConsent
        }

        return .blocked
    }

    private static func hostMatches(_ host: String, suffix: String) -> Bool {
        if host == suffix { return true }
        return host.hasSuffix("." + suffix)
    }
}

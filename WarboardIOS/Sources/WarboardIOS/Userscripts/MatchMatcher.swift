import Foundation

enum MatchMatcher {

    static func matchesMatchPattern(pattern: String, url: String) -> Bool {
        guard let p = parseMatchPattern(pattern),
              let u = URLParts(url)
        else { return false }

        if p.scheme == "*" {
            if u.scheme != "http" && u.scheme != "https" { return false }
        } else if p.scheme != u.scheme {
            return false
        }

        if p.host == "*" {
        } else if p.host.hasPrefix("*.") {
            let suffix = String(p.host.dropFirst(2))
            if u.host != suffix && !u.host.hasSuffix("." + suffix) { return false }
        } else if p.host != u.host {
            return false
        }

        let target = u.path + (u.query.map { "?" + $0 } ?? "")
        return wildcardMatches(glob: p.path, text: target)
    }

    private struct MatchPattern { let scheme: String; let host: String; let path: String }

    private static func parseMatchPattern(_ pattern: String) -> MatchPattern? {
        guard let schemeRange = pattern.range(of: "://") else { return nil }
        let scheme = String(pattern[pattern.startIndex..<schemeRange.lowerBound]).lowercased()
        let rest = pattern[schemeRange.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let host = String(rest[rest.startIndex..<slash]).lowercased()
        let path = String(rest[slash...])
        if scheme.isEmpty || host.isEmpty { return nil }
        return MatchPattern(scheme: scheme, host: host, path: path)
    }

    static func wildcardMatches(glob: String, text: String) -> Bool {
        var rx = "^"
        for ch in glob {
            if ch == "*" {
                rx += ".*"
            } else {
                rx += NSRegularExpression.escapedPattern(for: String(ch))
            }
        }
        rx += "$"
        guard let re = try? NSRegularExpression(pattern: rx) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.firstMatch(in: text, range: range) != nil
    }
}

struct URLParts {
    let scheme: String
    let host: String
    let path: String
    let query: String?

    init?(_ url: String) {
        guard let schemeRange = url.range(of: "://") else { return nil }
        scheme = String(url[url.startIndex..<schemeRange.lowerBound]).lowercased()
        if scheme.isEmpty { return nil }
        var rest = Substring(url[schemeRange.upperBound...])

        if let hash = rest.firstIndex(of: "#") { rest = rest[rest.startIndex..<hash] }

        var q: String? = nil
        if let qmark = rest.firstIndex(of: "?") {
            q = String(rest[rest.index(after: qmark)...])
            rest = rest[rest.startIndex..<qmark]
        }
        query = q

        if let slash = rest.firstIndex(of: "/") {
            host = String(rest[rest.startIndex..<slash]).lowercased()
            path = String(rest[slash...])
        } else {
            host = String(rest).lowercased()
            path = "/"
        }
        if host.isEmpty { return nil }
    }
}

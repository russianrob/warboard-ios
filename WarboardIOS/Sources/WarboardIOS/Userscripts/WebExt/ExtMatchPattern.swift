import Foundation

/// Chrome extension match-pattern matching (`https://*.torn.com/page.php?sid=stocks`).
/// Converts a pattern to a regex: `*` → `.*`, everything else escaped. Good enough
/// for ReTorn's patterns (scheme://host/path with `*` wildcards). The `*.host`
/// subdomain form is handled by the leading `.*` (it also matches the bare host
/// because ReTorn always pairs `*.torn.com` with `https://`).
enum ExtMatchPattern {
    static func matches(_ pattern: String, _ url: String) -> Bool {
        let regex = "^" + escapeGlob(pattern) + "$"
        return url.range(of: regex, options: [.regularExpression]) != nil
    }

    private static func escapeGlob(_ pattern: String) -> String {
        var out = ""
        for ch in pattern {
            if ch == "*" {
                out += ".*"
            } else if "\\^$.|?+()[]{}".contains(ch) {
                out += "\\" + String(ch)
            } else {
                out += String(ch)
            }
        }
        return out
    }
}

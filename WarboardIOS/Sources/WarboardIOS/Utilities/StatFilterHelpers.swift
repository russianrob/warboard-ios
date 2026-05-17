import Foundation

/// Parses human-readable stat input ("10M", "1.5B", "100000", "2.5k") into
/// an Int64 value, mirroring the FactionOps userscript's input handling.
/// Returns nil when the input is empty or unparseable so callers can treat
/// "no filter" as "no constraint" rather than "match-zero".
func parseStatInput(_ raw: String) -> Int64? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let upper = trimmed.uppercased().replacingOccurrences(of: ",", with: "")
    var multiplier: Double = 1
    var digits = upper
    if let last = upper.last {
        switch last {
        case "K": multiplier = 1_000;            digits = String(upper.dropLast())
        case "M": multiplier = 1_000_000;        digits = String(upper.dropLast())
        case "B": multiplier = 1_000_000_000;    digits = String(upper.dropLast())
        case "T": multiplier = 1_000_000_000_000; digits = String(upper.dropLast())
        default: break
        }
    }
    guard let n = Double(digits), n >= 0 else { return nil }
    return Int64(n * multiplier)
}

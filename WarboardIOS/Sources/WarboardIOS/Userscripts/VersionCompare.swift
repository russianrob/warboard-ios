import Foundation

enum VersionCompare {
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let pb = b.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let count = max(pa.count, pb.count)
        for i in 0..<count {
            let ca = i < pa.count ? pa[i] : "0"
            let cb = i < pb.count ? pb[i] : "0"
            if let na = Int(ca), let nb = Int(cb) {
                if na != nb { return na < nb ? .orderedAscending : .orderedDescending }
            } else {
                if ca != cb { return ca < cb ? .orderedAscending : .orderedDescending }
            }
        }
        return .orderedSame
    }

    static func isUpdate(installed: String, remote: String) -> Bool {
        compare(installed, remote) == .orderedAscending
    }
}

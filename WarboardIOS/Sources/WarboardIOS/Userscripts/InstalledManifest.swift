import Foundation

struct ManifestEntry: Equatable {
    let filename: String
    let name: String
    let version: String
    let enabled: Bool
    let source: String
}

enum InstalledManifest {
    static func build(from scripts: [Userscript]) -> [ManifestEntry] {
        var used = Set<String>()
        var out: [ManifestEntry] = []
        for s in scripts {
            var fname = filename(for: s)
            if used.contains(fname) {
                let base = fname.hasSuffix(".user.js") ? String(fname.dropLast(8)) : fname
                var n = 2
                while used.contains("\(base)-\(n).user.js") { n += 1 }
                fname = "\(base)-\(n).user.js"
            }
            used.insert(fname)
            out.append(ManifestEntry(filename: fname, name: s.name, version: s.version ?? "",
                                     enabled: s.enabled, source: s.source))
        }
        return out
    }

    private static func filename(for s: Userscript) -> String {
        if let dl = s.downloadURL, let last = dl.split(separator: "/").last, last.hasSuffix(".user.js") {
            return String(last)
        }
        var slug = ""
        for ch in s.name.lowercased() {
            if ch.isLetter || ch.isNumber { slug.append(ch) }
            else if !slug.hasSuffix("-") { slug.append("-") }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (slug.isEmpty ? "script" : slug) + ".user.js"
    }
}

extension Array where Element == ManifestEntry {
    func asJSONBody() -> [[String: Any]] {
        map { ["filename": $0.filename, "name": $0.name, "version": $0.version,
               "enabled": $0.enabled, "source": $0.source] }
    }
}

import Foundation

final class ScriptRegistry {
    enum RegistryError: Error { case notFound(String) }

    private let fileURL: URL
    private var scripts: [Userscript]

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("userscripts.json")
        self.scripts = Self.load(from: fileURL)
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Userscripts", isDirectory: true)
    }

    private static func load(from url: URL) -> [Userscript] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Userscript].self, from: data)
        else { return [] }
        return decoded.sorted { $0.order < $1.order }
    }

    private func persist() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(scripts.sorted { $0.order < $1.order })
        try data.write(to: fileURL, options: .atomic)
    }

    private func recompact() {
        for i in scripts.indices { scripts[i].order = i }
    }

    // MARK: - Read

    func all() -> [Userscript] { scripts.sorted { $0.order < $1.order } }

    func script(id: String) -> Userscript? { scripts.first { $0.id == id } }

    func enabledScripts(matching url: URL) -> [Userscript] {
        let urlString = url.absoluteString
        return all().filter { $0.enabled && MatchMatcher.matches(url: urlString, script: $0) }
    }

    // MARK: - Write

    func add(_ script: Userscript) throws {
        var s = script
        s.order = (scripts.map(\.order).max().map { $0 + 1 }) ?? 0
        scripts.append(s)
        scripts.sort { $0.order < $1.order }
        try persist()
    }

    func upsert(_ script: Userscript) throws {
        if let idx = scripts.firstIndex(where: { $0.id == script.id }) {
            var s = script
            s.order = scripts[idx].order
            scripts[idx] = s
            try persist()
        } else {
            try add(script)
        }
    }

    func setEnabled(id: String, _ enabled: Bool) throws {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else {
            throw RegistryError.notFound(id)
        }
        scripts[idx].enabled = enabled
        try persist()
    }

    func remove(id: String) throws {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else {
            throw RegistryError.notFound(id)
        }
        scripts.remove(at: idx)
        scripts.sort { $0.order < $1.order }
        recompact()
        try persist()
    }

    func reorder(ids: [String]) throws {
        var byId = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })
        var next: [Userscript] = []
        for id in ids {
            guard let s = byId.removeValue(forKey: id) else {
                throw RegistryError.notFound(id)
            }
            next.append(s)
        }
        next.append(contentsOf: byId.values.sorted { $0.order < $1.order })
        scripts = next
        recompact()
        try persist()
    }
}

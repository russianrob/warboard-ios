import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b):   try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a):  try c.encode(a)
        case .null:          try c.encodeNil()
        }
    }
}

final class GMStore {
    private let directory: URL
    private var cache: [String: [String: JSONValue]] = [:]

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.directory = dir
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GMStore", isDirectory: true)
    }

    private func fileURL(_ scriptId: String) -> URL {
        let safe = scriptId.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics) ?? scriptId
        return directory.appendingPathComponent("\(safe).gm.json")
    }

    private func document(_ scriptId: String) -> [String: JSONValue] {
        if let d = cache[scriptId] { return d }
        let loaded: [String: JSONValue]
        if let data = try? Data(contentsOf: fileURL(scriptId)),
           let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            loaded = decoded
        } else {
            loaded = [:]
        }
        cache[scriptId] = loaded
        return loaded
    }

    private func write(_ scriptId: String, _ doc: [String: JSONValue]) throws {
        cache[scriptId] = doc
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(doc)
        try data.write(to: fileURL(scriptId), options: .atomic)
    }

    // MARK: - GM_* backend

    func get(scriptId: String, key: String) -> JSONValue? {
        document(scriptId)[key]
    }

    func set(scriptId: String, key: String, value: JSONValue) throws {
        var doc = document(scriptId)
        doc[key] = value
        try write(scriptId, doc)
    }

    func delete(scriptId: String, key: String) throws {
        var doc = document(scriptId)
        doc.removeValue(forKey: key)
        try write(scriptId, doc)
    }

    func listKeys(scriptId: String) -> [String] {
        Array(document(scriptId).keys)
    }

    // MARK: - Snapshot for the document-start bootstrap

    func snapshot(scriptId: String) -> [String: JSONValue] {
        document(scriptId)
    }

    func snapshotJSON(scriptId: String) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(document(scriptId))
        return String(decoding: data, as: UTF8.self)
    }
}

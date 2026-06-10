import Foundation

enum RunAt: String, Codable, Equatable, CaseIterable {
    case documentStart
    case documentEnd
    case documentIdle

    init(token: String?) {
        switch token?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "document-start": self = .documentStart
        case "document-end": self = .documentEnd
        case "document-idle": self = .documentIdle
        default: self = .documentIdle
        }
    }

    var token: String {
        switch self {
        case .documentStart: return "document-start"
        case .documentEnd: return "document-end"
        case .documentIdle: return "document-idle"
        }
    }
}

struct Userscript: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var namespace: String?
    var version: String?
    var description: String?
    var matches: [String]
    var includes: [String]
    var excludes: [String]
    var requires: [String]
    var connects: [String]
    var grants: [String]
    var runAt: RunAt
    var icon: String?
    var downloadURL: String?
    var updateURL: String?
    var enabled: Bool
    var order: Int
    var source: String
    var wildcardConnectGranted: Bool
}

struct ScriptMetadata: Equatable {
    var name: String?
    var namespace: String?
    var version: String?
    var description: String?
    var matches: [String] = []
    var includes: [String] = []
    var excludes: [String] = []
    var requires: [String] = []
    var connects: [String] = []
    var grants: [String] = []
    var runAt: RunAt = .documentIdle
    var icon: String?
    var downloadURL: String?
    var updateURL: String?
}

import Foundation

enum MetadataParseError: Error, Equatable {
    case missingBlock
    case unterminatedBlock
}

enum MetadataParser {
    private static let open = "==UserScript=="
    private static let close = "==/UserScript=="

    static func parse(_ source: String) throws -> ScriptMetadata {
        let lines = source.components(separatedBy: .newlines)

        guard let startIdx = lines.firstIndex(where: { stripCommentMarker($0)?.trimmingCharacters(in: .whitespaces) == open })
        else { throw MetadataParseError.missingBlock }

        var endIdx: Int?
        for i in (startIdx + 1)..<lines.count {
            if stripCommentMarker(lines[i])?.trimmingCharacters(in: .whitespaces) == close {
                endIdx = i
                break
            }
        }
        guard let blockEnd = endIdx else { throw MetadataParseError.unterminatedBlock }

        var meta = ScriptMetadata()
        var sawRunAt = false

        for i in (startIdx + 1)..<blockEnd {
            guard let body = stripCommentMarker(lines[i]) else { continue }
            guard let (key, value) = keyValue(body) else { continue }
            if value.isEmpty { continue }

            switch key {
            case "name": meta.name = value
            case "namespace": meta.namespace = value
            case "version": meta.version = value
            case "description": meta.description = value
            case "match": meta.matches.append(value)
            case "include": meta.includes.append(value)
            case "exclude": meta.excludes.append(value)
            case "require": meta.requires.append(value)
            case "connect": meta.connects.append(value)
            case "grant": meta.grants.append(value)
            case "run-at": meta.runAt = RunAt(token: value); sawRunAt = true
            case "icon", "iconurl": meta.icon = value
            case "downloadurl": meta.downloadURL = value
            case "updateurl": meta.updateURL = value
            default: break
            }
        }

        if !sawRunAt { meta.runAt = .documentIdle }
        return meta
    }

    private static func stripCommentMarker(_ line: String) -> String? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.hasPrefix("//") else { return nil }
        return String(trimmed.dropFirst(2))
    }

    private static func keyValue(_ body: String) -> (key: String, value: String)? {
        let s = body.drop(while: { $0 == " " || $0 == "\t" })
        guard s.hasPrefix("@") else { return nil }
        let afterAt = s.dropFirst()
        guard let firstWS = afterAt.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            return (String(afterAt).lowercased(), "")
        }
        let key = String(afterAt[afterAt.startIndex..<firstWS]).lowercased()
        let value = afterAt[firstWS...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }
}

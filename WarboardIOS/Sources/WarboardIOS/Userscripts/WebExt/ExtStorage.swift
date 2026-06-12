import Foundation

/// Backs `browser.storage.{local,sync,session}` over App-Group UserDefaults,
/// namespaced `webext.retorn.<area>.<key>`. `sync` collapses to local (no
/// cross-device sync on iOS); `session` is local too (cleared keys can be
/// pruned later — Phase 1 keeps it simple). `set`/`remove` return accurate
/// old/new change records so the Phase-3 notification engine can diff them.
final class ExtStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
    }

    private static func prefix(_ area: String) -> String { "webext.retorn.\(area)." }

    /// `keys` may be null (all in area), a String, an array of Strings, or a
    /// dict of key→default. Returns the resolved values.
    func get(area: String, keys: Any?) -> [String: Any] {
        let p = Self.prefix(area)
        var result: [String: Any] = [:]
        func value(_ k: String) -> Any? { defaults.object(forKey: p + k) }

        if keys == nil || keys is NSNull {
            for (full, val) in defaults.dictionaryRepresentation() where full.hasPrefix(p) {
                result[String(full.dropFirst(p.count))] = val
            }
        } else if let s = keys as? String {
            if let v = value(s) { result[s] = v }
        } else if let arr = keys as? [String] {
            for k in arr { if let v = value(k) { result[k] = v } }
        } else if let dict = keys as? [String: Any] {
            for (k, def) in dict { result[k] = value(k) ?? def }
        }
        return result
    }

    /// Stores each item; returns `{key: {oldValue, newValue}}` change records.
    @discardableResult
    func set(area: String, items: [String: Any]) -> [String: [String: Any]] {
        let p = Self.prefix(area)
        var changes: [String: [String: Any]] = [:]
        for (k, v) in items {
            let old = defaults.object(forKey: p + k)
            if v is NSNull { defaults.removeObject(forKey: p + k) }
            else { defaults.set(v, forKey: p + k) }
            changes[k] = ["oldValue": old ?? NSNull(), "newValue": v]
        }
        return changes
    }

    @discardableResult
    func remove(area: String, keys: Any?) -> [String: [String: Any]] {
        let p = Self.prefix(area)
        let list: [String] = (keys as? String).map { [$0] } ?? (keys as? [String]) ?? []
        var changes: [String: [String: Any]] = [:]
        for k in list {
            let old = defaults.object(forKey: p + k)
            defaults.removeObject(forKey: p + k)
            changes[k] = ["oldValue": old ?? NSNull(), "newValue": NSNull()]
        }
        return changes
    }

    func clear(area: String) {
        let p = Self.prefix(area)
        for (full, _) in defaults.dictionaryRepresentation() where full.hasPrefix(p) {
            defaults.removeObject(forKey: full)
        }
    }

    /// The stored version marker, for install-vs-update synthesis.
    var storedVersion: String? {
        get { defaults.string(forKey: "webext.retorn.__version") }
        set { defaults.set(newValue, forKey: "webext.retorn.__version") }
    }
}

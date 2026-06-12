import Foundation

/// Backs `browser.storage.{local,sync,session}` over App-Group UserDefaults,
/// namespaced `webext.retorn.<area>.<key>`. `sync` collapses to local (no
/// cross-device sync on iOS); `session` is local too (cleared keys can be
/// pruned later — Phase 1 keeps it simple). `set`/`remove` return accurate
/// old/new change records so the Phase-3 notification engine can diff them.
///
/// Values are stored as JSON `Data`, NOT as raw objects. The Torn `/user/`
/// blob ReTorn caches (`re_user_data`) is full of JSON `null`s, which bridge to
/// `NSNull`. `UserDefaults.set(_:forKey:)` only accepts property-list types,
/// and `NSNull` is not one — storing a null-containing dict raises an
/// uncatchable `NSInvalidArgumentException` ("Attempt to insert non-property-
/// list object") and crashes the app. Encoding to JSON Data accepts every
/// WKScriptMessage value type (including `null`) and round-trips faithfully.
final class ExtStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard) {
        self.defaults = defaults
    }

    private static func prefix(_ area: String) -> String { "webext.retorn.\(area)." }

    /// Wrap in a 1-element array so top-level fragments (string/number/bool/null)
    /// are always valid JSON roots; `decode` unwraps. Returns nil only for values
    /// JSONSerialization can't represent (none of the WKScriptMessage types).
    private static func encode(_ v: Any) -> Data? {
        try? JSONSerialization.data(withJSONObject: [v], options: [])
    }

    private static func decode(_ data: Data) -> Any? {
        guard let arr = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [Any] else {
            return nil
        }
        return arr.first
    }

    /// Read + decode a single key, with a legacy fallback for values that may
    /// have been stored raw by an earlier build.
    private func read(_ area: String, _ key: String) -> Any? {
        let full = Self.prefix(area) + key
        if let data = defaults.data(forKey: full), let value = Self.decode(data) {
            return value
        }
        return defaults.object(forKey: full)
    }

    /// `keys` may be null (all in area), a String, an array of Strings, or a
    /// dict of key→default. Returns the resolved values.
    func get(area: String, keys: Any?) -> [String: Any] {
        let p = Self.prefix(area)
        var result: [String: Any] = [:]

        if keys == nil || keys is NSNull {
            for (full, _) in defaults.dictionaryRepresentation() where full.hasPrefix(p) {
                let k = String(full.dropFirst(p.count))
                if let v = read(area, k) { result[k] = v }
            }
        } else if let s = keys as? String {
            if let v = read(area, s) { result[s] = v }
        } else if let arr = keys as? [String] {
            for k in arr { if let v = read(area, k) { result[k] = v } }
        } else if let dict = keys as? [String: Any] {
            for (k, def) in dict { result[k] = read(area, k) ?? def }
        }
        return result
    }

    /// Stores each item as JSON Data; returns `{key: {oldValue, newValue}}`.
    @discardableResult
    func set(area: String, items: [String: Any]) -> [String: [String: Any]] {
        let p = Self.prefix(area)
        var changes: [String: [String: Any]] = [:]
        for (k, v) in items {
            let old = read(area, k)
            if let data = Self.encode(v) {
                defaults.set(data, forKey: p + k)
            }
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
            let old = read(area, k)
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

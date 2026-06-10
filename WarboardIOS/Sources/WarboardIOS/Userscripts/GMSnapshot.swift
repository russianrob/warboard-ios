import Foundation

/// Generates the document-start storage snapshot embedded into the GM
/// bootstrap so `GM_getValue` / `GM_listValues` can read synchronously.
///
/// Input is a `[scriptKey: rawJSONEncodedValue]` map as persisted by `GMStore`
/// (every value is already a valid JSON fragment string, e.g. `"5"`, `"\"hi\""`,
/// `"{\"a\":1}"`). Output is a JSON object literal whose values are those
/// fragments spliced in verbatim, so the bootstrap parses it once into a plain
/// JS object.
enum GMSnapshot {
    static func objectLiteral(from rawValues: [String: String]) -> String {
        if rawValues.isEmpty { return "{}" }
        var parts: [String] = []
        parts.reserveCapacity(rawValues.count)
        for key in rawValues.keys.sorted() {
            let raw = rawValues[key]!
            let encodedKey = encodeJSONString(key)
            let value = isValidJSONFragment(raw) ? raw : "null"
            parts.append("\(encodedKey):\(value)")
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    /// JSON-encode a Swift string into a quoted JSON string literal.
    private static func encodeJSONString(_ s: String) -> String {
        // Encode as a one-element array then strip the brackets — guarantees
        // RFC-correct escaping (quotes, backslashes, control chars, unicode).
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let arr = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        // arr == "[\"...\"]" → drop the outer [ and ].
        return String(arr.dropFirst().dropLast())
    }

    /// True if `raw` parses as a standalone JSON value.
    private static func isValidJSONFragment(_ raw: String) -> Bool {
        guard let data = raw.data(using: .utf8) else { return false }
        // .fragmentsAllowed lets bare scalars (5, true, "x", null) validate.
        return (try? JSONSerialization.jsonObject(
            with: data, options: [.fragmentsAllowed])) != nil
    }
}

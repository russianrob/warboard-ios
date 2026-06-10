import Foundation

/// Loads `gm-bootstrap.js` and builds the per-script document-start
/// main-world source by prepending a `__WB_SCRIPT_CONTEXT__` literal.
///
/// The *same* bootstrap body serves every script; only the prepended context
/// (script id, `GM_info`, and the storage snapshot) differs. Mac/WebKit wraps
/// the result in a `WKUserScript` at `.atDocumentStart` (Task 12/16); that
/// wiring is not part of this headless target.
enum GMBootstrap {
    /// Cached bootstrap body, loaded once from the resource bundle.
    static let body: String = loadBody()

    /// Full main-world document-start source for one script:
    /// `var __WB_SCRIPT_CONTEXT__ = {...};\n<bootstrap>`.
    /// - Parameters:
    ///   - scriptID: the `Userscript.id`.
    ///   - infoJSON: `GM_info` object literal (built by the controller).
    ///   - snapshotLiteral: storage snapshot from `GMSnapshot.objectLiteral`.
    static func source(scriptID: String,
                       infoJSON: String,
                       snapshotLiteral: String) -> String {
        let idLiteral = jsString(scriptID)
        let context = "var __WB_SCRIPT_CONTEXT__ = {"
            + "\"scriptId\":\(idLiteral),"
            + "\"info\":\(infoJSON),"
            + "\"store\":\(snapshotLiteral)"
            + "};\n"
        return context + body
    }

    /// JSON-escape a Swift string into a JS string literal (with quotes).
    static func jsString(_ s: String) -> String {
        // Encode as a one-element array then strip the brackets — guarantees
        // RFC-correct escaping (quotes, backslashes, control chars, unicode).
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let arr = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(arr.dropFirst().dropLast())
    }

    /// Resolve and read `gm-bootstrap.js` from whichever bundle holds it.
    /// SwiftPM (Linux test build) emits `Bundle.module`; the xcodegen Mac app
    /// build copies the file into the app bundle (`Bundle.main`). Fall back to
    /// scanning loaded bundles so the headless test never misses it.
    private static func loadBody() -> String {
        let name = "gm-bootstrap"
        let ext = "js"

        var candidates: [Bundle] = []
        #if SWIFT_PACKAGE
        candidates.append(Bundle.module)
        #endif
        candidates.append(Bundle.main)
        candidates.append(contentsOf: Bundle.allBundles)

        var seen = Set<String>()
        for bundle in candidates {
            guard seen.insert(bundle.bundlePath).inserted else { continue }
            if let url = bundle.url(forResource: name, withExtension: ext),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        assertionFailure("gm-bootstrap.js missing from bundle")
        return ""
    }
}

import Foundation

/// The subset of an MV3 `manifest.json` the runtime needs: the version (for the
/// install-vs-update synthesis) and the content-script entries (which JS files
/// inject on which URL patterns, at which run-at).
struct ExtManifest: Decodable {
    let version: String
    let contentScripts: [ContentScript]

    struct ContentScript: Decodable {
        let matches: [String]
        let excludeMatches: [String]?
        let runAt: String?
        /// Ordered JS file paths; may be bundle-absolute ("/lib/x.js") or
        /// extension-relative ("js/foo.js"). Normalize with `normalized(_:)`.
        let js: [String]?
        let css: [String]?

        enum CodingKeys: String, CodingKey {
            case matches, js, css
            case runAt = "run_at"
            case excludeMatches = "exclude_matches"
        }
    }

    enum CodingKeys: String, CodingKey {
        case version
        case contentScripts = "content_scripts"
    }

    /// Strip a single leading slash so every path is bundle-relative to `retorn/`.
    static func normalized(_ jsPath: String) -> String {
        jsPath.hasPrefix("/") ? String(jsPath.dropFirst()) : jsPath
    }

    /// Loads the bundled ReTorn manifest from the app bundle (`retorn/manifest.json`).
    static func loadReTorn() -> ExtManifest? {
        guard let base = Bundle.main.resourceURL else { return nil }
        let url = base.appendingPathComponent("retorn/manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ExtManifest.self, from: data)
        else { return nil }
        return manifest
    }
}

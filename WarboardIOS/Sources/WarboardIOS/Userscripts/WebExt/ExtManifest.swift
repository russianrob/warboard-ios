import Foundation

/// The subset of an MV3 `manifest.json` the runtime needs: the version (for the
/// install-vs-update synthesis) and the content-script entries (which JS files
/// inject on which URL patterns, at which run-at).
struct ExtManifest: Decodable {
    let version: String
    let contentScripts: [ContentScript]
    let optionsUI: OptionsUI?

    /// The extension's options page, bundle-relative (leading slash stripped),
    /// or nil if the extension declares no `options_ui`.
    var optionsPage: String? { optionsUI?.page.map(ExtManifest.normalized) }

    struct OptionsUI: Decodable { let page: String? }

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
        case optionsUI = "options_ui"
    }

    /// Strip a single leading slash so every path is bundle-relative to `retorn/`.
    static func normalized(_ jsPath: String) -> String {
        jsPath.hasPrefix("/") ? String(jsPath.dropFirst()) : jsPath
    }

    /// Loads a bundled extension's manifest from `<id>/manifest.json` in the app
    /// bundle (the resource folder is named after the extension id).
    static func load(id: String) -> ExtManifest? {
        let base = RemoteExtStore.shared.containerBase(for: id)
        let url = base.appendingPathComponent("\(id)/manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ExtManifest.self, from: data)
        else { return nil }
        return manifest
    }
}

import Foundation
#if canImport(WebKit)
import WebKit

/// Reads bundled userscripts from the SwiftPM resources and injects
/// them into a `WKWebView` at the right lifecycle moment. Mirrors the
/// Kotlin `UserscriptManager` in the Android app — same scripts, same
/// match patterns, same GM_* shim.
enum UserscriptManager {

    /// One bundled userscript: an asset filename plus the Tampermonkey
    /// `@match` URL globs that decide when to inject it.
    struct Script {
        let name: String
        let assetName: String
        let assetExt: String
        let matchers: [String]
    }

    static let scripts: [Script] = [
        Script(
            name: "FactionOps",
            assetName: "factionops",
            assetExt: "user.js",
            matchers: [
                "https://www.torn.com/factions.php?step=your*",
                "https://www.torn.com/factions.php?step=profile*",
                "https://*.torn.com/loader.php?sid=attack*",
                "https://*.torn.com/page.php?sid=attack*",
                "https://*.torn.com/profiles.php?XID=*",
                "https://www.torn.com/war.php*",
            ]
        ),
        Script(
            name: "OC Spawn Assistance",
            assetName: "oc-spawn-assistance",
            assetExt: "user.js",
            matchers: ["https://www.torn.com/factions.php*"]
        ),
    ]

    /// Inject the GM_* shim. Idempotent — the shim guards against
    /// re-installation via `__warboardGMShimInstalled`. Safe to call
    /// on every navigation.
    static func injectShim(into webView: WKWebView) {
        guard let js = readBundleResource(name: "gm-shim", ext: "js") else { return }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Inject every userscript whose @match list matches `currentUrl`.
    /// Wraps each script in an IIFE so two scripts can't collide on
    /// top-level `let` / `const` re-declarations.
    static func injectMatching(into webView: WKWebView, currentUrl: String) {
        for s in scripts where s.matchers.contains(where: { matches(url: currentUrl, pattern: $0) }) {
            guard let js = readBundleResource(name: s.assetName, ext: s.assetExt) else {
                NSLog("[Warboard] Missing bundled script: \(s.name)")
                continue
            }
            let wrapped = "(function(){\n\(js)\n})();"
            webView.evaluateJavaScript(wrapped, completionHandler: nil)
            NSLog("[Warboard] Injected \(s.name) on \(currentUrl)")
        }
    }

    private static func readBundleResource(name: String, ext: String) -> String? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Tampermonkey `@match` glob → regex. Escapes regex metacharacters
    /// then expands `*` to `.*`. Good enough for the patterns the
    /// userscripts use today; not a full URLPattern implementation.
    private static func matches(url: String, pattern: String) -> Bool {
        let escapedSet: Set<Character> = [".", "+", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]", "\\"]
        var regex = ""
        for ch in pattern {
            if ch == "*" {
                regex.append(".*")
            } else if escapedSet.contains(ch) {
                regex.append("\\")
                regex.append(ch)
            } else {
                regex.append(ch)
            }
        }
        regex = "^" + regex + "$"
        return url.range(of: regex, options: .regularExpression) != nil
    }
}
#endif

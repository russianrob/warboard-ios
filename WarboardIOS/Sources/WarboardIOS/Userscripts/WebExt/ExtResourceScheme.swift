import Foundation
import WebKit

/// Serves the bundled WebExtension tree for `browser.runtime.getURL()`.
///
/// MV3 extensions reference packaged resources (default settings JSON, images,
/// the main-world inject scripts) via `getURL('path')`, which our shim maps to
/// `webext://retorn/<path>`. This handler resolves that to a file inside the
/// app bundle's `retorn/` folder reference and streams it back.
final class ExtResourceScheme: NSObject, WKURLSchemeHandler {
    /// Custom scheme registered on the WKWebViewConfiguration.
    static let scheme = "webext"

    private static func mime(for ext: String) -> String {
        switch ext.lowercased() {
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "json":      return "application/json; charset=utf-8"
        case "css":       return "text/css; charset=utf-8"
        case "html", "htm": return "text/html; charset=utf-8"
        case "png":       return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":       return "image/gif"
        case "svg":       return "image/svg+xml"
        case "woff":      return "font/woff"
        case "woff2":     return "font/woff2"
        default:          return "application/octet-stream"
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let host = url.host else {
            urlSchemeTask.didFailWithError(URLError(.badURL)); return
        }
        // webext://retorn/js/gym/gym.js -> host="retorn", path="/js/gym/gym.js"
        // -> bundle/retorn/js/gym/gym.js
        let relative = host + url.path
        guard let base = Bundle.main.resourceURL else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let fileURL = base.appendingPathComponent(relative)
        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": Self.mime(for: fileURL.pathExtension),
                "Content-Length": String(data.count),
                "Access-Control-Allow-Origin": "*",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

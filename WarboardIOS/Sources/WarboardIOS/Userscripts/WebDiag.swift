import Foundation

/// Fire-and-forget diagnostic POSTer for the in-app browser. Mirrors the
/// userscripts' `/api/debug/client-log` shape so webview events land in the
/// same warboard log stream (tag `ios-webview-diag`). Dependency-free: no
/// auth, no retry, response ignored — never blocks or surfaces failures.
enum WebDiag {
    private static let endpoint = URL(string: "https://tornwar.com/api/debug/client-log")!

    static func log(_ event: String, _ detail: [String: Any] = [:]) {
        var data: [String: Any] = detail
        data["event"] = event
        let body: [String: Any] = ["tag": "ios-webview-diag", "data": data]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = 10
        URLSession.shared.dataTask(with: req).resume()
    }
}

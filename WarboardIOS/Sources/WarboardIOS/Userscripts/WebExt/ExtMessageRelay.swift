import Foundation
import WebKit

/// The native side of the `browser` shim: a `WKScriptMessageHandlerWithReply`
/// named `webextBridge`. Content scripts (in the "retorn" world) and the hidden
/// background host both post here; replies become the JS promise the shim awaits.
///
/// Routes by `kind`: `storage` → ExtStorage; `sendMessage` → the background host's
/// onMessage handlers; `apiFetch` → URLSession (CORS bypass); `tabs.create` →
/// open-in-app; `alarms`/`notifications`/`action` are Phase-3 stubs.
final class ExtMessageRelay: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "webextBridge"

    private let storage: ExtStorage
    weak var backgroundHost: ExtBackgroundHost?
    /// tabs.create → ask the app to open a URL in the browser.
    var onOpenURL: ((String) -> Void)?

    init(storage: ExtStorage) {
        self.storage = storage
        super.init()
    }

    func register(on ucc: WKUserContentController, world: WKContentWorld) {
        ucc.removeScriptMessageHandler(forName: Self.name, contentWorld: world)
        ucc.addScriptMessageHandler(self, contentWorld: world, name: Self.name)
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else {
            replyHandler(nil, "bad webext message"); return
        }
        switch kind {
        case "storage":
            handleStorage(body, replyHandler)
        case "sendMessage":
            let msg = body["message"] as Any
            Task { @MainActor in
                let reply: Any? = await self.backgroundHost?.dispatch(msg, sender: [:]) ?? nil
                replyHandler(reply, nil)
            }
        case "apiFetch":
            handleApiFetch(body, replyHandler)
        case "tabs":
            if (body["op"] as? String) == "create",
               let props = body["props"] as? [String: Any],
               let url = props["url"] as? String {
                onOpenURL?(url)
            }
            replyHandler(nil, nil)
        case "alarms":
            // Phase-1 stub: `get` returns a scheduledTime so popup timing code
            // doesn't break; create/clear are no-ops until Phase 3.
            if (body["op"] as? String) == "get" {
                replyHandler(["scheduledTime": Date().timeIntervalSince1970 * 1000], nil)
            } else {
                replyHandler(nil, nil)
            }
        case "notifications", "action":
            replyHandler(nil, nil) // Phase 3
        default:
            replyHandler(nil, "unknown webext kind: \(kind)")
        }
    }

    private func handleStorage(_ body: [String: Any], _ reply: @escaping (Any?, String?) -> Void) {
        let area = (body["area"] as? String) ?? "local"
        switch body["op"] as? String {
        case "get":
            reply(storage.get(area: area, keys: body["keys"]), nil)
        case "set":
            if let items = body["items"] as? [String: Any] {
                storage.set(area: area, items: items)
            }
            reply(nil, nil)
        case "remove":
            storage.remove(area: area, keys: body["keys"])
            reply(nil, nil)
        case "clear":
            storage.clear(area: area)
            reply(nil, nil)
        default:
            reply(nil, "bad storage op")
        }
    }

    private func handleApiFetch(_ body: [String: Any], _ reply: @escaping (Any?, String?) -> Void) {
        guard let urlStr = body["url"] as? String, let url = URL(string: urlStr) else {
            reply(nil, "bad apiFetch url"); return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            DispatchQueue.main.async {
                reply(["status": status, "ok": (200..<300).contains(status), "body": text], nil)
            }
        }.resume()
    }
}

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
    /// runtime.openOptionsPage / action popup → ask the app to present an
    /// extension page (e.g. "options") in a sheet.
    var onOpenExtPage: ((String) -> Void)?

    /// `browser.alarms` backing: a repeating timer per alarm name whose tick
    /// fires `onAlarm` into the bg world (the extension's only recurring trigger,
    /// e.g. TornTools' data-update alarm → userdata refresh). `alarmInfo` mirrors
    /// the registrations so `get`/`getAll` can answer.
    private var alarmTimers: [String: Timer] = [:]
    private var alarmInfo: [String: [String: Any]] = [:]

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
        ExtCrashDiag.breadcrumb("relay:\(kind):\(Self.crumbDetail(kind, body))")
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
                if url.hasPrefix("\(ExtResourceScheme.scheme)://") {
                    // An extension page opened as a tab (e.g. options.html via
                    // options_ui.open_in_tab). Present it in the extension-page
                    // sheet, which serves webext:// + injects this extension's
                    // shim/relay. The browser tab's config has neither, so loading
                    // it there just renders blank.
                    onOpenExtPage?("options")
                } else {
                    onOpenURL?(url)
                }
            }
            replyHandler(nil, nil)
        case "openExtPage":
            onOpenExtPage?((body["page"] as? String) ?? "options")
            replyHandler(nil, nil)
        case "diag":
            // Content-world instrumentation (debug extensions only) → server log.
            WebDiag.log("webext-content-diag", body)
            replyHandler(nil, nil)
        case "alarms":
            handleAlarms(body, replyHandler)
        case "notifications", "action":
            replyHandler(nil, nil) // Phase 3
        default:
            replyHandler(nil, "unknown webext kind: \(kind)")
        }
    }

    /// A compact, plist-safe detail string for the breadcrumb trail: the storage
    /// op + keys, the sendMessage `name`, or the apiFetch host — enough to know
    /// exactly which step a crash report stopped at.
    private static func crumbDetail(_ kind: String, _ body: [String: Any]) -> String {
        switch kind {
        case "storage":
            let op = (body["op"] as? String) ?? "?"
            let keys = (body["items"] as? [String: Any]).map { Array($0.keys) }
                ?? (body["keys"] as? [String]) ?? (body["keys"] as? String).map { [$0] } ?? []
            return "\(op):\(keys.joined(separator: ","))"
        case "sendMessage":
            return ((body["message"] as? [String: Any])?["name"] as? String) ?? "?"
        case "apiFetch":
            return URL(string: (body["url"] as? String) ?? "")?.host ?? "?"
        default:
            return (body["op"] as? String) ?? ""
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

    /// Real `browser.alarms`. `create` schedules a repeating timer (sub-minute
    /// allowed; 5s floor) whose tick fires `onAlarm` into the bg world via the
    /// background host. The extension re-arms its alarms on each bg boot (its
    /// own onInitialisation/resetAlarms → clearAll + create), so the registry
    /// self-heals; a tick into a torn-down webview is a safe no-op (fireAlarm
    /// guards a nil web view).
    private func handleAlarms(_ body: [String: Any], _ reply: @escaping (Any?, String?) -> Void) {
        switch body["op"] as? String {
        case "create":
            guard let name = body["name"] as? String else { reply(nil, nil); return }
            let info = body["info"] as? [String: Any] ?? [:]
            let period = Self.minutes(info["periodInMinutes"])
            let delay = Self.minutes(info["delayInMinutes"])
            alarmTimers[name]?.invalidate()
            let now = Date().timeIntervalSince1970 * 1000
            alarmInfo[name] = ["name": name, "periodInMinutes": period,
                               "scheduledTime": now + max(delay, period) * 60_000]
            if period > 0 {
                let t = Timer.scheduledTimer(withTimeInterval: max(period * 60, 5), repeats: true) { [weak self] _ in
                    self?.backgroundHost?.fireAlarm(name: name)
                }
                alarmTimers[name] = t
            }
            reply(nil, nil)
        case "clear":
            if let name = body["name"] as? String {
                alarmTimers[name]?.invalidate(); alarmTimers[name] = nil; alarmInfo[name] = nil
            }
            reply(true, nil)
        case "clearAll":
            alarmTimers.values.forEach { $0.invalidate() }
            alarmTimers.removeAll(); alarmInfo.removeAll()
            reply(true, nil)
        case "get":
            reply((body["name"] as? String).flatMap { alarmInfo[$0] } as Any, nil)
        case "getAll":
            reply(Array(alarmInfo.values), nil)
        default:
            reply(nil, nil)
        }
    }

    private static func minutes(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        return 0
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
                ExtCrashDiag.breadcrumb("apiFetch:reply:\(status)")
                reply(["status": status, "ok": (200..<300).contains(status), "body": text], nil)
            }
        }.resume()
    }
}

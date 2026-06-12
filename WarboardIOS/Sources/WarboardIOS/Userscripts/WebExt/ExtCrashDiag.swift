import Foundation

/// Reliable crash capture for the WebExt runtime.
///
/// The previous logger POSTed asynchronously from inside the uncaught-exception
/// handler — but the process terminates before that network call can flush, so
/// nothing was ever recorded. Instead, PERSIST the crash to App-Group
/// UserDefaults synchronously at crash time (survives termination) and UPLOAD it
/// on the next launch via `WebDiag`. Breadcrumbs (also persisted, plist-safe
/// strings) record how far a flow got, so even without a usable stack the last
/// successful step localizes the failure.
///
/// Covers uncaught ObjC exceptions (`NSInvalidArgumentException` from WebKit /
/// UserDefaults misuse, etc.). Pure Swift traps (force-unwrap, `fatalError`)
/// are not ObjC exceptions and won't fire this handler — if a crash leaves no
/// captured exception but the breadcrumbs stop mid-flow, that points at a trap.
enum ExtCrashDiag {
    private static let store = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard
    private static let pendingKey = "webext.crash.pending"
    private static let crumbsKey = "webext.crash.crumbs"
    private static let maxCrumbs = 50

    /// Persist a step marker. Synchronous + plist-safe so it survives a crash.
    static func breadcrumb(_ s: String) {
        var arr = store.stringArray(forKey: crumbsKey) ?? []
        arr.append(s)
        if arr.count > maxCrumbs { arr.removeFirst(arr.count - maxCrumbs) }
        store.set(arr, forKey: crumbsKey)
    }

    /// Install once at runtime start: upload any crash persisted last launch,
    /// then capture future uncaught ObjC exceptions synchronously to disk.
    static func install() {
        flushPending()
        NSSetUncaughtExceptionHandler { e in
            ExtCrashDiag.record([
                "name": e.name.rawValue,
                "reason": e.reason ?? "",
                "stack": e.callStackSymbols.prefix(30).joined(separator: " || "),
            ])
        }
    }

    private static func record(_ info: [String: String]) {
        var payload: [String: Any] = info
        payload["crumbs"] = (store.stringArray(forKey: crumbsKey) ?? []).joined(separator: " > ")
        store.set(payload, forKey: pendingKey)
        store.synchronize()
    }

    private static func flushPending() {
        guard let payload = store.dictionary(forKey: pendingKey) else { return }
        store.removeObject(forKey: pendingKey)
        store.removeObject(forKey: crumbsKey)
        store.synchronize()
        WebDiag.log("webext-crash", payload)
    }
}

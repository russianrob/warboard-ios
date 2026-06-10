import Foundation

/// Platform-free mirror of `WKUserScriptInjectionTime`. The WebKit glue
/// (`UserscriptController`) maps these to the real enum; keeping the planner
/// WebKit-free lets it run under `swift test` on Linux CI.
enum InjectionTiming: Equatable {
    case documentStart
    case documentEnd
}

/// One fully-resolved payload ready to become a `WKUserScript`.
struct PlannedUserScript: Equatable {
    let source: String
    let timing: InjectionTiming
    let mainFrameOnly: Bool
    /// Diagnostic label: "bootstrap", "<scriptId>#require:<url>", "<scriptId>#body".
    let label: String
}

/// Pure planner: given the destination URL, the pre-filtered ordered scripts,
/// and resolved @require sources, emit the exact ordered injection payload list.
enum UserscriptInjectionPlanner {

    /// Maps a script's `@run-at` to WebKit injection timing.
    /// document-start → documentStart; document-end / document-idle → documentEnd.
    static func timing(for runAt: RunAt) -> InjectionTiming {
        switch runAt {
        case .documentStart: return .documentStart
        case .documentEnd, .documentIdle: return .documentEnd
        }
    }

    static func plan(
        for url: URL,
        scripts: [Userscript],
        requireSources: [String: String],
        bootstrapSource: String
    ) -> [PlannedUserScript] {
        var plan: [PlannedUserScript] = []

        // The GM bootstrap runs first, in the main world, at document-start so
        // `unsafeWindow`/`GM_*` are in place before any script body executes.
        plan.append(PlannedUserScript(
            source: bootstrapSource,
            timing: .documentStart,
            mainFrameOnly: true,
            label: "bootstrap"
        ))

        for script in scripts {
            // Every @require must be resolved; if a library is missing the
            // script can't run safely, so drop it entirely (no partial inject).
            var resolvedRequires: [(url: String, source: String)] = []
            var allRequiresPresent = true
            for require in script.requires {
                guard let source = requireSources[require] else {
                    allRequiresPresent = false
                    break
                }
                resolvedRequires.append((url: require, source: source))
            }
            guard allRequiresPresent else { continue }

            // @require libs and the body share the body's timing so the library
            // is present in the page when the body runs.
            let bodyTiming = timing(for: script.runAt)

            for require in resolvedRequires {
                plan.append(PlannedUserScript(
                    source: require.source,
                    timing: bodyTiming,
                    mainFrameOnly: true,
                    label: "\(script.id)#require:\(require.url)"
                ))
            }

            // document-idle has no native WebKit timing; defer the body via
            // requestIdleCallback so it runs after document-end like Tampermonkey.
            let bodySource = script.runAt == .documentIdle
                ? idleShim(script.source)
                : script.source

            plan.append(PlannedUserScript(
                source: bodySource,
                timing: bodyTiming,
                mainFrameOnly: true,
                label: "\(script.id)#body"
            ))
        }

        return plan
    }

    /// Wrap a document-idle body so it runs on the next idle tick (with a
    /// timeout fallback), mirroring Tampermonkey's document-idle semantics.
    private static func idleShim(_ body: String) -> String {
        let runner = "function(){\n\(body)\n}"
        return "(function(){var __wb_run=\(runner);"
            + "if(typeof requestIdleCallback==='function'){"
            + "requestIdleCallback(__wb_run,{timeout:1000});}"
            + "else{setTimeout(__wb_run,0);}})();"
    }
}

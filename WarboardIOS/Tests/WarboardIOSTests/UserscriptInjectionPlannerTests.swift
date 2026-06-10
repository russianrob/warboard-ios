import XCTest
@testable import WarboardIOS

final class UserscriptInjectionPlannerTests: XCTestCase {

    private func script(
        id: String,
        runAt: RunAt,
        requires: [String] = [],
        body: String = "BODY"
    ) -> Userscript {
        Userscript(
            id: id, name: id, namespace: "", version: "1", description: "",
            matches: ["*://*.torn.com/*"], includes: [], excludes: [],
            requires: requires, connects: [], grants: [], runAt: runAt,
            icon: nil, downloadURL: nil, updateURL: nil,
            enabled: true, order: 0, source: body,
            wildcardConnectGranted: false
        )
    }

    private let url = URL(string: "https://www.torn.com/factions.php?step=your")!

    // MARK: run-at → timing mapping (pure)

    func testRunAtMapping() {
        XCTAssertEqual(UserscriptInjectionPlanner.timing(for: .documentStart), .documentStart)
        XCTAssertEqual(UserscriptInjectionPlanner.timing(for: .documentEnd), .documentEnd)
        XCTAssertEqual(UserscriptInjectionPlanner.timing(for: .documentIdle), .documentEnd)
    }

    // MARK: bootstrap is always first, at documentStart, main world

    func testBootstrapAlwaysFirstAtDocumentStart() {
        let plan = UserscriptInjectionPlanner.plan(
            for: url,
            scripts: [script(id: "a", runAt: .documentEnd)],
            requireSources: [:],
            bootstrapSource: "BOOT"
        )
        XCTAssertEqual(plan.first?.label, "bootstrap")
        XCTAssertEqual(plan.first?.source, "BOOT")
        XCTAssertEqual(plan.first?.timing, .documentStart)
        XCTAssertEqual(plan.first?.mainFrameOnly, true)
    }

    // MARK: @require sources precede the body, in @require order

    func testRequiresPrecedeBodyInOrder() {
        let s = script(
            id: "factionops",
            runAt: .documentIdle,
            requires: ["https://cdn/socket.io.js", "https://cdn/util.js"],
            body: "FACTIONOPS"
        )
        let plan = UserscriptInjectionPlanner.plan(
            for: url,
            scripts: [s],
            requireSources: [
                "https://cdn/socket.io.js": "SOCKETIO",
                "https://cdn/util.js": "UTIL"
            ],
            bootstrapSource: "BOOT"
        )
        let labels = plan.map(\.label)
        XCTAssertEqual(labels, [
            "bootstrap",
            "factionops#require:https://cdn/socket.io.js",
            "factionops#require:https://cdn/util.js",
            "factionops#body"
        ])
        // requires inject at the BODY's timing (so the lib is present when body runs)
        XCTAssertEqual(plan[1].timing, .documentEnd)
        XCTAssertEqual(plan[1].source, "SOCKETIO")
        XCTAssertEqual(plan[2].source, "UTIL")
    }

    // MARK: install order across multiple scripts is preserved

    func testMultipleScriptsKeepInstallOrder() {
        let a = script(id: "a", runAt: .documentStart, body: "A")
        let b = script(id: "b", runAt: .documentEnd, body: "B")
        let plan = UserscriptInjectionPlanner.plan(
            for: url, scripts: [a, b], requireSources: [:], bootstrapSource: "BOOT"
        )
        XCTAssertEqual(plan.map(\.label), ["bootstrap", "a#body", "b#body"])
        XCTAssertEqual(plan[1].timing, .documentStart)
        XCTAssertEqual(plan[2].timing, .documentEnd)
    }

    // MARK: document-idle body is wrapped in the idle shim; start/end are NOT

    func testDocumentIdleBodyIsWrappedInIdleShim() {
        let idle = script(id: "idle", runAt: .documentIdle, body: "IDLEBODY")
        let plan = UserscriptInjectionPlanner.plan(
            for: url, scripts: [idle], requireSources: [:], bootstrapSource: "BOOT"
        )
        let body = plan.first { $0.label == "idle#body" }!
        XCTAssertTrue(body.source.contains("requestIdleCallback"),
                      "idle body must be deferred via requestIdleCallback")
        XCTAssertTrue(body.source.contains("IDLEBODY"))
        // not double-wrapped / not wrapping a non-idle script:
        let end = script(id: "end", runAt: .documentEnd, body: "ENDBODY")
        let plan2 = UserscriptInjectionPlanner.plan(
            for: url, scripts: [end], requireSources: [:], bootstrapSource: "BOOT"
        )
        let endBody = plan2.first { $0.label == "end#body" }!
        XCTAssertFalse(endBody.source.contains("requestIdleCallback"))
        XCTAssertEqual(endBody.source, "ENDBODY")
    }

    // MARK: a missing @require source produces NO body (script can't run safely)

    func testMissingRequireDropsScriptBody() {
        let s = script(id: "needslib", runAt: .documentEnd,
                       requires: ["https://cdn/missing.js"], body: "NEEDSLIB")
        let plan = UserscriptInjectionPlanner.plan(
            for: url, scripts: [s], requireSources: [:], bootstrapSource: "BOOT"
        )
        // only the bootstrap — needslib is skipped entirely
        XCTAssertEqual(plan.map(\.label), ["bootstrap"])
    }

    // MARK: every payload's main-frame flag is true (Torn scripts run top-frame only)

    func testAllPayloadsMainFrameOnly() {
        let s = script(id: "a", runAt: .documentEnd,
                       requires: ["https://cdn/lib.js"], body: "A")
        let plan = UserscriptInjectionPlanner.plan(
            for: url, scripts: [s],
            requireSources: ["https://cdn/lib.js": "LIB"], bootstrapSource: "BOOT"
        )
        XCTAssertTrue(plan.allSatisfy(\.mainFrameOnly))
    }
}

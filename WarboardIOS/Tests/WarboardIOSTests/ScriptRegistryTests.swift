import XCTest
@testable import WarboardIOS

final class ScriptRegistryTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scriptregistry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func script(_ name: String, matches: [String] = ["https://www.torn.com/*"]) -> Userscript {
        Userscript(
            id: UUID().uuidString,
            name: name,
            namespace: "test",
            version: "1.0.0",
            description: "",
            matches: matches,
            includes: [],
            excludes: [],
            requires: [],
            connects: [],
            grants: [],
            runAt: .documentIdle,
            icon: nil,
            downloadURL: nil,
            updateURL: nil,
            enabled: true,
            order: 0,
            source: "// ==UserScript==\n// ==/UserScript==\n",
            wildcardConnectGranted: false
        )
    }

    func testAddAssignsContiguousOrderAndPersists() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        try reg.add(script("a"))
        try reg.add(script("b"))
        try reg.add(script("c"))

        XCTAssertEqual(reg.all().map(\.name), ["a", "b", "c"])
        XCTAssertEqual(reg.all().map(\.order), [0, 1, 2])

        // A fresh registry over the same directory reloads the same list.
        let reloaded = ScriptRegistry(directory: tmpDir)
        XCTAssertEqual(reloaded.all().map(\.name), ["a", "b", "c"])
        XCTAssertEqual(reloaded.all().map(\.order), [0, 1, 2])
    }

    func testRemoveCompactsOrder() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        let a = script("a"); let b = script("b"); let c = script("c")
        try reg.add(a); try reg.add(b); try reg.add(c)

        try reg.remove(id: b.id)

        XCTAssertEqual(reg.all().map(\.name), ["a", "c"])
        XCTAssertEqual(reg.all().map(\.order), [0, 1])
    }

    func testEnableDisableTogglesAndPersists() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        let a = script("a")
        try reg.add(a)

        try reg.setEnabled(id: a.id, false)
        XCTAssertEqual(reg.all().first?.enabled, false)

        let reloaded = ScriptRegistry(directory: tmpDir)
        XCTAssertEqual(reloaded.all().first?.enabled, false)
    }

    func testReorderRewritesOrderField() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        let a = script("a"); let b = script("b"); let c = script("c")
        try reg.add(a); try reg.add(b); try reg.add(c)

        // Move c to the front: new id order is [c, a, b].
        try reg.reorder(ids: [c.id, a.id, b.id])

        XCTAssertEqual(reg.all().map(\.name), ["c", "a", "b"])
        XCTAssertEqual(reg.all().map(\.order), [0, 1, 2])
    }

    func testUpsertReplacesSourceAndKeepsOrder() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        var a = script("a")
        try reg.add(a)
        try reg.add(script("b"))

        a.version = "2.0.0"
        a.source = "// updated"
        try reg.upsert(a)   // same id → replace in place, keep order 0

        XCTAssertEqual(reg.all().map(\.name), ["a", "b"])
        XCTAssertEqual(reg.script(id: a.id)?.version, "2.0.0")
        XCTAssertEqual(reg.script(id: a.id)?.order, 0)
    }
}

extension ScriptRegistryTests {
    func testEnabledScriptsMatchingFiltersByEnabledAndURLInOrder() throws {
        let reg = ScriptRegistry(directory: tmpDir)
        try reg.add(script("torn-only", matches: ["https://www.torn.com/*"]))
        try reg.add(script("disabled", matches: ["https://www.torn.com/*"]))
        try reg.add(script("greasy",   matches: ["https://greasyfork.org/*"]))

        let disabled = reg.all().first { $0.name == "disabled" }!
        try reg.setEnabled(id: disabled.id, false)

        let url = URL(string: "https://www.torn.com/factions.php?step=your")!
        let hits = reg.enabledScripts(matching: url)

        // "disabled" is filtered out; "greasy" doesn't @match torn.com;
        // result is install-order sorted.
        XCTAssertEqual(hits.map(\.name), ["torn-only"])
    }
}

import XCTest
@testable import WarboardIOS

@MainActor
final class LocalInstallerTests: XCTestCase {
    private func tempInstaller() -> (LocalInstaller, ScriptRegistry) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let registry = ScriptRegistry(directory: tmp)
        let cache = RequireCache(root: tmp.appendingPathComponent("req"))
        let resolver = RequireResolver(cache: cache, fetch: { _ in "" })   // no @require -> never called
        return (LocalInstaller(registry: registry, resolver: resolver), registry)
    }
    private let valid = """
    // ==UserScript==
    // @name Travel Declutter
    // @version 1.0.0
    // @match https://www.torn.com/*
    // ==/UserScript==
    (function(){})();
    """

    func testInstallAddsToRegistryWithStableId() async throws {
        let (installer, registry) = tempInstaller()
        let dl = "https://tornwar.com/scripts/x.user.js"
        _ = try await installer.install(filename: "x.user.js", content: valid, downloadURL: dl)
        XCTAssertEqual(registry.all().count, 1)
        XCTAssertEqual(registry.all().first?.id, SHA256Pure.hexDigest(dl))
        XCTAssertEqual(registry.all().first?.matches, ["https://www.torn.com/*"])
    }

    func testRedeploySameFilenameUpsertsNoDuplicate() async throws {
        let (installer, registry) = tempInstaller()
        let dl = "https://tornwar.com/scripts/x.user.js"
        _ = try await installer.install(filename: "x.user.js", content: valid, downloadURL: dl)
        _ = try await installer.install(filename: "x.user.js", content: valid + "\n// edit", downloadURL: dl)
        XCTAssertEqual(registry.all().count, 1)
        XCTAssertTrue(registry.all().first!.source.contains("// edit"))
    }

    func testNoMatchIsRejected() async {
        let (installer, _) = tempInstaller()
        let noMatch = "// ==UserScript==\n// @name No\n// ==/UserScript==\n"
        do {
            _ = try await installer.install(filename: "n.user.js", content: noMatch, downloadURL: "https://tornwar.com/scripts/n.user.js")
            XCTFail("expected noMatch")
        } catch let e as LocalInstaller.InstallError {
            XCTAssertEqual(e, .noMatch)
        } catch { XCTFail("wrong error: \(error)") }
    }
}

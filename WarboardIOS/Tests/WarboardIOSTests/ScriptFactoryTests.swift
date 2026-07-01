import XCTest
@testable import WarboardIOS

final class ScriptFactoryTests: XCTestCase {
    func testMakeMapsMetadataAndDerivesIdFromDownloadURL() throws {
        var meta = ScriptMetadata()
        meta.name = "Alpha"; meta.version = "1.2"; meta.matches = ["https://www.torn.com/*"]
        meta.runAt = .documentStart
        let dl = "https://tornwar.com/scripts/alpha.user.js"
        let s = ScriptFactory.make(from: meta, source: "// SRC", downloadURL: dl)
        XCTAssertEqual(s.id, SHA256Pure.hexDigest(dl))
        XCTAssertEqual(s.name, "Alpha")
        XCTAssertEqual(s.version, "1.2")
        XCTAssertEqual(s.matches, ["https://www.torn.com/*"])
        XCTAssertEqual(s.runAt, .documentStart)
        XCTAssertEqual(s.source, "// SRC")
        XCTAssertTrue(s.enabled)
        XCTAssertEqual(s.downloadURL, dl)   // meta.downloadURL nil -> falls back to arg
    }
}

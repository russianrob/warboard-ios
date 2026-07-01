import XCTest
@testable import WarboardIOS

final class InstalledManifestTests: XCTestCase {
    private func script(name: String, dl: String?) -> Userscript {
        Userscript(id: dl ?? name, name: name, namespace: nil, version: "1", description: nil,
                   matches: ["*"], includes: [], excludes: [], requires: [], connects: [], grants: [],
                   runAt: .documentIdle, icon: nil, downloadURL: dl, updateURL: nil,
                   enabled: true, order: 0, source: "//s", wildcardConnectGranted: false)
    }

    func testFilenameFromDownloadURLBasename() {
        let m = InstalledManifest.build(from: [script(name: "Whatever", dl: "https://tornwar.com/scripts/foo.user.js")])
        XCTAssertEqual(m.first?.filename, "foo.user.js")
    }

    func testFilenameSluggedFromNameWhenNoURL() {
        let m = InstalledManifest.build(from: [script(name: "My Script!", dl: nil)])
        XCTAssertEqual(m.first?.filename, "my-script.user.js")
    }

    func testDuplicateFilenamesGetSuffix() {
        let m = InstalledManifest.build(from: [
            script(name: "A", dl: "https://x/foo.user.js"),
            script(name: "B", dl: "https://y/foo.user.js"),
        ])
        XCTAssertEqual(m.map(\.filename), ["foo.user.js", "foo-2.user.js"])
    }
}

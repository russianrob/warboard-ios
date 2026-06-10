# iOS Userscript Host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Tampermonkey-class userscript host (with `@require`) to warboard-iOS — an in-app navigable Torn browser that runs arbitrary installed userscripts on iOS.

**Architecture:** Native Swift owns the script registry, `@require` cache, per-navigation `WKUserScript` rebuild (Approach 1), the `GM_*` bridge (`WKScriptMessageHandlerWithReply`), and the `@connect`/`URLSession` proxy; injected JS provides the `GM_*` shims + `unsafeWindow` (main world). Pure logic (parser, matcher, cache keys, version compare) is XCTest-covered; WebKit wiring is Xcode-build/smoke-verified on a Mac.

**Tech Stack:** Swift, SwiftUI, WebKit, URLSession, XCTest; SwiftPM/xcodegen under `WarboardIOS/`.

**Spec:** `docs/superpowers/specs/2026-06-10-ios-userscript-host-design.md`.

---

> ⚠️ **Execution order:** Do the **"Add the XCTest target"** task (in the final UI/integration section) **FIRST** — every unit-test task depends on it. Then execute the rest top-to-bottom: parser/matcher → registry/storage → `@require` → GM bridge → injection engine → Browser/Scripts UI + integration.

## File Structure

All paths are under the warboard-iOS repo (`/root/projects/warboard-ios/`).

**Engine sources** — `WarboardIOS/Sources/WarboardIOS/Userscripts/`

- `Userscript.swift` — `Userscript` persisted model + `ScriptMetadata` parse result + the `RunAt` enum.
- `MetadataParser.swift` — parses a `// ==UserScript== … ==/UserScript==` block into `ScriptMetadata`.
- `MatchMatcher.swift` — `@match` glob compiler plus `@include`/`@exclude` and the full per-script URL decision.
- `ScriptRegistry.swift` — durable, install-ordered list of installed scripts (`userscripts.json`); per-navigation matching seam.
- `GMStore.swift` — per-script namespaced K/V backend for the `GM_*` storage APIs; defines the `JSONValue` any-JSON codec.
- `SHA256Pure.swift` — dependency-free SHA-256 used to content-address `@require` cache entries.
- `RequireCache.swift` — content-addressed on-disk cache for `@require` library bodies.
- `RequireResolver.swift` — fetches `@require` libs on install/update into the cache and supplies injection sources.
- `ConnectPolicy.swift` — pure `@connect` allowlist evaluator for `GM_xmlhttpRequest`.
- `GMSnapshot.swift` — generates the document-start storage snapshot JSON literal for the bootstrap.
- `Resources/gm-bootstrap.js` — in-page `GM_*`/`GM.*` + `unsafeWindow` bootstrap injected at document-start (bundled resource).
- `GMBootstrap.swift` — loads `gm-bootstrap.js` and builds the per-script `__WB_SCRIPT_CONTEXT__` source.
- `GMBridge.swift` — native `WKScriptMessageHandlerWithReply`; routes bootstrap messages to storage/XHR/clipboard/tabs; builds `GM_info`.
- `UserscriptInjectionPlanner.swift` — pure planner that orders the per-navigation injection payload list (`PlannedUserScript`, `InjectionTiming`).
- `UserscriptController.swift` — WebKit glue: owns the `WKWebViewConfiguration`, rebuilds the user-script set per navigation, registers handlers.
- `VersionCompare.swift` — numeric `@version` comparison for the update badge.
- `BrowserView.swift` — navigable `WKWebView` SwiftUI tab (`BrowserModel`, `BrowserWebView`) wired to `UserscriptController`.
- `ScriptsView.swift` — Scripts management screen (`ScriptsViewModel`): add-by-URL, list, enable, update, remove, reorder.

**Tests** — `WarboardIOS/Tests/WarboardIOSTests/`

- Pure (headless `swift test`): `UserscriptModelTests`, `MetadataParserTests`, `MatchMatcherTests`, `MatchMatcherIncludeExcludeTests`, `ScriptRegistryTests`, `GMStoreTests`, `RequireCacheTests`, `RequireResolverTests`, `ConnectPolicyTests`, `GMSnapshotTests`, `UserscriptInjectionPlannerTests`, `VersionCompareTests`.
- WebKit (Mac/CI only): `GMBridgeIntegrationTests` — `WKWebView` round-trip smoke, guarded by `#if canImport(WebKit)`.

**Modified app files**

- `WarboardIOS/Sources/WarboardIOS/Views/ContentView.swift` — add the Browser + Scripts tabs to the `WBTab` enum + `ZStack` body.
- `WarboardIOS/Sources/WarboardIOS/Views/TornChatWebView.swift` — non-breaking convenience hook only; referenced as the existing `WKWebView` pattern.

**Packaging / build**

- `Package.swift` — thin SwiftPM manifest so the pure engine sources + tests run headlessly on Linux CI.
- `project.yml` — adds the `WarboardIOSTests` xcodegen target and wires it into the `Warboard` scheme's `test` block.
- `WarboardIOS/Tests/WarboardIOSTests/.gitkeep` — placeholder so the test source path resolves before any test file exists.

## Tasks

### Task 1: `Userscript` model + `ScriptMetadata` (pure Codable structs)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/Userscript.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/UserscriptModelTests.swift`

- [ ] **Step 1: Write the failing model round-trip test.** This is pure-logic (Foundation only, no WebKit), so it runs headless. Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/UserscriptModelTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class UserscriptModelTests: XCTestCase {
    func testRunAtDecodesTampermonkeyTokens() throws {
        XCTAssertEqual(RunAt(token: "document-start"), .documentStart)
        XCTAssertEqual(RunAt(token: "document-end"), .documentEnd)
        XCTAssertEqual(RunAt(token: "document-idle"), .documentIdle)
        // Unknown / missing falls back to Tampermonkey's default.
        XCTAssertEqual(RunAt(token: "bogus"), .documentIdle)
        XCTAssertEqual(RunAt(token: nil), .documentIdle)
    }

    func testRunAtRoundTripsItsRawToken() throws {
        for value in [RunAt.documentStart, .documentEnd, .documentIdle] {
            XCTAssertEqual(RunAt(token: value.token), value)
        }
    }

    func testUserscriptCodableRoundTrip() throws {
        let script = Userscript(
            id: "11111111-1111-1111-1111-111111111111",
            name: "factionops",
            namespace: "RussianRob",
            version: "1.2.6",
            description: "war overlay",
            matches: ["https://*.torn.com/factions.php*"],
            includes: ["*://www.torn.com/loader.php*"],
            excludes: ["https://www.torn.com/logout*"],
            requires: ["https://cdn.socket.io/4.7.5/socket.io.min.js"],
            connects: ["tornwar.com", "*"],
            grants: ["GM_getValue", "GM_setValue", "unsafeWindow"],
            runAt: .documentIdle,
            icon: "https://www.torn.com/favicon.ico",
            downloadURL: "https://greasyfork.org/scripts/1/factionops.user.js",
            updateURL: "https://greasyfork.org/scripts/1/factionops.meta.js",
            enabled: true,
            order: 3,
            source: "// ==UserScript==\n// @name factionops\n// ==/UserScript==\n",
            wildcardConnectGranted: true
        )
        let data = try JSONEncoder().encode(script)
        let decoded = try JSONDecoder().decode(Userscript.self, from: data)
        XCTAssertEqual(decoded, script)
    }
}
```

- [ ] **Step 2: Run it and watch it fail to compile** (no `RunAt`/`Userscript` yet). On this Linux server pure Swift tests run headlessly:

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter UserscriptModelTests
```

Expect: `error: cannot find 'RunAt' in scope` / `cannot find 'Userscript' in scope`.

- [ ] **Step 3: Create the model file** `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/Userscript.swift`:

```swift
import Foundation

enum RunAt: String, Codable, Equatable, CaseIterable {
    case documentStart
    case documentEnd
    case documentIdle

    init(token: String?) {
        switch token?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "document-start": self = .documentStart
        case "document-end": self = .documentEnd
        case "document-idle": self = .documentIdle
        default: self = .documentIdle
        }
    }

    var token: String {
        switch self {
        case .documentStart: return "document-start"
        case .documentEnd: return "document-end"
        case .documentIdle: return "document-idle"
        }
    }
}

struct Userscript: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var namespace: String?
    var version: String?
    var description: String?
    var matches: [String]
    var includes: [String]
    var excludes: [String]
    var requires: [String]
    var connects: [String]
    var grants: [String]
    var runAt: RunAt
    var icon: String?
    var downloadURL: String?
    var updateURL: String?
    var enabled: Bool
    var order: Int
    var source: String
    var wildcardConnectGranted: Bool
}
```

- [ ] **Step 4: Create `ScriptMetadata`** — the pure parse result, *before* it gets an `id`/`order`/`enabled` install identity. Add to the same file (so the parser has a target distinct from the persisted model):

```swift
struct ScriptMetadata: Equatable {
    var name: String?
    var namespace: String?
    var version: String?
    var description: String?
    var matches: [String] = []
    var includes: [String] = []
    var excludes: [String] = []
    var requires: [String] = []
    var connects: [String] = []
    var grants: [String] = []
    var runAt: RunAt = .documentIdle
    var icon: String?
    var downloadURL: String?
    var updateURL: String?
}
```

- [ ] **Step 5: Re-run the test, confirm green:**

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter UserscriptModelTests
```

Expect: `Executed 3 tests, with 0 failures`.

---

### Task 2: `MetadataParser` (pure Swift)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/MetadataParser.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MetadataParserTests.swift`

- [ ] **Step 1: Write the failing parser tests** (Foundation only → headless). Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MetadataParserTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class MetadataParserTests: XCTestCase {

    private let factionops = """
    // ==UserScript==
    // @name         factionops
    // @namespace    RussianRob
    // @version      1.2.6
    // @description  war overlay
    // @match        https://*.torn.com/factions.php*
    // @match        https://www.torn.com/loader.php?sid=*
    // @include      *://www.torn.com/profiles.php*
    // @exclude      https://www.torn.com/logout*
    // @require      https://cdn.socket.io/4.7.5/socket.io.min.js
    // @require      https://example.com/lib.js
    // @connect      tornwar.com
    // @connect      api.torn.com
    // @connect      *
    // @grant        GM_getValue
    // @grant        GM_setValue
    // @grant        unsafeWindow
    // @run-at       document-end
    // @icon         https://www.torn.com/favicon.ico
    // @downloadURL  https://greasyfork.org/scripts/1/factionops.user.js
    // @updateURL    https://greasyfork.org/scripts/1/factionops.meta.js
    // ==/UserScript==
    (function(){ console.log("body"); })();
    """

    func testParsesAllRepeatedKeysIntoArrays() throws {
        let m = try MetadataParser.parse(factionops)
        XCTAssertEqual(m.name, "factionops")
        XCTAssertEqual(m.namespace, "RussianRob")
        XCTAssertEqual(m.version, "1.2.6")
        XCTAssertEqual(m.description, "war overlay")
        XCTAssertEqual(m.matches, [
            "https://*.torn.com/factions.php*",
            "https://www.torn.com/loader.php?sid=*",
        ])
        XCTAssertEqual(m.includes, ["*://www.torn.com/profiles.php*"])
        XCTAssertEqual(m.excludes, ["https://www.torn.com/logout*"])
        XCTAssertEqual(m.requires, [
            "https://cdn.socket.io/4.7.5/socket.io.min.js",
            "https://example.com/lib.js",
        ])
        XCTAssertEqual(m.connects, ["tornwar.com", "api.torn.com", "*"])
        XCTAssertEqual(m.grants, ["GM_getValue", "GM_setValue", "unsafeWindow"])
        XCTAssertEqual(m.runAt, .documentEnd)
        XCTAssertEqual(m.icon, "https://www.torn.com/favicon.ico")
        XCTAssertEqual(m.downloadURL, "https://greasyfork.org/scripts/1/factionops.user.js")
        XCTAssertEqual(m.updateURL, "https://greasyfork.org/scripts/1/factionops.meta.js")
    }

    func testRunAtDefaultsToDocumentIdleWhenAbsent() throws {
        let src = """
        // ==UserScript==
        // @name minimal
        // @match https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.runAt, .documentIdle)
    }

    func testValueMayContainSpacesAndIsTrimmed() throws {
        let src = """
        // ==UserScript==
        // @name   a script   with   spaces
        // @match  https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.name, "a script   with   spaces")
    }

    func testKeyWithNoValueIsIgnored() throws {
        // A bare `// @grant` with no value (Tampermonkey's "no-grant"
        // sentinel) must not append an empty string.
        let src = """
        // ==UserScript==
        // @name nogrant
        // @match https://www.torn.com/*
        // @grant
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.grants, [])
    }

    func testLeadingBlankAndCodeLinesBeforeBlockAreSkipped() throws {
        let src = """

        const x = 1; // not metadata
        // ==UserScript==
        // @name late
        // @match https://www.torn.com/*
        // ==/UserScript==
        """
        let m = try MetadataParser.parse(src)
        XCTAssertEqual(m.name, "late")
    }

    func testThrowsWhenNoOpeningMarker() throws {
        let src = "// @name orphan\n// @match https://www.torn.com/*\n"
        XCTAssertThrowsError(try MetadataParser.parse(src)) { err in
            XCTAssertEqual(err as? MetadataParseError, .missingBlock)
        }
    }

    func testThrowsWhenNoClosingMarker() throws {
        let src = """
        // ==UserScript==
        // @name unterminated
        // @match https://www.torn.com/*
        """
        XCTAssertThrowsError(try MetadataParser.parse(src)) { err in
            XCTAssertEqual(err as? MetadataParseError, .unterminatedBlock)
        }
    }
}
```

- [ ] **Step 2: Run and watch it fail** (`MetadataParser`/`MetadataParseError` don't exist):

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MetadataParserTests
```

Expect: `error: cannot find 'MetadataParser' in scope`.

- [ ] **Step 3: Implement the parser.** Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/MetadataParser.swift`:

```swift
import Foundation

enum MetadataParseError: Error, Equatable {
    case missingBlock
    case unterminatedBlock
}

enum MetadataParser {
    private static let open = "==UserScript=="
    private static let close = "==/UserScript=="

    static func parse(_ source: String) throws -> ScriptMetadata {
        let lines = source.components(separatedBy: .newlines)

        guard let startIdx = lines.firstIndex(where: { stripCommentMarker($0)?.trimmingCharacters(in: .whitespaces) == open })
        else { throw MetadataParseError.missingBlock }

        var endIdx: Int?
        for i in (startIdx + 1)..<lines.count {
            if stripCommentMarker(lines[i])?.trimmingCharacters(in: .whitespaces) == close {
                endIdx = i
                break
            }
        }
        guard let blockEnd = endIdx else { throw MetadataParseError.unterminatedBlock }

        var meta = ScriptMetadata()
        var sawRunAt = false

        for i in (startIdx + 1)..<blockEnd {
            guard let body = stripCommentMarker(lines[i]) else { continue }
            guard let (key, value) = keyValue(body) else { continue }
            if value.isEmpty { continue }

            switch key {
            case "name": meta.name = value
            case "namespace": meta.namespace = value
            case "version": meta.version = value
            case "description": meta.description = value
            case "match": meta.matches.append(value)
            case "include": meta.includes.append(value)
            case "exclude": meta.excludes.append(value)
            case "require": meta.requires.append(value)
            case "connect": meta.connects.append(value)
            case "grant": meta.grants.append(value)
            case "run-at": meta.runAt = RunAt(token: value); sawRunAt = true
            case "icon", "iconurl": meta.icon = value
            case "downloadurl": meta.downloadURL = value
            case "updateurl": meta.updateURL = value
            default: break
            }
        }

        if !sawRunAt { meta.runAt = .documentIdle }
        return meta
    }

    /// Returns the text after a leading `//` comment marker, or nil if the
    /// line is not a `//` comment line. Tolerates leading whitespace.
    private static func stripCommentMarker(_ line: String) -> String? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.hasPrefix("//") else { return nil }
        return String(trimmed.dropFirst(2))
    }

    /// Splits `  @match   https://x/*` into ("match", "https://x/*").
    /// Key is lowercased; value is everything after the first run of
    /// whitespace, trimmed on both ends. Returns nil if no `@key`.
    private static func keyValue(_ body: String) -> (key: String, value: String)? {
        let s = body.drop(while: { $0 == " " || $0 == "\t" })
        guard s.hasPrefix("@") else { return nil }
        let afterAt = s.dropFirst()
        guard let firstWS = afterAt.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            // `@key` with no value at all.
            return (String(afterAt).lowercased(), "")
        }
        let key = String(afterAt[afterAt.startIndex..<firstWS]).lowercased()
        let value = afterAt[firstWS...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }
}
```

- [ ] **Step 4: Re-run, confirm green:**

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MetadataParserTests
```

Expect: `Executed 7 tests, with 0 failures`. The empty-value guard (`if value.isEmpty`) makes both `testKeyWithNoValueIsIgnored` and the absent-`@run-at` default pass.

---

### Task 3: `MatchMatcher` — `@match` glob compiler (pure Swift)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/MatchMatcher.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MatchMatcherTests.swift`

This task does the Tampermonkey `@match` pattern (scheme `://` host `/` path with restricted globbing). `@include`/`@exclude` string+regex semantics are Task 4 — kept separate so each has tight tests.

- [ ] **Step 1: Write the failing `@match` tests** (Foundation/`NSRegularExpression` only → headless). Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MatchMatcherTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class MatchMatcherTests: XCTestCase {

    private func matches(_ pattern: String, _ url: String) -> Bool {
        MatchMatcher.matchesMatchPattern(pattern: pattern, url: url)
    }

    func testHostWildcardSubdomain() {
        // `*.torn.com` matches both apex and any subdomain (TM rule).
        XCTAssertTrue(matches("https://*.torn.com/*", "https://www.torn.com/factions.php"))
        XCTAssertTrue(matches("https://*.torn.com/*", "https://torn.com/factions.php"))
        XCTAssertTrue(matches("https://*.torn.com/*", "https://api.torn.com/v2/user"))
        XCTAssertFalse(matches("https://*.torn.com/*", "https://eviltorn.com/x"))
        XCTAssertFalse(matches("https://*.torn.com/*", "https://torn.com.evil.com/x"))
    }

    func testSchemeWildcardMatchesHttpAndHttps() {
        XCTAssertTrue(matches("*://www.torn.com/*", "http://www.torn.com/x"))
        XCTAssertTrue(matches("*://www.torn.com/*", "https://www.torn.com/x"))
        // `*` scheme in TM is http|https only, not ftp.
        XCTAssertFalse(matches("*://www.torn.com/*", "ftp://www.torn.com/x"))
    }

    func testExactSchemeIsHonored() {
        XCTAssertFalse(matches("https://www.torn.com/*", "http://www.torn.com/x"))
        XCTAssertTrue(matches("http://www.torn.com/*", "http://www.torn.com/x"))
    }

    func testPathGlobAndQueryString() {
        XCTAssertTrue(matches("https://www.torn.com/factions.php*",
                              "https://www.torn.com/factions.php?step=your"))
        XCTAssertTrue(matches("https://www.torn.com/factions.php*",
                              "https://www.torn.com/factions.php"))
        XCTAssertFalse(matches("https://www.torn.com/factions.php*",
                               "https://www.torn.com/profiles.php"))
    }

    func testPathStarMatchesEmptyPath() {
        // TM: `/*` matches a URL whose path is just `/`.
        XCTAssertTrue(matches("https://www.torn.com/*", "https://www.torn.com/"))
        XCTAssertTrue(matches("https://www.torn.com/*", "https://www.torn.com"))
    }

    func testHostIsAnchoredNotSubstring() {
        XCTAssertFalse(matches("https://www.torn.com/*", "https://www.torn.com.evil.com/x"))
        XCTAssertFalse(matches("https://www.torn.com/*", "https://evil.www.torn.com/x"))
    }

    func testPathWildcardInMiddle() {
        XCTAssertTrue(matches("https://www.torn.com/loader.php?sid=*",
                              "https://www.torn.com/loader.php?sid=attack&user2ID=1"))
        XCTAssertFalse(matches("https://www.torn.com/loader.php?sid=*",
                               "https://www.torn.com/loader.php?mode=x"))
    }

    func testSpecialRegexCharsInPathAreEscaped() {
        // `.` and `?` in the pattern are literal, not regex metachars.
        XCTAssertTrue(matches("https://www.torn.com/a.b.php",
                              "https://www.torn.com/a.b.php"))
        XCTAssertFalse(matches("https://www.torn.com/a.b.php",
                               "https://www.torn.com/aXbYphp"))
    }

    func testMalformedPatternNeverMatches() {
        XCTAssertFalse(matches("not-a-valid-pattern", "https://www.torn.com/x"))
        XCTAssertFalse(matches("https://www.torn.com", "https://www.torn.com/x")) // no path section
    }
}
```

- [ ] **Step 2: Run, watch it fail** (`MatchMatcher` missing):

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MatchMatcherTests
```

Expect: `error: cannot find 'MatchMatcher' in scope`.

- [ ] **Step 3: Implement the `@match` compiler.** Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/MatchMatcher.swift`:

```swift
import Foundation

/// Pure Tampermonkey/Chrome match-pattern + include/exclude engine.
/// No WebKit/UIKit deps — unit-testable on any platform.
enum MatchMatcher {

    /// `<scheme>://<host><path>` where:
    ///   scheme = `*` | `http` | `https` | …
    ///   host   = `*` | `*.domain` | `domain`
    ///   path   = glob with `*`
    static func matchesMatchPattern(pattern: String, url: String) -> Bool {
        guard let p = parseMatchPattern(pattern),
              let u = URLParts(url)
        else { return false }

        // scheme
        if p.scheme == "*" {
            if u.scheme != "http" && u.scheme != "https" { return false }
        } else if p.scheme != u.scheme {
            return false
        }

        // host
        if p.host == "*" {
            // matches any host
        } else if p.host.hasPrefix("*.") {
            let suffix = String(p.host.dropFirst(2)) // drop "*."
            // `*.torn.com` matches apex `torn.com` and any `x.torn.com`.
            if u.host != suffix && !u.host.hasSuffix("." + suffix) { return false }
        } else if p.host != u.host {
            return false
        }

        // path (+ query) — anchored full match with `*` → `.*`
        let target = u.path + (u.query.map { "?" + $0 } ?? "")
        return wildcardMatches(glob: p.path, text: target)
    }

    private struct MatchPattern { let scheme: String; let host: String; let path: String }

    private static func parseMatchPattern(_ pattern: String) -> MatchPattern? {
        guard let schemeRange = pattern.range(of: "://") else { return nil }
        let scheme = String(pattern[pattern.startIndex..<schemeRange.lowerBound]).lowercased()
        let rest = pattern[schemeRange.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return nil } // path required
        let host = String(rest[rest.startIndex..<slash]).lowercased()
        let path = String(rest[slash...])
        if scheme.isEmpty || host.isEmpty { return nil }
        return MatchPattern(scheme: scheme, host: host, path: path)
    }

    /// Compiles a `*`-glob to an anchored regex. Everything except `*`
    /// is escaped literally (so `.`, `?`, `+` are not regex metachars).
    static func wildcardMatches(glob: String, text: String) -> Bool {
        var rx = "^"
        for ch in glob {
            if ch == "*" {
                rx += ".*"
            } else {
                rx += NSRegularExpression.escapedPattern(for: String(ch))
            }
        }
        rx += "$"
        guard let re = try? NSRegularExpression(pattern: rx) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.firstMatch(in: text, range: range) != nil
    }
}

/// Minimal URL splitter that does NOT depend on Foundation's URLComponents
/// host-normalization quirks; gives us scheme / host / path / query as the
/// match engine needs them. Treats a missing path as "/".
struct URLParts {
    let scheme: String
    let host: String
    let path: String
    let query: String?

    init?(_ url: String) {
        guard let schemeRange = url.range(of: "://") else { return nil }
        scheme = String(url[url.startIndex..<schemeRange.lowerBound]).lowercased()
        if scheme.isEmpty { return nil }
        var rest = Substring(url[schemeRange.upperBound...])

        // strip fragment
        if let hash = rest.firstIndex(of: "#") { rest = rest[rest.startIndex..<hash] }

        // split query
        var q: String? = nil
        if let qmark = rest.firstIndex(of: "?") {
            q = String(rest[rest.index(after: qmark)...])
            rest = rest[rest.startIndex..<qmark]
        }
        query = q

        // host ends at first "/"
        if let slash = rest.firstIndex(of: "/") {
            host = String(rest[rest.startIndex..<slash]).lowercased()
            path = String(rest[slash...])
        } else {
            host = String(rest).lowercased()
            path = "/"
        }
        if host.isEmpty { return nil }
    }
}
```

- [ ] **Step 4: Re-run, confirm green:**

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MatchMatcherTests
```

Expect: `Executed 9 tests, with 0 failures`. Note `testPathStarMatchesEmptyPath` relies on `URLParts` defaulting a hostless-path URL (`https://www.torn.com`) to `path = "/"`, which `/` `*`-glob matches.

---

### Task 4: `MatchMatcher.matches(url:)` — include/exclude + full script decision (pure Swift)

**Files:**
- Modify: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/MatchMatcher.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MatchMatcherIncludeExcludeTests.swift`

`@include`/`@exclude` use legacy GM glob (`*` = `.*` over the *whole* URL) OR a `/regex/` literal. The public entry point `matches(url:)` combines `@match` ∪ `@include`, minus `@exclude`, with **exclude beating include/match**.

- [ ] **Step 1: Write the failing include/exclude + combined tests** (headless). Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/MatchMatcherIncludeExcludeTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class MatchMatcherIncludeExcludeTests: XCTestCase {

    func testIncludeGlobMatchesWholeURL() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "*://www.torn.com/profiles.php*",
            url: "https://www.torn.com/profiles.php?XID=1"))
        XCTAssertFalse(MatchMatcher.matchesIncludePattern(
            pattern: "*://www.torn.com/profiles.php*",
            url: "https://www.torn.com/factions.php"))
    }

    func testIncludeBareStarMatchesEverything() {
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(pattern: "*",
            url: "https://anything.example/x?y=1#z"))
    }

    func testIncludeRegexLiteral() {
        // `/.../` form → treated as a regex, not a glob.
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "/^https:\\/\\/www\\.torn\\.com\\/factions\\.php/",
            url: "https://www.torn.com/factions.php?step=your"))
        XCTAssertFalse(MatchMatcher.matchesIncludePattern(
            pattern: "/^https:\\/\\/www\\.torn\\.com\\/factions\\.php/",
            url: "https://www.torn.com/profiles.php"))
    }

    func testIncludeRegexIsUnanchoredSubstring() {
        // Unlike @match, a regex @include is a substring search unless anchored.
        XCTAssertTrue(MatchMatcher.matchesIncludePattern(
            pattern: "/loader\\.php/",
            url: "https://www.torn.com/loader.php?sid=attack"))
    }

    func testExcludeBeatsMatch() {
        let script = makeScript(
            matches: ["https://*.torn.com/*"],
            includes: [],
            excludes: ["https://www.torn.com/logout*"])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/factions.php", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/logout.php", script: script))
    }

    func testExcludeBeatsInclude() {
        let script = makeScript(
            matches: [],
            includes: ["*://www.torn.com/*"],
            excludes: ["/admin/"])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/index.php", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/admin/panel", script: script))
    }

    func testMatchOrIncludeUnion() {
        let script = makeScript(
            matches: ["https://www.torn.com/factions.php*"],
            includes: ["*://www.torn.com/profiles.php*"],
            excludes: [])
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/factions.php", script: script))
        XCTAssertTrue(MatchMatcher.matches(url: "https://www.torn.com/profiles.php?XID=1", script: script))
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/items.php", script: script))
    }

    func testNoMatchOrIncludeNeverRuns() {
        let script = makeScript(matches: [], includes: [], excludes: [])
        XCTAssertFalse(MatchMatcher.matches(url: "https://www.torn.com/x", script: script))
    }

    // MARK: helper
    private func makeScript(matches: [String], includes: [String], excludes: [String]) -> Userscript {
        Userscript(
            id: "00000000-0000-0000-0000-000000000000",
            name: "t", namespace: nil, version: nil, description: nil,
            matches: matches, includes: includes, excludes: excludes,
            requires: [], connects: [], grants: [], runAt: .documentIdle,
            icon: nil, downloadURL: nil, updateURL: nil,
            enabled: true, order: 0, source: "", wildcardConnectGranted: false)
    }
}
```

- [ ] **Step 2: Run, watch it fail** (`matchesIncludePattern` / `matches(url:script:)` missing):

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MatchMatcherIncludeExcludeTests
```

Expect: `error: type 'MatchMatcher' has no member 'matchesIncludePattern'`.

- [ ] **Step 3: Add include/exclude + the public decision entry point** to `MatchMatcher.swift` (append inside the `enum MatchMatcher` body, before its closing brace):

```swift
    /// `@include`/`@exclude` semantics: a `/regex/` literal is an
    /// unanchored ICU regex over the whole URL; anything else is a legacy
    /// glob where only `*` is special (`.*`) and the rest is literal,
    /// anchored to the whole URL.
    static func matchesIncludePattern(pattern: String, url: String) -> Bool {
        if pattern.count >= 2, pattern.hasPrefix("/"), pattern.hasSuffix("/") {
            let body = String(pattern.dropFirst().dropLast())
            guard let re = try? NSRegularExpression(pattern: body) else { return false }
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            return re.firstMatch(in: url, range: range) != nil
        }
        return wildcardMatches(glob: pattern, text: url)
    }

    /// Full Tampermonkey decision for one script against one URL:
    /// (any @match OR any @include) AND NOT (any @exclude).
    /// Exclude wins. A script with no @match and no @include never runs.
    static func matches(url: String, script: Userscript) -> Bool {
        for ex in script.excludes where matchesIncludePattern(pattern: ex, url: url) {
            return false
        }
        for m in script.matches where matchesMatchPattern(pattern: m, url: url) {
            return true
        }
        for inc in script.includes where matchesIncludePattern(pattern: inc, url: url) {
            return true
        }
        return false
    }
```

- [ ] **Step 4: Re-run, confirm green:**

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter MatchMatcherIncludeExcludeTests
```

Expect: `Executed 8 tests, with 0 failures`. Exclude-beats-everything is guaranteed by checking `excludes` first and short-circuiting `false`.

- [ ] **Step 5: Run the whole parsing/matching suite together to confirm nothing regressed:**

```
cd /root/projects/warboard-ios/WarboardIOS && swift test --filter 'UserscriptModelTests|MetadataParserTests|MatchMatcherTests|MatchMatcherIncludeExcludeTests'
```

Expect all four classes green. These are all pure Foundation (`String`, `NSRegularExpression`, `JSONEncoder`) with **no WebKit/UIKit imports**, so they run headlessly under `swift test` on this Linux server — no Mac/Xcode required for this section. (The test target itself is created by subsystem 6; if running before that lands, these files compile but `swift test` has no target to attach them to — that's expected and is subsystem 6's responsibility.)

### Task 5: ScriptRegistry — persist installed userscripts to JSON in Application Support

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptRegistry.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/ScriptRegistryTests.swift`

Depends on the `Userscript` model + `MatchMatcher` from the model/parser section. `ScriptRegistry` owns the durable list of installed scripts: a single Codable JSON file (`userscripts.json`) under Application Support. The store is pure-ish (filesystem only — no WebKit/UIKit), so it runs under `swift test` headless. The injection-order contract: `order: Int` is dense and contiguous starting at 0; `add` appends at the end (max order + 1), `remove` re-compacts, `reorder` rewrites the `order` field, and every accessor that returns lists returns them **sorted by `order`**.

- [ ] **Step 1: Write the failing persistence + CRUD test.** This pins the file location injection, round-trip, append-order, and enabled-filter contract. It will not compile until `ScriptRegistry` exists.

```swift
// /root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/ScriptRegistryTests.swift
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
```

- [ ] **Step 2: Write a separate failing test for the `enabledScripts(matching:)` helper.** This is the seam the injection pipeline (other section) calls per navigation. It must honor `enabled`, preserve install order, and delegate URL matching to `MatchMatcher`.

```swift
// append to ScriptRegistryTests.swift
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
```

- [ ] **Step 3: Run the tests and confirm they fail to compile (no `ScriptRegistry`).**
  Verification: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter ScriptRegistryTests` — expect a compile error `cannot find 'ScriptRegistry' in scope`. (Note: this assumes the test target from subsystem 6 and the `Userscript`/`MatchMatcher` types are present; if `Userscript` is also still missing, the failure is the RED state for the dependency ordering — implement this task only after the model task lands.)

- [ ] **Step 4: Implement `ScriptRegistry` to make the tests pass.** Default directory resolves to the real Application Support container; tests inject a temp dir. Writes are atomic; the on-disk shape is a single JSON array of `Userscript`.

```swift
// /root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptRegistry.swift
import Foundation

/// Durable list of installed userscripts. Backed by a single Codable
/// JSON file (`userscripts.json`) under Application Support. Pure-ish:
/// filesystem only, no WebKit/UIKit — so it unit-tests headless.
///
/// `order` is the install/injection order: dense, contiguous, starting
/// at 0. Every list accessor returns scripts sorted by `order`. The
/// injection pipeline reads `enabledScripts(matching:)` per navigation.
final class ScriptRegistry {
    enum RegistryError: Error { case notFound(String) }

    private let fileURL: URL
    private var scripts: [Userscript]

    /// Production callers pass no arguments → Application Support.
    /// Tests inject a temp `directory`.
    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("userscripts.json")
        self.scripts = Self.load(from: fileURL)
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Userscripts", isDirectory: true)
    }

    private static func load(from url: URL) -> [Userscript] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Userscript].self, from: data)
        else { return [] }
        return decoded.sorted { $0.order < $1.order }
    }

    private func persist() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(scripts.sorted { $0.order < $1.order })
        try data.write(to: fileURL, options: .atomic)
    }

    /// Re-densify `order` to 0..<count following current array position.
    private func recompact() {
        for i in scripts.indices { scripts[i].order = i }
    }

    // MARK: - Read

    func all() -> [Userscript] { scripts.sorted { $0.order < $1.order } }

    func script(id: String) -> Userscript? { scripts.first { $0.id == id } }

    /// The per-navigation seam: enabled scripts whose @match/@include
    /// (and not @exclude) accept `url`, in install order.
    func enabledScripts(matching url: URL) -> [Userscript] {
        all().filter { $0.enabled && MatchMatcher(script: $0).matches(url) }
    }

    // MARK: - Write

    /// Append a new script at the end of the install order.
    func add(_ script: Userscript) throws {
        var s = script
        s.order = (scripts.map(\.order).max().map { $0 + 1 }) ?? 0
        scripts.append(s)
        scripts.sort { $0.order < $1.order }
        try persist()
    }

    /// Replace an existing script (same id) in place, keeping its order;
    /// or append if the id is new. Used by install-update.
    func upsert(_ script: Userscript) throws {
        if let idx = scripts.firstIndex(where: { $0.id == script.id }) {
            var s = script
            s.order = scripts[idx].order
            scripts[idx] = s
            try persist()
        } else {
            try add(script)
        }
    }

    func setEnabled(id: String, _ enabled: Bool) throws {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else {
            throw RegistryError.notFound(id)
        }
        scripts[idx].enabled = enabled
        try persist()
    }

    func remove(id: String) throws {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else {
            throw RegistryError.notFound(id)
        }
        scripts.remove(at: idx)
        scripts.sort { $0.order < $1.order }
        recompact()
        try persist()
    }

    /// Reorder by a full list of ids (must cover every installed id).
    /// New `order` follows the supplied id sequence.
    func reorder(ids: [String]) throws {
        var byId = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })
        var next: [Userscript] = []
        for id in ids {
            guard let s = byId.removeValue(forKey: id) else {
                throw RegistryError.notFound(id)
            }
            next.append(s)
        }
        // Any ids not named keep their relative order, appended after.
        next.append(contentsOf: byId.values.sorted { $0.order < $1.order })
        scripts = next
        recompact()
        try persist()
    }
}
```

- [ ] **Step 5: Re-run the tests and confirm GREEN.**
  Verification: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter ScriptRegistryTests` — expect all six test methods passing.

- [ ] **Step 6: Register the new file with the build.** The Xcode project is generated from `/root/projects/warboard-ios/project.yml`; the `Warboard` target already globs `WarboardIOS/Sources/WarboardIOS` (`sources: - path: WarboardIOS/Sources/WarboardIOS`), so the new `Userscripts/` subdirectory is picked up automatically with no `project.yml` edit. Confirm by regenerating on a Mac: `cd /root/projects/warboard-ios && xcodegen generate` and checking `ScriptRegistry.swift` appears in the Warboard target's Compile Sources. (Mac-only — `xcodegen`/Xcode are not available on this Linux server. The `swift test` runs in Step 5 already prove the source compiles headless.)

---

### Task 6: GMStore — per-script namespaced K/V, one JSON document per script id

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMStore.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMStoreTests.swift`

`GMStore` is the native backend for `GM_setValue`/`GM_getValue`/`GM_deleteValue`/`GM_listValues`. One file-backed JSON document **per script id** (`<scriptId>.gm.json`) under an Application Support subdirectory. Values are arbitrary JSON (string, number, bool, object, array) — so the document is `[String: JSONValue]` where `JSONValue` is a small Codable any-JSON enum. The whole document serializes to a `[String: Any]`-equivalent the bootstrap injects as the document-start snapshot. Pure filesystem → headless-testable with a temp dir.

- [ ] **Step 1: Write the failing test for the `JSONValue` codec.** This must round-trip every GM value shape and decode from real JSON text, because the bootstrap snapshot and `GM_xmlhttpRequest` payloads both ride on it.

```swift
// /root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMStoreTests.swift
import XCTest
@testable import WarboardIOS

final class JSONValueTests: XCTestCase {
    func testDecodesEveryJSONShape() throws {
        let json = """
        { "s": "hi", "n": 42, "f": 3.5, "b": true, "z": null,
          "arr": [1, "two", false],
          "obj": { "k": "v" } }
        """.data(using: .utf8)!
        let v = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case let .object(d) = v else { return XCTFail("expected object") }
        XCTAssertEqual(d["s"], .string("hi"))
        XCTAssertEqual(d["b"], .bool(true))
        XCTAssertEqual(d["z"], .null)
        XCTAssertEqual(d["arr"], .array([.number(1), .string("two"), .bool(false)]))
        XCTAssertEqual(d["obj"], .object(["k": .string("v")]))
    }

    func testEncodeDecodeRoundTrips() throws {
        let original: JSONValue = .object([
            "name": .string("factionops"),
            "count": .number(7),
            "on": .bool(true),
            "tags": .array([.string("a"), .string("b")])
        ])
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, back)
    }

    func testBoolIsNotCoercedToNumber() throws {
        // JSONSerialization/Codable can confuse true→1; pin the distinction.
        let data = "true".data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), .bool(true))
        let n = "1".data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: n), .number(1))
    }
}
```

- [ ] **Step 2: Write the failing test for `GMStore` CRUD + per-id isolation + snapshot.** Pins namespacing (two script ids never collide), persistence across instances, delete, list, and the snapshot shape the bootstrap consumes.

```swift
// append to GMStoreTests.swift
final class GMStoreTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gmstore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmpDir) }

    func testSetGetRoundTripsAndPersists() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "theme", value: .string("dark"))
        XCTAssertEqual(store.get(scriptId: "s1", key: "theme"), .string("dark"))

        // A fresh store over the same dir reloads the value.
        let reopened = GMStore(directory: tmpDir)
        XCTAssertEqual(reopened.get(scriptId: "s1", key: "theme"), .string("dark"))
    }

    func testScriptIdsAreIsolated() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "k", value: .number(1))
        try store.set(scriptId: "s2", key: "k", value: .number(2))
        XCTAssertEqual(store.get(scriptId: "s1", key: "k"), .number(1))
        XCTAssertEqual(store.get(scriptId: "s2", key: "k"), .number(2))
    }

    func testDeleteAndListValues() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "a", value: .string("x"))
        try store.set(scriptId: "s1", key: "b", value: .string("y"))
        XCTAssertEqual(store.listKeys(scriptId: "s1").sorted(), ["a", "b"])

        try store.delete(scriptId: "s1", key: "a")
        XCTAssertEqual(store.listKeys(scriptId: "s1"), ["b"])
        XCTAssertNil(store.get(scriptId: "s1", key: "a"))
    }

    func testSnapshotReturnsWholeDocument() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "a", value: .number(1))
        try store.set(scriptId: "s1", key: "b", value: .bool(false))

        let snap = store.snapshot(scriptId: "s1")
        XCTAssertEqual(snap, ["a": .number(1), "b": .bool(false)])
        // Empty for an unknown script id — bootstrap injects {}.
        XCTAssertEqual(store.snapshot(scriptId: "unknown"), [:])
    }

    func testSnapshotJSONStringIsValidObject() throws {
        let store = GMStore(directory: tmpDir)
        try store.set(scriptId: "s1", key: "name", value: .string("ops"))
        let jsonString = try store.snapshotJSON(scriptId: "s1")
        // Round-trip through Foundation to confirm it's valid JSON the
        // bootstrap can `JSON.parse`.
        let obj = try JSONSerialization.jsonObject(
            with: jsonString.data(using: .utf8)!) as? [String: Any]
        XCTAssertEqual(obj?["name"] as? String, "ops")
    }
}
```

- [ ] **Step 3: Run the tests and confirm they fail (no `JSONValue` / `GMStore`).**
  Verification: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter GMStoreTests` and `... --filter JSONValueTests` — expect `cannot find type 'JSONValue'` / `cannot find 'GMStore'`.

- [ ] **Step 4: Implement `JSONValue` (the any-JSON Codable enum).** Bool must decode before number so `true`/`false` don't collapse into `.number(1)`.

```swift
// /root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMStore.swift
import Foundation

/// A Codable representation of any JSON value. Backs GM stored values
/// (which are arbitrary JSON in Tampermonkey) and the document-start
/// snapshot the GM bootstrap injects.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            // Bool BEFORE Double: JSON `true` must not become .number(1).
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b):   try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a):  try c.encode(a)
        case .null:          try c.encodeNil()
        }
    }
}
```

- [ ] **Step 5: Implement `GMStore` (one `<scriptId>.gm.json` per script).** In-memory cache per loaded id; writes are atomic; the snapshot helpers feed the bootstrap.

```swift
// append to GMStore.swift

/// Per-script namespaced key/value store backing the GM_* storage APIs.
/// One file-backed JSON document per script id
/// (`<scriptId>.gm.json`) under Application Support / GMStore.
/// Pure filesystem — no WebKit/UIKit — so it unit-tests headless.
final class GMStore {
    private let directory: URL
    /// scriptId → loaded document. Lazily loaded on first access.
    private var cache: [String: [String: JSONValue]] = [:]

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.directory = dir
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GMStore", isDirectory: true)
    }

    private func fileURL(_ scriptId: String) -> URL {
        // Percent-encode the id so a UUID/string id is always a safe
        // filename; ids are our own UUIDs so this is belt-and-suspenders.
        let safe = scriptId.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics) ?? scriptId
        return directory.appendingPathComponent("\(safe).gm.json")
    }

    private func document(_ scriptId: String) -> [String: JSONValue] {
        if let d = cache[scriptId] { return d }
        let loaded: [String: JSONValue]
        if let data = try? Data(contentsOf: fileURL(scriptId)),
           let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            loaded = decoded
        } else {
            loaded = [:]
        }
        cache[scriptId] = loaded
        return loaded
    }

    private func write(_ scriptId: String, _ doc: [String: JSONValue]) throws {
        cache[scriptId] = doc
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(doc)
        try data.write(to: fileURL(scriptId), options: .atomic)
    }

    // MARK: - GM_* backend

    func get(scriptId: String, key: String) -> JSONValue? {
        document(scriptId)[key]
    }

    func set(scriptId: String, key: String, value: JSONValue) throws {
        var doc = document(scriptId)
        doc[key] = value
        try write(scriptId, doc)
    }

    func delete(scriptId: String, key: String) throws {
        var doc = document(scriptId)
        doc.removeValue(forKey: key)
        try write(scriptId, doc)
    }

    func listKeys(scriptId: String) -> [String] {
        Array(document(scriptId).keys)
    }

    // MARK: - Snapshot for the document-start bootstrap

    /// The whole document, for GM_getValue/GM_listValues synchronous reads.
    func snapshot(scriptId: String) -> [String: JSONValue] {
        document(scriptId)
    }

    /// The document serialized as a JSON object string the bootstrap can
    /// embed and `JSON.parse` at document-start.
    func snapshotJSON(scriptId: String) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(document(scriptId))
        return String(decoding: data, as: UTF8.self)
    }
}
```

- [ ] **Step 6: Re-run the tests and confirm GREEN.**
  Verification: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter GMStoreTests` and `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter JSONValueTests` — expect all methods passing.

- [ ] **Step 7: Confirm the file is in the build.** Same as Task 5 Step 6 — the `Warboard` target globs `WarboardIOS/Sources/WarboardIOS` in `/root/projects/warboard-ios/project.yml`, so `Userscripts/GMStore.swift` is included with no `project.yml` change. Verify on a Mac via `cd /root/projects/warboard-ios && xcodegen generate` + Xcode build. (Mac-only; the headless `swift test` in Step 6 already proves it compiles. `JSONValue` is reused by the GM bridge section — keep it in this file as the single source of truth.)

### Task 7: RequireCache — content-addressed cache for `@require` libs (pure, TDD)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/SHA256Pure.swift`
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/RequireCache.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/RequireCacheTests.swift`

`RequireCache` is the spec's pure unit-test seam (spec lines 126, 149: "A pure `RequireCache` key function (URL + hash → cache path)" / "`RequireCache` key stability"). It maps a `@require` URL to a stable on-disk path via `sha256(url)` and stores/reads the cached JS body. CryptoKit is unavailable on the headless Linux toolchain (verified: `no such module 'CryptoKit'`), so this task ships a dependency-free pure-Swift SHA-256 (verified bit-for-bit against `sha256sum`: `"abc"` → `ba7816bf…20015ad`) — keeping the whole cache layer runnable under `swift test` on Linux.

- [ ] **Step 1: Write the failing SHA-256 + key-stability test.**
  Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/RequireCacheTests.swift`. It won't compile yet (no `SHA256Pure`, no `RequireCache`) — that's the red state.
  ```swift
  import XCTest
  @testable import WarboardIOS

  final class RequireCacheTests: XCTestCase {

      // MARK: SHA-256 correctness (NIST/`sha256sum` vectors)

      func testSHA256KnownVectors() {
          XCTAssertEqual(
              SHA256Pure.hexDigest(Array("abc".utf8)),
              "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
          XCTAssertEqual(
              SHA256Pure.hexDigest([]),
              "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
          XCTAssertEqual(
              SHA256Pure.hexDigest(Array("https://cdnjs.cloudflare.com/socket.io.js".utf8)),
              "683ffc5f61dac222d780dd31d44ab20315c1e165b88f24297ca9bd79221a3240")
      }

      func testSHA256MultiBlockInput() {
          // 100-byte input crosses the 64-byte SHA block boundary; matches
          // `python3 -c "import hashlib; print(hashlib.sha256(b'a'*100).hexdigest())"`.
          let digest = SHA256Pure.hexDigest(Array(repeating: UInt8(ascii: "a"), count: 100))
          XCTAssertEqual(
              digest,
              "2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e")
      }

      // MARK: cache-key stability

      func testCacheKeyIsSha256OfURL() throws {
          let dir = try makeTempDir()
          defer { try? FileManager.default.removeItem(at: dir) }
          let cache = RequireCache(root: dir)
          let url = "https://cdnjs.cloudflare.com/socket.io.js"
          XCTAssertEqual(cache.key(forURL: url),
                         "683ffc5f61dac222d780dd31d44ab20315c1e165b88f24297ca9bd79221a3240")
          // Stable across calls and instances.
          XCTAssertEqual(RequireCache(root: dir).key(forURL: url),
                         cache.key(forURL: url))
      }

      func testPathForURLLivesUnderRootAndIsKeyed() throws {
          let dir = try makeTempDir()
          defer { try? FileManager.default.removeItem(at: dir) }
          let cache = RequireCache(root: dir)
          let url = "https://example.com/lib.js"
          let path = cache.path(forURL: url)
          XCTAssertEqual(path.deletingLastPathComponent().standardizedFileURL,
                         dir.standardizedFileURL)
          XCTAssertEqual(path.lastPathComponent, cache.key(forURL: url) + ".js")
      }

      // MARK: store / read round-trip

      func testStoreThenReadRoundTrips() throws {
          let dir = try makeTempDir()
          defer { try? FileManager.default.removeItem(at: dir) }
          let cache = RequireCache(root: dir)
          let url = "https://example.com/socket.io.js"
          let body = "var io = function(){ return {}; };"

          XCTAssertNil(cache.read(forURL: url))   // miss before store
          XCTAssertFalse(cache.isCached(forURL: url))

          try cache.store(body, forURL: url)

          XCTAssertTrue(cache.isCached(forURL: url))
          XCTAssertEqual(cache.read(forURL: url), body)
      }

      func testStoreCreatesRootDirectoryIfMissing() throws {
          let parent = try makeTempDir()
          defer { try? FileManager.default.removeItem(at: parent) }
          // Point the cache at a not-yet-existent subdirectory.
          let root = parent.appendingPathComponent("requires", isDirectory: true)
          let cache = RequireCache(root: root)
          try cache.store("x", forURL: "https://h/lib.js")
          XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
          XCTAssertEqual(cache.read(forURL: "https://h/lib.js"), "x")
      }

      func testRemoveDeletesEntry() throws {
          let dir = try makeTempDir()
          defer { try? FileManager.default.removeItem(at: dir) }
          let cache = RequireCache(root: dir)
          let url = "https://example.com/lib.js"
          try cache.store("body", forURL: url)
          XCTAssertTrue(cache.isCached(forURL: url))
          try cache.remove(forURL: url)
          XCTAssertFalse(cache.isCached(forURL: url))
          XCTAssertNil(cache.read(forURL: url))
      }

      // MARK: helpers

      private func makeTempDir() throws -> URL {
          let dir = FileManager.default.temporaryDirectory
              .appendingPathComponent("RequireCacheTests-\(UUID().uuidString)", isDirectory: true)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          return dir
      }
  }
  ```
  Confirm red (compile failure is the expected first failure):
  `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter RequireCacheTests` → fails to build (`cannot find 'SHA256Pure'` / `cannot find 'RequireCache'`).

- [ ] **Step 2: Add the dependency-free SHA-256.**
  Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/SHA256Pure.swift`. CryptoKit is iOS-only and absent from the Linux test toolchain, so this is a self-contained FIPS-180-4 implementation (verified against `sha256sum`). `String(format:)` requires Foundation.
  ```swift
  import Foundation

  /// Dependency-free SHA-256 (FIPS 180-4). Used for content-addressing
  /// `@require` cache entries. Deliberately avoids CryptoKit so the cache
  /// layer compiles and unit-tests under plain SwiftPM on Linux CI.
  enum SHA256Pure {
      private static let k: [UInt32] = [
          0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
          0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
          0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
          0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
          0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
          0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
          0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
          0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

      private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }

      /// Hex (lowercase) SHA-256 of the given bytes.
      static func hexDigest(_ bytes: [UInt8]) -> String {
          var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                             0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
          var msg = bytes
          let bitLen = UInt64(bytes.count) &* 8
          msg.append(0x80)
          while msg.count % 64 != 56 { msg.append(0) }
          for i in (0..<8).reversed() { msg.append(UInt8((bitLen >> (UInt64(i) &* 8)) & 0xff)) }

          var chunkStart = 0
          while chunkStart < msg.count {
              var w = [UInt32](repeating: 0, count: 64)
              for i in 0..<16 {
                  let j = chunkStart + i * 4
                  w[i] = (UInt32(msg[j]) << 24) | (UInt32(msg[j+1]) << 16)
                       | (UInt32(msg[j+2]) << 8) | UInt32(msg[j+3])
              }
              for i in 16..<64 {
                  let s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)
                  let s1 = rotr(w[i-2], 17) ^ rotr(w[i-2], 19) ^ (w[i-2] >> 10)
                  w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
              }
              var a = h[0], b = h[1], c = h[2], d = h[3]
              var e = h[4], f = h[5], g = h[6], hh = h[7]
              for i in 0..<64 {
                  let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                  let ch = (e & f) ^ (~e & g)
                  let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                  let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                  let maj = (a & b) ^ (a & c) ^ (b & c)
                  let t2 = s0 &+ maj
                  hh = g; g = f; f = e; e = d &+ t1
                  d = c; c = b; b = a; a = t1 &+ t2
              }
              h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
              h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
              chunkStart += 64
          }
          return h.map { String(format: "%08x", $0) }.joined()
      }

      /// Convenience: hex digest of a UTF-8 string.
      static func hexDigest(_ string: String) -> String {
          hexDigest(Array(string.utf8))
      }
  }
  ```

- [ ] **Step 3: Implement `RequireCache`.**
  Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/RequireCache.swift`. Filenames are `sha256(url).js` under `root`; store/read use UTF-8. `init(root:)` keeps it injectable so tests use a temp dir.
  ```swift
  import Foundation

  /// Content-addressed on-disk cache for `@require` library bodies.
  /// One file per `@require` URL, named `sha256(url).js` under `root`.
  /// Pure Foundation — no WebKit — so it unit-tests headlessly.
  struct RequireCache {
      let root: URL

      /// `root` is where cached `.js` files live. Defaults to
      /// Application Support/Userscripts/requires (created lazily on first store).
      init(root: URL) {
          self.root = root
      }

      static func defaultRoot() -> URL {
          let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                              in: .userDomainMask).first
              ?? FileManager.default.temporaryDirectory
          return base
              .appendingPathComponent("Userscripts", isDirectory: true)
              .appendingPathComponent("requires", isDirectory: true)
      }

      /// Stable cache key for a `@require` URL = lowercase hex SHA-256 of the URL string.
      func key(forURL url: String) -> String {
          SHA256Pure.hexDigest(url)
      }

      /// On-disk location for a URL's cached body.
      func path(forURL url: String) -> URL {
          root.appendingPathComponent(key(forURL: url) + ".js", isDirectory: false)
      }

      func isCached(forURL url: String) -> Bool {
          FileManager.default.fileExists(atPath: path(forURL: url).path)
      }

      /// Cached JS body for a URL, or nil on a miss / unreadable file.
      func read(forURL url: String) -> String? {
          let p = path(forURL: url)
          guard let data = try? Data(contentsOf: p) else { return nil }
          return String(decoding: data, as: UTF8.self)
      }

      /// Persist a library body, creating `root` if needed. Atomic write.
      func store(_ body: String, forURL url: String) throws {
          try FileManager.default.createDirectory(at: root,
                                                  withIntermediateDirectories: true)
          try Data(body.utf8).write(to: path(forURL: url), options: .atomic)
      }

      /// Drop a single entry (used on script update / cleanup). No-op if absent.
      func remove(forURL url: String) throws {
          let p = path(forURL: url)
          if FileManager.default.fileExists(atPath: p.path) {
              try FileManager.default.removeItem(at: p)
          }
      }
  }
  ```

- [ ] **Step 4: Go green.**
  `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter RequireCacheTests`
  Expect all 7 tests passing (`Executed 7 tests, with 0 failures`). This runs fully on the headless Linux server — no Mac/Xcode needed for this task.

---

### Task 8: RequireResolver — fetch `@require` libs on install/update, feed injection (TDD, injectable fetch)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/RequireResolver.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/RequireResolverTests.swift`

`RequireResolver` implements spec §3 (lines 90–94) and the error path (line 139): on install/update it fetches every `@require` URL and writes it to `RequireCache`; a fetch failure surfaces an error that **blocks enabling** the script. `injectionSources(for:)` reads the cache to produce the ordered `[String]` of lib bodies the injection pipeline (subsystem 1) prepends before a script body. The network is a single injectable `async` closure so the resolver is fully stubbed and headless-testable; production wires it to `URLSession`.

- [ ] **Step 1: Write the failing resolver test (stubbed fetch, temp cache).**
  Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/RequireResolverTests.swift`. Uses the shared `Userscript` model (subsystem 5). Won't compile yet (no `RequireResolver`, no `RequireError`) — red.
  ```swift
  import XCTest
  @testable import WarboardIOS

  final class RequireResolverTests: XCTestCase {

      // A Userscript with the two @require URLs factionops uses.
      private func script(requires: [String]) -> Userscript {
          Userscript(
              id: "test-\(UUID().uuidString)",
              name: "Test", namespace: "ns", version: "1.0.0", description: "",
              matches: ["https://www.torn.com/*"], includes: [], excludes: [],
              requires: requires, connects: [], grants: [],
              runAt: .documentIdle, icon: nil, downloadURL: nil, updateURL: nil,
              enabled: false, order: 0, source: "// body", wildcardConnectGranted: false)
      }

      private func makeTempCache() throws -> RequireCache {
          let dir = FileManager.default.temporaryDirectory
              .appendingPathComponent("RequireResolverTests-\(UUID().uuidString)", isDirectory: true)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          return RequireCache(root: dir)
      }

      func testResolveFetchesEachRequireAndWritesToCache() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          var requested: [String] = []
          let resolver = RequireResolver(cache: cache) { url in
              requested.append(url)
              return "/* body of \(url) */"
          }
          let s = script(requires: [
              "https://cdn/socket.io.js",
              "https://cdn/pako.js"])

          try await resolver.resolve(s)

          XCTAssertEqual(requested, ["https://cdn/socket.io.js", "https://cdn/pako.js"])
          XCTAssertEqual(cache.read(forURL: "https://cdn/socket.io.js"), "/* body of https://cdn/socket.io.js */")
          XCTAssertEqual(cache.read(forURL: "https://cdn/pako.js"), "/* body of https://cdn/pako.js */")
      }

      func testResolveSkipsAlreadyCachedURLs() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          try cache.store("cached", forURL: "https://cdn/socket.io.js")
          var fetched: [String] = []
          let resolver = RequireResolver(cache: cache) { url in
              fetched.append(url); return "fresh"
          }
          try await resolver.resolve(script(requires: ["https://cdn/socket.io.js"]))
          // Already cached → not re-fetched, body preserved.
          XCTAssertEqual(fetched, [])
          XCTAssertEqual(cache.read(forURL: "https://cdn/socket.io.js"), "cached")
      }

      func testForceRefetchOverwritesCacheOnUpdate() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          try cache.store("old", forURL: "https://cdn/lib.js")
          let resolver = RequireResolver(cache: cache) { _ in "new" }
          try await resolver.resolve(script(requires: ["https://cdn/lib.js"]),
                                     forceRefetch: true)
          XCTAssertEqual(cache.read(forURL: "https://cdn/lib.js"), "new")
      }

      func testFetchFailureThrowsRequireErrorAndBlocksEnable() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          struct Boom: Error {}
          let resolver = RequireResolver(cache: cache) { url in
              if url.contains("pako") { throw Boom() }
              return "ok"
          }
          let s = script(requires: ["https://cdn/socket.io.js", "https://cdn/pako.js"])

          do {
              try await resolver.resolve(s)
              XCTFail("expected resolve to throw")
          } catch let err as RequireResolver.RequireError {
              XCTAssertEqual(err.url, "https://cdn/pako.js")
          }
          // The good one may be cached, but the failing one must NOT be.
          XCTAssertFalse(cache.isCached(forURL: "https://cdn/pako.js"))
      }

      func testEmptyContentIsTreatedAsFailure() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          let resolver = RequireResolver(cache: cache) { _ in "   \n  " }
          do {
              try await resolver.resolve(script(requires: ["https://cdn/lib.js"]))
              XCTFail("expected empty body to throw")
          } catch let err as RequireResolver.RequireError {
              XCTAssertEqual(err.url, "https://cdn/lib.js")
          }
      }

      func testInjectionSourcesReturnsCachedBodiesInOrder() async throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          let resolver = RequireResolver(cache: cache) { url in "/* \(url) */" }
          let s = script(requires: ["https://cdn/a.js", "https://cdn/b.js"])
          try await resolver.resolve(s)
          XCTAssertEqual(resolver.injectionSources(for: s),
                         ["/* https://cdn/a.js */", "/* https://cdn/b.js */"])
      }

      func testInjectionSourcesThrowsIfRequireMissing() throws {
          let cache = try makeTempCache()
          defer { try? FileManager.default.removeItem(at: cache.root) }
          let resolver = RequireResolver(cache: cache) { _ in "x" }
          // Never resolved → cache miss → must surface (don't silently inject a script
          // without its lib).
          XCTAssertThrowsError(
              try resolver.injectionSourcesStrict(for: script(requires: ["https://cdn/missing.js"]))
          ) { error in
              guard let err = error as? RequireResolver.RequireError else {
                  return XCTFail("wrong error type")
              }
              XCTAssertEqual(err.url, "https://cdn/missing.js")
          }
      }
  }
  ```
  Confirm red: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter RequireResolverTests` → build failure (`cannot find 'RequireResolver'`).

- [ ] **Step 2: Implement `RequireResolver` with an injectable fetch closure.**
  Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/RequireResolver.swift`. The `Fetch` typealias is the seam; production passes a `URLSession`-backed closure (Step 3), tests pass a stub.
  ```swift
  import Foundation

  /// Resolves a userscript's `@require` libraries: on install/update, fetch
  /// each URL and write it to the `RequireCache`; injection then reads the
  /// cached bodies. A failed fetch throws `RequireError`, which the installer
  /// uses to block enabling the script (spec §3 / error handling).
  struct RequireResolver {

      /// Async fetch seam — returns the library's text body or throws.
      /// Production wires this to URLSession; tests stub it.
      typealias Fetch = (_ url: String) async throws -> String

      /// A `@require` that could not be made available. Carries the URL so the
      /// UI can show "couldn't load <url>" with a retry, and an underlying cause.
      struct RequireError: Error, Equatable {
          let url: String
          let reason: String
          static func == (lhs: RequireError, rhs: RequireError) -> Bool {
              lhs.url == rhs.url && lhs.reason == rhs.reason
          }
      }

      let cache: RequireCache
      private let fetch: Fetch

      init(cache: RequireCache, fetch: @escaping Fetch) {
          self.cache = cache
          self.fetch = fetch
      }

      /// Fetch + cache every `@require` for `script`. Cached entries are reused
      /// unless `forceRefetch` (set on script update). Throws `RequireError` on
      /// the first URL that fails — caller must NOT enable the script.
      func resolve(_ script: Userscript, forceRefetch: Bool = false) async throws {
          for url in script.requires {
              if !forceRefetch, cache.isCached(forURL: url) { continue }
              let body: String
              do {
                  body = try await fetch(url)
              } catch {
                  throw RequireError(url: url, reason: "\(error)")
              }
              guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                  throw RequireError(url: url, reason: "empty response")
              }
              do {
                  try cache.store(body, forURL: url)
              } catch {
                  throw RequireError(url: url, reason: "cache write failed: \(error)")
              }
          }
      }

      /// Cached lib bodies in `@require` order. Skips misses (best-effort) — use
      /// `injectionSourcesStrict` when a miss should abort injection.
      func injectionSources(for script: Userscript) -> [String] {
          script.requires.compactMap { cache.read(forURL: $0) }
      }

      /// Like `injectionSources` but throws `RequireError` on any miss, so the
      /// injection pipeline never runs a script body without its libraries.
      func injectionSourcesStrict(for script: Userscript) throws -> [String] {
          try script.requires.map { url in
              guard let body = cache.read(forURL: url) else {
                  throw RequireError(url: url, reason: "not cached")
              }
              return body
          }
      }
  }
  ```

- [ ] **Step 3: Add the production `URLSession` fetch factory (Mac/Xcode-verified only).**
  Append to the same file `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/RequireResolver.swift`. This is plain Foundation `URLSession` (no WebKit), but it makes a real network call, so it is **not** exercised by `swift test` — it is verified by the integration smoke (subsystem 6) and the live factionops/socket.io smoke (spec lines 152–154) on a Mac. The pure logic above is what the Linux tests cover.
  ```swift
  extension RequireResolver {
      /// Default resolver backed by URLSession. `@require` libs are plain GETs.
      static func live(cache: RequireCache,
                       session: URLSession = .shared) -> RequireResolver {
          RequireResolver(cache: cache) { urlString in
              guard let url = URL(string: urlString) else {
                  throw RequireError(url: urlString, reason: "invalid URL")
              }
              var request = URLRequest(url: url)
              request.setValue("warboard-ios", forHTTPHeaderField: "User-Agent")
              let (data, response) = try await session.data(for: request)
              if let http = response as? HTTPURLResponse,
                 !(200...299).contains(http.statusCode) {
                  throw RequireError(url: urlString, reason: "HTTP \(http.statusCode)")
              }
              return String(decoding: data, as: UTF8.self)
          }
      }
  }
  ```

- [ ] **Step 4: Go green on the pure logic.**
  `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter RequireResolverTests`
  Expect all 8 tests passing (`Executed 8 tests, with 0 failures`). The stubbed fetch closure means no network is touched, so this runs on the headless Linux server. The `RequireResolver.live(...)` factory's real `URLSession` path is **not** covered here — it is checked via Xcode build + the live factionops smoke on a Mac (spec §Testing), since this server can't run WKWebView/integration smokes.

- [ ] **Step 5: Whole-suite regression.**
  `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter RequireCacheTests && swift test --filter RequireResolverTests`
  Both green confirms Tasks 7–8 compose. Note the shared `Userscript` initializer used in these tests must match subsystem 5's field list exactly (`id, name, namespace, version, description, matches, includes, excludes, requires, connects, grants, runAt, icon, downloadURL, updateURL, enabled, order, source, wildcardConnectGranted`); if subsystem 5 lands a different memberwise signature, update the `script(...)` helper in `RequireResolverTests` accordingly.

### Task 9: GM connect-host allowlist check (pure)

The `@connect` enforcement is the one piece of `GM_xmlhttpRequest` that must be testable headless. It maps a request URL's host against the script's declared `@connect` hosts plus the always-allowed `*.torn.com` rule, and reports whether the request is allowed, blocked, or requires the one-time `*` consent prompt. Pure Swift, no WebKit.

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ConnectPolicy.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/ConnectPolicyTests.swift`

- [ ] **Step 1: Write the failing test for host matching, Torn allowlist, and wildcard consent.**
  Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/ConnectPolicyTests.swift`:
  ```swift
  import XCTest
  @testable import WarboardIOS

  final class ConnectPolicyTests: XCTestCase {

      // Tampermonkey @connect matches a host if the connect entry equals the
      // host OR is a domain suffix of it (e.g. "torn.com" allows "api.torn.com").
      func testExactAndSuffixMatch() {
          let policy = ConnectPolicy(connects: ["api.tornwar.com", "ffscouter.com"])
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://api.tornwar.com/v1/x")!),
                         .allowed)
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://ffscouter.com/a")!),
                         .allowed)
          // suffix: connect "ffscouter.com" also covers "www.ffscouter.com"
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://www.ffscouter.com/a")!),
                         .allowed)
      }

      func testSuffixDoesNotMatchUnrelatedHost() {
          let policy = ConnectPolicy(connects: ["torn.com"])
          // "eviltorn.com" is NOT a subdomain of "torn.com"
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://eviltorn.com/x")!),
                         .blocked)
      }

      func testTornAlwaysAllowedEvenWithoutConnect() {
          let policy = ConnectPolicy(connects: [])
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://www.torn.com/api")!),
                         .allowed)
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://api.torn.com/v2/x")!),
                         .allowed)
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://torn.com/")!),
                         .allowed)
      }

      func testWildcardNeedsConsentThenAllows() {
          let ungranted = ConnectPolicy(connects: ["*"], wildcardConnectGranted: false)
          XCTAssertEqual(ungranted.decision(forURL: URL(string: "https://anything.example/x")!),
                         .needsWildcardConsent)
          let granted = ConnectPolicy(connects: ["*"], wildcardConnectGranted: true)
          XCTAssertEqual(granted.decision(forURL: URL(string: "https://anything.example/x")!),
                         .allowed)
      }

      func testHostlessOrNonHTTPURLBlocked() {
          let policy = ConnectPolicy(connects: ["*"], wildcardConnectGranted: true)
          // file:// and data: have no usable host for an allowlist decision
          XCTAssertEqual(policy.decision(forURL: URL(string: "data:text/plain,hi")!),
                         .blocked)
      }

      func testCaseInsensitiveHost() {
          let policy = ConnectPolicy(connects: ["FFScouter.com"])
          XCTAssertEqual(policy.decision(forURL: URL(string: "https://FFSCOUTER.COM/a")!),
                         .allowed)
      }
  }
  ```
  Run (expect compile failure — `ConnectPolicy` does not exist yet):
  ```
  cd /root/projects/warboard-ios/WarboardIOS && swift test --filter ConnectPolicyTests
  ```

- [ ] **Step 2: Implement `ConnectPolicy` to make the test pass.**
  Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ConnectPolicy.swift`:
  ```swift
  import Foundation

  /// Pure `@connect` allowlist evaluator for `GM_xmlhttpRequest`.
  ///
  /// Mirrors Tampermonkey semantics: a `@connect` entry matches a request host
  /// if it equals the host or is a domain suffix of it; `*.torn.com` (same-origin
  /// to where the scripts live) is always permitted; `*` is honored only after a
  /// one-time per-script consent recorded on the `Userscript`.
  struct ConnectPolicy {
      enum Decision: Equatable {
          case allowed
          case blocked
          case needsWildcardConsent
      }

      let connects: [String]
      let wildcardConnectGranted: Bool

      init(connects: [String], wildcardConnectGranted: Bool = false) {
          self.connects = connects
          self.wildcardConnectGranted = wildcardConnectGranted
      }

      func decision(forURL url: URL) -> Decision {
          guard let scheme = url.scheme?.lowercased(),
                scheme == "http" || scheme == "https",
                let host = url.host?.lowercased(), !host.isEmpty else {
              return .blocked
          }

          // Same-origin to the script ecosystem — always allowed.
          if Self.hostMatches(host, suffix: "torn.com") {
              return .allowed
          }

          let entries = connects.map { $0.lowercased() }

          for entry in entries where entry != "*" {
              if Self.hostMatches(host, suffix: entry) {
                  return .allowed
              }
          }

          if entries.contains("*") {
              return wildcardConnectGranted ? .allowed : .needsWildcardConsent
          }

          return .blocked
      }

      /// True when `host` equals `suffix` or is a sub-domain of it.
      /// "api.torn.com" matches suffix "torn.com"; "eviltorn.com" does NOT.
      private static func hostMatches(_ host: String, suffix: String) -> Bool {
          if host == suffix { return true }
          return host.hasSuffix("." + suffix)
      }
  }
  ```

- [ ] **Step 3: Run the test green.**
  ```
  cd /root/projects/warboard-ios/WarboardIOS && swift test --filter ConnectPolicyTests
  ```
  All six cases pass. `GMBridge` (Task 12) consumes `ConnectPolicy` so the WebKit handler stays a thin shell over this pure logic.

---

### Task 10: Per-script GM storage snapshot JSON (pure)

`GM_getValue`/`GM_listValues` are synchronous in Tampermonkey. We satisfy that by injecting, at document-start, a JSON snapshot of the script's stored K/V into the bootstrap's per-script context. This task is the pure generator that turns a `GMStore` snapshot dictionary into the exact JSON literal embedded in the generated `WKUserScript` — testable headless, and the seam the injection pipeline (subsystem 5) calls.

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMSnapshot.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMSnapshotTests.swift`

- [ ] **Step 1: Write the failing test for snapshot JSON generation.**
  `GMStore` (built in another section) persists each value already JSON-encoded as a string (matching GM raw-string-coercion semantics — `GM_setValue("n", 5)` stores `"5"`, `GM_getValue` parses it). The snapshot generator takes the `[String: String]` of raw JSON-encoded values and emits a `{ "key": <rawJSON>, ... }` object literal that the bootstrap reads. Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMSnapshotTests.swift`:
  ```swift
  import XCTest
  @testable import WarboardIOS

  final class GMSnapshotTests: XCTestCase {

      private func parse(_ s: String) -> [String: Any] {
          let data = s.data(using: .utf8)!
          return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
      }

      func testEmptySnapshotIsEmptyObject() {
          XCTAssertEqual(GMSnapshot.objectLiteral(from: [:]), "{}")
      }

      func testScalarValuesArePreservedAsRawJSON() {
          // Stored values are already JSON-encoded strings, per GMStore.
          let raw = ["count": "5", "ratio": "1.5", "on": "true", "nothing": "null"]
          let obj = parse(GMSnapshot.objectLiteral(from: raw))
          XCTAssertEqual(obj["count"] as? Int, 5)
          XCTAssertEqual(obj["ratio"] as? Double, 1.5)
          XCTAssertEqual(obj["on"] as? Bool, true)
          XCTAssertTrue(obj["nothing"] is NSNull)
      }

      func testStringValueRoundTrips() {
          // A GM string value "hi" is stored as the JSON string "\"hi\"".
          let raw = ["greeting": "\"hi\""]
          let obj = parse(GMSnapshot.objectLiteral(from: raw))
          XCTAssertEqual(obj["greeting"] as? String, "hi")
      }

      func testObjectValueRoundTrips() {
          let raw = ["cfg": "{\"a\":1,\"b\":[2,3]}"]
          let obj = parse(GMSnapshot.objectLiteral(from: raw))
          let cfg = obj["cfg"] as? [String: Any]
          XCTAssertEqual(cfg?["a"] as? Int, 1)
          XCTAssertEqual((cfg?["b"] as? [Any])?.count, 2)
      }

      func testKeysWithQuotesAndUnicodeAreEscaped() {
          let raw = ["wei\"rd": "1", "ключ": "2"]
          let s = GMSnapshot.objectLiteral(from: raw)
          // Must be valid JSON that re-parses to the same keys.
          let obj = parse(s)
          XCTAssertEqual(obj["wei\"rd"] as? Int, 1)
          XCTAssertEqual(obj["ключ"] as? Int, 2)
      }

      func testCorruptStoredValueFallsBackToJSONNull() {
          // If a stored value isn't valid JSON, emit null rather than break the literal.
          let raw = ["bad": "not json {{"]
          let obj = parse(GMSnapshot.objectLiteral(from: raw))
          XCTAssertTrue(obj["bad"] is NSNull)
      }

      func testDeterministicKeyOrdering() {
          let raw = ["b": "1", "a": "2", "c": "3"]
          // Sorted keys → stable output (snapshot diffs / test stability).
          XCTAssertEqual(GMSnapshot.objectLiteral(from: raw),
                         "{\"a\":2,\"b\":1,\"c\":3}")
      }
  }
  ```
  Run (expect compile failure — no `GMSnapshot`):
  ```
  cd /root/projects/warboard-ios/WarboardIOS && swift test --filter GMSnapshotTests
  ```

- [ ] **Step 2: Implement `GMSnapshot.objectLiteral(from:)`.**
  We can't use `JSONSerialization` on the outer object directly because the *values* are already-encoded JSON fragments (not Swift values). We build the literal by hand: JSON-escape each key, validate each raw value is parseable (else `null`), and join. Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMSnapshot.swift`:
  ```swift
  import Foundation

  /// Generates the document-start storage snapshot embedded into the GM
  /// bootstrap so `GM_getValue` / `GM_listValues` can read synchronously.
  ///
  /// Input is a `[scriptKey: rawJSONEncodedValue]` map as persisted by `GMStore`
  /// (every value is already a valid JSON fragment string, e.g. `"5"`, `"\"hi\""`,
  /// `"{\"a\":1}"`). Output is a JSON object literal whose values are those
  /// fragments spliced in verbatim, so the bootstrap parses it once into a plain
  /// JS object.
  enum GMSnapshot {
      static func objectLiteral(from rawValues: [String: String]) -> String {
          if rawValues.isEmpty { return "{}" }
          var parts: [String] = []
          parts.reserveCapacity(rawValues.count)
          for key in rawValues.keys.sorted() {
              let raw = rawValues[key]!
              let encodedKey = encodeJSONString(key)
              let value = isValidJSONFragment(raw) ? raw : "null"
              parts.append("\(encodedKey):\(value)")
          }
          return "{" + parts.joined(separator: ",") + "}"
      }

      /// JSON-encode a Swift string into a quoted JSON string literal.
      private static func encodeJSONString(_ s: String) -> String {
          // Encode as a one-element array then strip the brackets — guarantees
          // RFC-correct escaping (quotes, backslashes, control chars, unicode).
          guard let data = try? JSONSerialization.data(withJSONObject: [s]),
                let arr = String(data: data, encoding: .utf8) else {
              return "\"\""
          }
          // arr == "[\"...\"]" → drop the outer [ and ].
          return String(arr.dropFirst().dropLast())
      }

      /// True if `raw` parses as a standalone JSON value.
      private static func isValidJSONFragment(_ raw: String) -> Bool {
          guard let data = raw.data(using: .utf8) else { return false }
          // .fragmentsAllowed lets bare scalars (5, true, "x", null) validate.
          return (try? JSONSerialization.jsonObject(
              with: data, options: [.fragmentsAllowed])) != nil
      }
  }
  ```

- [ ] **Step 3: Run green.**
  ```
  cd /root/projects/warboard-ios/WarboardIOS && swift test --filter GMSnapshotTests
  ```
  Both pure tasks (Task 9, 10) are now independently verified on Linux. The remaining GM-bridge tasks touch WebKit and are Mac-only.

---

### Task 11: GM bootstrap JavaScript (embedded resource)

The bootstrap is the in-page half of the bridge: a single JS string injected at document-start in the **main world** per matching script. It defines the synchronous and async `GM_*` functions, `GM_info`, `unsafeWindow`, and reads the per-script snapshot. It is parameterized by two tokens the native side substitutes per script: `__WB_SCRIPT_CONTEXT__` (a JSON object with the script id, `GM_info` metadata, and the storage snapshot) — so the *same* bootstrap source serves every script, only the prepended context differs.

This is JS, not Swift — it can't run under `swift test`. It is verified by the integration smoke (Task 13) on a Mac. We still lint it for syntax headless with `node --check`.

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/Resources/gm-bootstrap.js`
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMBootstrap.swift`

- [ ] **Step 1: Write `gm-bootstrap.js`.**
  The native side prepends `var __WB_SCRIPT_CONTEXT__ = { ... };` (see Task 12, Step 2) before this body, so the IIFE below closes over it. All async calls go through `window.webkit.messageHandlers.gmBridge` (a `WKScriptMessageHandlerWithReply`, which returns a Promise from `postMessage`). Synchronous reads hit the injected snapshot. Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/Resources/gm-bootstrap.js`:
  ```javascript
  (function () {
    "use strict";

    var ctx = (typeof __WB_SCRIPT_CONTEXT__ !== "undefined")
      ? __WB_SCRIPT_CONTEXT__ : { scriptId: "", info: {}, store: {} };

    var SCRIPT_ID = ctx.scriptId;
    var store = ctx.store || {};        // synchronous snapshot, mutated on write
    var menuCommands = [];              // {name, callback} registered this page
    var bridge = (window.webkit
      && window.webkit.messageHandlers
      && window.webkit.messageHandlers.gmBridge) || null;

    function post(action, payload) {
      if (!bridge) {
        return Promise.reject(new Error("GM bridge unavailable"));
      }
      return bridge.postMessage({
        scriptId: SCRIPT_ID,
        action: action,
        payload: payload || {}
      });
    }

    // ---- synchronous storage (reads the document-start snapshot) ----
    function GM_getValue(key, defaultValue) {
      return Object.prototype.hasOwnProperty.call(store, key)
        ? store[key]
        : defaultValue;
    }
    function GM_listValues() {
      return Object.keys(store);
    }

    // ---- async storage (write-through to native + update snapshot) ----
    function GM_setValue(key, value) {
      store[key] = value;             // keep sync reads consistent immediately
      return post("setValue", { key: key, value: value });
    }
    function GM_deleteValue(key) {
      delete store[key];
      return post("deleteValue", { key: key });
    }

    // ---- GM_xmlhttpRequest: native URLSession proxy with @connect enforcement
    function GM_xmlhttpRequest(details) {
      var d = details || {};
      var control = { abort: function () {} };
      post("xmlhttpRequest", {
        method: d.method || "GET",
        url: d.url,
        headers: d.headers || {},
        data: d.data != null ? String(d.data) : null,
        responseType: d.responseType || "",
        timeout: d.timeout || 0
      }).then(function (res) {
        // res: {status, statusText, responseHeaders, responseText, finalUrl}
        if (res && res.status >= 200 && res.status < 400) {
          if (typeof d.onload === "function") d.onload(res);
        } else {
          if (typeof d.onerror === "function") d.onerror(res || { error: "request failed" });
        }
      }).catch(function (err) {
        if (typeof d.onerror === "function") {
          d.onerror({ error: (err && err.message) || "request failed" });
        }
      });
      return control;
    }

    // ---- clipboard / tabs ----
    function GM_setClipboard(text, info) {
      return post("setClipboard", { text: String(text), type: (info && info.type) || "text" });
    }
    function GM_openInTab(url, options) {
      var opts = (typeof options === "boolean") ? { active: !options } : (options || {});
      post("openInTab", { url: url, active: opts.active !== false });
      return { close: function () {} };
    }

    // ---- styles ----
    function GM_addStyle(css) {
      var style = document.createElement("style");
      style.textContent = css;
      (document.head || document.documentElement).appendChild(style);
      return style;
    }

    // ---- menu commands (surfaced in the native script-actions sheet) ----
    function GM_registerMenuCommand(name, callback) {
      var id = menuCommands.length;
      menuCommands.push({ name: name, callback: callback });
      post("registerMenuCommand", { name: name, id: id });
      return id;
    }
    function GM_unregisterMenuCommand(id) {
      if (menuCommands[id]) menuCommands[id] = null;
    }

    // Native invokes a menu command by id via injected JS (Task 12, Step 4).
    window.__wbInvokeMenuCommand = function (id) {
      var cmd = menuCommands[id];
      if (cmd && typeof cmd.callback === "function") cmd.callback();
    };

    var GM_info = ctx.info || {};

    // ---- expose into the page (main world: unsafeWindow === window) ----
    var w = window;
    w.unsafeWindow = w;
    w.GM_getValue = GM_getValue;
    w.GM_setValue = GM_setValue;
    w.GM_deleteValue = GM_deleteValue;
    w.GM_listValues = GM_listValues;
    w.GM_xmlhttpRequest = GM_xmlhttpRequest;
    w.GM_setClipboard = GM_setClipboard;
    w.GM_openInTab = GM_openInTab;
    w.GM_addStyle = GM_addStyle;
    w.GM_registerMenuCommand = GM_registerMenuCommand;
    w.GM_unregisterMenuCommand = GM_unregisterMenuCommand;
    w.GM_info = GM_info;

    // Promise-style GM.* aliases for scripts that use the modern API.
    w.GM = {
      getValue: function (k, d) { return Promise.resolve(GM_getValue(k, d)); },
      setValue: GM_setValue,
      deleteValue: GM_deleteValue,
      listValues: function () { return Promise.resolve(GM_listValues()); },
      xmlHttpRequest: GM_xmlhttpRequest,
      setClipboard: GM_setClipboard,
      openInTab: GM_openInTab,
      addStyle: GM_addStyle,
      registerMenuCommand: GM_registerMenuCommand,
      info: GM_info
    };
  })();
  ```

- [ ] **Step 2: Syntax-check the bootstrap headless.**
  `node --check` validates JS syntax without a browser (the `window`/`webkit` references are fine — `--check` parses, doesn't execute):
  ```
  node --check /root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/Resources/gm-bootstrap.js && echo "bootstrap OK"
  ```
  Expect `bootstrap OK`.

- [ ] **Step 3: Add the bootstrap loader `GMBootstrap.swift`.**
  The injection pipeline needs the bootstrap text plus the snapshot prefix. Load the `.js` from the app bundle (xcodegen copies `Resources/` into the bundle — see project.yml change in Step 4) and expose a builder that prepends the per-script context. Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMBootstrap.swift`:
  ```swift
  import Foundation

  /// Loads `gm-bootstrap.js` and builds the per-script document-start
  /// `WKUserScript` source by prepending a `__WB_SCRIPT_CONTEXT__` literal.
  enum GMBootstrap {
      /// Cached bootstrap body, loaded once from the bundle.
      static let body: String = {
          guard let url = Bundle.main.url(forResource: "gm-bootstrap",
                                          withExtension: "js"),
                let text = try? String(contentsOf: url, encoding: .utf8) else {
              assertionFailure("gm-bootstrap.js missing from bundle")
              return ""
          }
          return text
      }()

      /// Full main-world document-start source for one script:
      /// `var __WB_SCRIPT_CONTEXT__ = {...}; <bootstrap>`.
      /// - Parameters:
      ///   - scriptID: the `Userscript.id`.
      ///   - infoJSON: `GM_info` object literal (Task 12, Step 2).
      ///   - snapshotLiteral: storage snapshot from `GMSnapshot.objectLiteral`.
      static func source(scriptID: String,
                         infoJSON: String,
                         snapshotLiteral: String) -> String {
          let idLiteral = jsString(scriptID)
          let context = "var __WB_SCRIPT_CONTEXT__ = {"
              + "scriptId:\(idLiteral),"
              + "info:\(infoJSON),"
              + "store:\(snapshotLiteral)"
              + "};\n"
          return context + body
      }

      /// JSON-escape a Swift string into a JS string literal.
      static func jsString(_ s: String) -> String {
          guard let data = try? JSONSerialization.data(withJSONObject: [s]),
                let arr = String(data: data, encoding: .utf8) else { return "\"\"" }
          return String(arr.dropFirst().dropLast())
      }
  }
  ```

- [ ] **Step 4: Register the Resources directory in `project.yml` so xcodegen bundles the JS.**
  Modify `/root/projects/warboard-ios/project.yml` — add the Userscripts resources under the iOS app target's `sources` (xcodegen treats a `.js` file as a resource and copies it into the bundle; listing the directory is enough). After the `Assets.xcassets` line in the app target sources block:
  ```yaml
      - path: WarboardIOS/Sources/WarboardIOS
      - path: WarboardIOS/Sources/Shared
      - path: WarboardIOS/AppIcon/Assets.xcassets
      # Userscript engine resources (GM bootstrap JS, document-idle shim).
      # xcodegen copies non-source files into the app bundle so
      # Bundle.main.url(forResource:withExtension:) can load them at runtime.
      - path: WarboardIOS/Sources/WarboardIOS/Userscripts/Resources
        buildPhase: resources
  ```
  Since the whole `Sources/WarboardIOS` tree is already a `sources` path, the `.swift` files under `Userscripts/` compile automatically; the explicit `Resources` entry with `buildPhase: resources` ensures the `.js` isn't mistaken for a compile input.

- [ ] **Step 5: Verify project generation + that the resource is in the Copy Bundle Resources phase (Mac only).**
  This requires `xcodegen` (Mac/CI), so it is **not runnable on this Linux server**. On a Mac:
  ```
  cd /root/projects/warboard-ios && xcodegen generate
  # then confirm the file is a bundled resource, not a compile input:
  grep -A2 "gm-bootstrap.js" Warboard.xcodeproj/project.pbxproj | grep -i "Resources"
  ```
  Expect the file to appear under a `Resources` build phase. The runtime load path (`Bundle.main.url`) is exercised by the integration smoke (Task 13).

---

### Task 12: Native `GMBridge` / `GMMessageHandler` (WebKit reply handler)

The native counterpart: a `WKScriptMessageHandlerWithReply` registered as `gmBridge` on the `userContentController`. It dispatches the bootstrap's `post(action, payload)` messages to `GMStore` (storage), `ConnectPolicy` + `URLSession` (`xmlhttpRequest`), `UIPasteboard` (clipboard), and the browser tab (`openInTab`), returning a `WKScriptMessage` reply (which becomes the JS Promise resolution). It is WebKit/UIKit-bound — **not runnable under `swift test` on Linux**; verified by Xcode build + the Task 13 smoke. The two pure dependencies it calls (`ConnectPolicy`, `GMSnapshot`) are already green from Tasks 9–10.

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMBridge.swift`

- [ ] **Step 1: Define the handler skeleton and per-script context.**
  The bridge holds a map from `scriptId` to the live `Userscript` (so it can read `connects`/`wildcardConnectGranted` and look up the `GMStore`). `UserscriptController` (another section) owns the bridge and updates `activeScripts` on each navigation. Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/GMBridge.swift`:
  ```swift
  import Foundation
  import WebKit
  #if canImport(UIKit)
  import UIKit
  #endif

  /// Native side of the GM bridge. Registered as the `gmBridge`
  /// `WKScriptMessageHandlerWithReply`; routes bootstrap messages to native
  /// privileged operations and replies with the JS Promise resolution.
  final class GMBridge: NSObject, WKScriptMessageHandlerWithReply {

      /// Per-script state the bridge needs, keyed by `Userscript.id`.
      struct ScriptContext {
          let connects: [String]
          let wildcardConnectGranted: Bool
          let store: GMStore
      }

      /// Maintained by `UserscriptController` on every navigation rebuild.
      var activeScripts: [String: ScriptContext] = [:]

      /// Callbacks into the app shell (wired by `UserscriptController`).
      var onOpenInTab: ((URL, Bool) -> Void)?
      var onRequestWildcardConsent: ((_ scriptID: String,
                                      _ completion: @escaping (Bool) -> Void) -> Void)?
      var onRegisterMenuCommand: ((_ scriptID: String, _ name: String, _ id: Int) -> Void)?

      private let session: URLSession

      init(session: URLSession = .shared) {
          self.session = session
          super.init()
      }
  ```

- [ ] **Step 2: Add the `GM_info` literal builder (used by the injection pipeline).**
  `GM_info` exposes the script + engine metadata to the bootstrap. Keep this on the bridge so the field set lives next to the handler that documents the contract. Append inside the class:
  ```swift
      /// Build the `GM_info` object literal for a script (spliced into
      /// `__WB_SCRIPT_CONTEXT__.info` by `GMBootstrap.source`).
      static func infoJSON(for script: Userscript, engineVersion: String) -> String {
          let info: [String: Any] = [
              "script": [
                  "name": script.name,
                  "namespace": script.namespace,
                  "version": script.version,
                  "description": script.description,
                  "matches": script.matches,
                  "includes": script.includes,
                  "excludes": script.excludes,
                  "runAt": script.runAt.gmInfoValue,
                  "grant": script.grants
              ] as [String: Any],
              "scriptHandler": "WarboardIOS",
              "version": engineVersion,
              "scriptMetaStr": script.source.userScriptMetaBlock ?? ""
          ]
          guard let data = try? JSONSerialization.data(withJSONObject: info),
                let s = String(data: data, encoding: .utf8) else { return "{}" }
          return s
      }
  ```
  `runAt.gmInfoValue` is a small computed property on the `RunAt` enum (`.documentStart` → `"document-start"`, etc.); `userScriptMetaBlock` slices the `// ==UserScript== … // ==/UserScript==` substring out of `source`. Both are added here if the model section hasn't:
  ```swift
  extension Userscript.RunAt {
      var gmInfoValue: String {
          switch self {
          case .documentStart: return "document-start"
          case .documentEnd:   return "document-end"
          case .documentIdle:  return "document-idle"
          }
      }
  }

  private extension String {
      var userScriptMetaBlock: String? {
          guard let start = range(of: "// ==UserScript=="),
                let end = range(of: "// ==/UserScript==") else { return nil }
          return String(self[start.lowerBound..<end.upperBound])
      }
  }
  ```

- [ ] **Step 3: Implement message dispatch.**
  Append the `WKScriptMessageHandlerWithReply` conformance:
  ```swift
      func userContentController(_ controller: WKUserContentController,
                                 didReceive message: WKScriptMessage,
                                 replyHandler: @escaping (Any?, String?) -> Void) {
          guard let body = message.body as? [String: Any],
                let scriptID = body["scriptId"] as? String,
                let action = body["action"] as? String,
                let ctx = activeScripts[scriptID] else {
              replyHandler(nil, "no active script context")   // spec: ignore/log
              return
          }
          let payload = body["payload"] as? [String: Any] ?? [:]

          switch action {
          case "setValue":
              if let key = payload["key"] as? String {
                  ctx.store.set(key, jsonValue: payload["value"])
              }
              replyHandler(nil, nil)

          case "deleteValue":
              if let key = payload["key"] as? String { ctx.store.delete(key) }
              replyHandler(nil, nil)

          case "xmlhttpRequest":
              performXHR(payload: payload, scriptID: scriptID, ctx: ctx,
                         replyHandler: replyHandler)

          case "setClipboard":
              #if canImport(UIKit)
              UIPasteboard.general.string = payload["text"] as? String ?? ""
              #endif
              replyHandler(nil, nil)

          case "openInTab":
              if let urlStr = payload["url"] as? String, let url = URL(string: urlStr) {
                  let active = (payload["active"] as? Bool) ?? true
                  DispatchQueue.main.async { self.onOpenInTab?(url, active) }
              }
              replyHandler(nil, nil)

          case "registerMenuCommand":
              if let name = payload["name"] as? String,
                 let id = payload["id"] as? Int {
                  DispatchQueue.main.async {
                      self.onRegisterMenuCommand?(scriptID, name, id)
                  }
              }
              replyHandler(nil, nil)

          default:
              replyHandler(nil, "unknown action: \(action)")
          }
      }
  ```

- [ ] **Step 4: Implement `performXHR` with `@connect` enforcement via `ConnectPolicy`.**
  Reuse the pure `ConnectPolicy` (Task 9). On `.needsWildcardConsent`, fire the consent callback; on grant, persist the flag and retry once. Append:
  ```swift
      private func performXHR(payload: [String: Any],
                              scriptID: String,
                              ctx: ScriptContext,
                              replyHandler: @escaping (Any?, String?) -> Void) {
          guard let urlStr = payload["url"] as? String, let url = URL(string: urlStr) else {
              replyHandler(nil, "invalid url"); return
          }
          let policy = ConnectPolicy(connects: ctx.connects,
                                     wildcardConnectGranted: ctx.wildcardConnectGranted)
          switch policy.decision(forURL: url) {
          case .blocked:
              replyHandler(nil, "blocked by @connect: \(url.host ?? "?")")
          case .needsWildcardConsent:
              guard let ask = onRequestWildcardConsent else {
                  replyHandler(nil, "wildcard @connect not granted"); return
              }
              DispatchQueue.main.async {
                  ask(scriptID) { granted in
                      guard granted else {
                          replyHandler(nil, "wildcard @connect denied"); return
                      }
                      // Caller (UserscriptController) persists the flag + refreshes
                      // activeScripts; re-dispatch with the now-granted context.
                      var newCtx = ctx
                      newCtx = ScriptContext(connects: ctx.connects,
                                             wildcardConnectGranted: true,
                                             store: ctx.store)
                      self.sendXHR(payload: payload, url: url, replyHandler: replyHandler)
                      self.activeScripts[scriptID] = newCtx
                  }
              }
          case .allowed:
              sendXHR(payload: payload, url: url, replyHandler: replyHandler)
          }
      }

      private func sendXHR(payload: [String: Any], url: URL,
                           replyHandler: @escaping (Any?, String?) -> Void) {
          var req = URLRequest(url: url)
          req.httpMethod = (payload["method"] as? String) ?? "GET"
          if let headers = payload["headers"] as? [String: String] {
              for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
          }
          if let data = payload["data"] as? String, !data.isEmpty {
              req.httpBody = data.data(using: .utf8)
          }
          if let timeout = payload["timeout"] as? Double, timeout > 0 {
              req.timeoutInterval = timeout / 1000.0
          }
          session.dataTask(with: req) { data, response, error in
              if let error = error {
                  replyHandler(["error": error.localizedDescription], nil)
                  return
              }
              let http = response as? HTTPURLResponse
              var headerMap: [String: String] = [:]
              http?.allHeaderFields.forEach { k, v in
                  headerMap["\(k)"] = "\(v)"
              }
              let result: [String: Any] = [
                  "status": http?.statusCode ?? 0,
                  "statusText": HTTPURLResponse.localizedString(
                      forStatusCode: http?.statusCode ?? 0),
                  "responseHeaders": headerMap,
                  "responseText": data.flatMap { String(data: $0, encoding: .utf8) } ?? "",
                  "finalUrl": (http?.url ?? url).absoluteString
              ]
              replyHandler(result, nil)
          }.resume()
      }
  }
  ```
  `GMStore.set(_:jsonValue:)` / `.delete(_:)` are the methods the storage section exposes; if it instead takes raw JSON strings, swap `ctx.store.set(key, jsonValue:)` for re-encoding the payload value with `JSONSerialization` first. Flag this as the one cross-section coupling to confirm with the `GMStore` author.

- [ ] **Step 5: Build-verify (Mac only — not headless).**
  `GMBridge` imports `WebKit`/`UIKit`, which are unavailable on this Linux server, so there is **no `swift test` command for this task**. On a Mac/CI:
  ```
  cd /root/projects/warboard-ios && xcodegen generate \
    && xcodebuild -project Warboard.xcodeproj -scheme Warboard \
       -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
  ```
  Expect a clean build. Runtime behavior is covered by Task 13.

---

### Task 13: WKWebView round-trip integration smoke (Mac/CI only)

End-to-end proof that the bootstrap + bridge wire up correctly: load a fixture page in a real `WKWebView`, register the `gmBridge` handler, inject `GMBootstrap.source(...)`, and assert the GM surface behaves. **This uses `WKWebView`, which has no headless implementation on Linux** — it is documented here and runs only on a Mac (or CI macOS runner). It is the spec's required integration test.

**Files:**
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMBridgeIntegrationTests.swift`

- [ ] **Step 1: Write the integration test (guarded so the test target still compiles on Linux).**
  Wrap the body in `#if canImport(WebKit)` so `swift test` on Linux compiles (skips) the file rather than failing to import `WebKit`. Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/GMBridgeIntegrationTests.swift`:
  ```swift
  import XCTest
  @testable import WarboardIOS

  #if canImport(WebKit)
  import WebKit

  /// Mac-only: exercises the real bootstrap + GMBridge through a WKWebView.
  /// Cannot run on the Linux CI box (no WebKit); runs on macOS via xcodebuild test.
  final class GMBridgeIntegrationTests: XCTestCase {

      private func makeWebView(bridge: GMBridge,
                               bootstrapSource: String) -> WKWebView {
          let cfg = WKWebViewConfiguration()
          let ucc = cfg.userContentController
          ucc.addScriptMessageHandler(bridge, contentWorld: .page, name: "gmBridge")
          ucc.addUserScript(WKUserScript(source: bootstrapSource,
                                         injectionTime: .atDocumentStart,
                                         forMainFrameOnly: true,
                                         in: .page))
          return WKWebView(frame: .zero, configuration: cfg)
      }

      func testSyncSetThenGetRoundTrip() throws {
          let store = GMStore(scriptID: "smoke")
          let bridge = GMBridge()
          bridge.activeScripts["smoke"] = .init(connects: [],
                                                wildcardConnectGranted: false,
                                                store: store)
          let source = GMBootstrap.source(
              scriptID: "smoke",
              infoJSON: GMBridge.infoJSON(for: .fixture(id: "smoke"),
                                          engineVersion: "1.0"),
              snapshotLiteral: GMSnapshot.objectLiteral(from: store.rawSnapshot()))
          let web = makeWebView(bridge: bridge, bootstrapSource: source)

          let loaded = expectation(description: "loaded")
          let nav = NavWaiter { loaded.fulfill() }
          web.navigationDelegate = nav
          web.loadHTMLString("<html><body>hi</body></html>",
                             baseURL: URL(string: "https://www.torn.com/"))
          wait(for: [loaded], timeout: 5)

          // GM_setValue then synchronous GM_getValue in the same page.
          let eval = expectation(description: "eval")
          web.evaluateJavaScript(
              "GM_setValue('k', 42); GM_getValue('k', 0)") { result, _ in
              XCTAssertEqual(result as? Int, 42)
              eval.fulfill()
          }
          wait(for: [eval], timeout: 5)
      }

      func testUnsafeWindowIsWindow() throws {
          let bridge = GMBridge()
          bridge.activeScripts["smoke"] = .init(connects: [], wildcardConnectGranted: false,
                                                store: GMStore(scriptID: "smoke"))
          let source = GMBootstrap.source(scriptID: "smoke", infoJSON: "{}",
                                          snapshotLiteral: "{}")
          let web = makeWebView(bridge: bridge, bootstrapSource: source)
          let loaded = expectation(description: "loaded")
          let nav = NavWaiter { loaded.fulfill() }
          web.navigationDelegate = nav
          web.loadHTMLString("<html><body></body></html>",
                             baseURL: URL(string: "https://www.torn.com/"))
          wait(for: [loaded], timeout: 5)

          let eval = expectation(description: "eval")
          web.evaluateJavaScript("unsafeWindow === window") { result, _ in
              XCTAssertEqual(result as? Bool, true)
              eval.fulfill()
          }
          wait(for: [eval], timeout: 5)
      }

      private final class NavWaiter: NSObject, WKNavigationDelegate {
          let onFinish: () -> Void
          init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
          func webView(_ w: WKWebView, didFinish n: WKNavigation!) { onFinish() }
      }
  }
  #endif
  ```
  `.fixture(id:)` is a tiny `Userscript` test factory and `GMStore.rawSnapshot()` returns the `[String: String]` raw map `GMSnapshot` consumes — both defined by their owning sections; if absent, add a one-line `Userscript` literal inline here.

- [ ] **Step 2: Confirm the file compiles (skips) on Linux.**
  The `#if canImport(WebKit)` guard means the WebKit tests vanish on Linux, so the pure test target still builds:
  ```
  cd /root/projects/warboard-ios/WarboardIOS && swift test --filter GMBridgeIntegrationTests
  ```
  Expect "executed 0 tests" (or a no-such-test notice) on Linux — **not** a build failure. This proves the guard is correct.

- [ ] **Step 3: Run the real smoke on a Mac/CI macOS runner.**
  **Not possible on this Linux server.** On macOS:
  ```
  cd /root/projects/warboard-ios && xcodegen generate \
    && xcodebuild test -project Warboard.xcodeproj -scheme Warboard \
       -destination 'platform=iOS Simulator,name=iPhone 15' \
       -only-testing:WarboardIOSTests/GMBridgeIntegrationTests
  ```
  Expect both `testSyncSetThenGetRoundTrip` and `testUnsafeWindowIsWindow` green. Pair this with the spec's live two-script smoke (factionops `@require socket.io` + `GM_xmlhttpRequest`; foreign-stock `GM_getValue/setValue` + `@connect`) run manually in the Browser tab before declaring the bridge done.

### Task 14: Pure payload-planner — failing XCTest for `UserscriptInjectionPlanner.plan(for:scripts:requireSources:)`

The live `WKWebView` wiring can't run headless on this Linux server, so we split the engine into a **pure** payload planner (testable with `swift test`) and the WebKit glue (Task 16, smoke-only). This task adds the planner's failing test.

The planner takes a destination `URL`, the **already-filtered, install-order-sorted** list of enabled matching `Userscript`s (filtering is `ScriptRegistry`+`MatchMatcher`, owned by other sections), and a `requireSources` lookup (`[String: String]` mapping a `@require` URL to its cached JS — produced by `RequireResolver`/`RequireCache`), and returns an **ordered** `[PlannedUserScript]` where each element is the exact payload WebKit will inject: `{ source, injectionTime, mainFrameOnly }`. This is the seam the spec calls "selecting+ordering the WKUserScript payload list for a given URL".

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptInjectionPlanner.swift` (types only this task; `plan` body stubbed to fail)
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/UserscriptInjectionPlannerTests.swift`

- [ ] **Step 1: Define the pure payload value type + injection-time enum (no WebKit import).** Create the file with the model the test compiles against. `WKUserScriptInjectionTime` is a WebKit type and can't be referenced on Linux, so the planner uses a platform-free mirror `InjectionTiming` and the WebKit glue (Task 16) maps it. Write `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptInjectionPlanner.swift`:

  ```swift
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
      static func timing(for runAt: Userscript.RunAt) -> InjectionTiming {
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
          fatalError("not implemented")
      }
  }
  ```

  NOTE: this references `Userscript.RunAt` with cases `.documentStart/.documentEnd/.documentIdle` — defined by the model section (Task block for `Userscript`). If that enum is named differently at compose time, update these three case labels to match; the mapping (start→start, end/idle→end) is the contract.

- [ ] **Step 2: Write the failing test that pins ordering + timing + the idle shim.** Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/UserscriptInjectionPlannerTests.swift`:

  ```swift
  import XCTest
  @testable import WarboardIOS

  final class UserscriptInjectionPlannerTests: XCTestCase {

      private func script(
          id: String,
          runAt: Userscript.RunAt,
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
  ```

- [ ] **Step 3: Confirm the test FAILS (red).** The `plan` body is `fatalError`, so the suite traps.
  Run: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter UserscriptInjectionPlannerTests`
  Expect: build succeeds, run crashes/fails on `fatalError("not implemented")`. If it fails to **compile** instead (e.g. `Userscript` initializer mismatch), reconcile the `Userscript` init call with the model section before proceeding — do not implement against a guessed initializer.

### Task 15: Implement `UserscriptInjectionPlanner.plan` (green) + the document-idle JS shim

**Files:**
- Modify: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptInjectionPlanner.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/UserscriptInjectionPlannerTests.swift` (unchanged — must pass)

- [ ] **Step 1: Add the idle-shim builder.** This wraps a script body so it runs at idle even though WebKit injects it at `.atDocumentEnd`. It must survive being injected before `DOMContentLoaded` (when `document.readyState === "loading"`). Add to the file, inside `enum UserscriptInjectionPlanner`:

  ```swift
  /// Wraps a body so it executes at "document-idle": after DOMContentLoaded,
  /// scheduled via requestIdleCallback when available (Safari lacks it on some
  /// versions, hence the setTimeout fallback). Injected at .atDocumentEnd.
  static func idleWrapped(_ body: String) -> String {
      // The body is interpolated raw — it is the script author's own code,
      // already trusted by virtue of being installed. We only wrap timing.
      let ric = "(window.requestIdleCallback||function(cb){return setTimeout(cb,1);})"
      return """
      (function(){
        var __run=function(){ \(body)
        };
        var __schedule=function(){ \(ric)(__run); };
        if (document.readyState === "loading") {
          document.addEventListener("DOMContentLoaded", __schedule, { once: true });
        } else {
          __schedule();
        }
      })();
      """
  }
  ```

- [ ] **Step 2: Replace the `fatalError` body with the real ordering logic.** Replace the stub `plan` with:

  ```swift
  static func plan(
      for url: URL,
      scripts: [Userscript],
      requireSources: [String: String],
      bootstrapSource: String
  ) -> [PlannedUserScript] {
      var out: [PlannedUserScript] = [
          PlannedUserScript(
              source: bootstrapSource,
              timing: .documentStart,
              mainFrameOnly: true,
              label: "bootstrap"
          )
      ]

      for script in scripts {
          let bodyTiming = timing(for: script.runAt)

          // Resolve every @require first; if any is missing, skip the whole
          // script (spec §3: a script can't run without its lib).
          var resolvedRequires: [(url: String, src: String)] = []
          var missing = false
          for req in script.requires {
              guard let src = requireSources[req] else { missing = true; break }
              resolvedRequires.append((req, src))
          }
          if missing { continue }

          // @require libs inject at the body's timing so they're present when
          // the body runs, and in declaration order.
          for (req, src) in resolvedRequires {
              out.append(PlannedUserScript(
                  source: src,
                  timing: bodyTiming,
                  mainFrameOnly: true,
                  label: "\(script.id)#require:\(req)"
              ))
          }

          let bodySource = (script.runAt == .documentIdle)
              ? idleWrapped(script.source)
              : script.source
          out.append(PlannedUserScript(
              source: bodySource,
              timing: bodyTiming,
              mainFrameOnly: true,
              label: "\(script.id)#body"
          ))
      }

      return out
  }
  ```

  (`url` is part of the signature for parity with the call site and future per-URL behavior — selection/filtering already happened upstream, so it isn't re-filtered here.)

- [ ] **Step 3: Confirm the suite PASSES (green).**
  Run: `cd /root/projects/warboard-ios/WarboardIOS && swift test --filter UserscriptInjectionPlannerTests`
  Expect: all 7 tests pass (`testRunAtMapping`, `testBootstrapAlwaysFirstAtDocumentStart`, `testRequiresPrecedeBodyInOrder`, `testMultipleScriptsKeepInstallOrder`, `testDocumentIdleBodyIsWrappedInIdleShim`, `testMissingRequireDropsScriptBody`, `testAllPayloadsMainFrameOnly`).

### Task 16: `UserscriptController` — WebKit glue, per-navigation rebuild, message-handler registration

This is the WebKit/UIKit-dependent layer that consumes the pure planner. It owns the `WKWebViewConfiguration` + `WKUserContentController`, drives the rebuild from `WKNavigationDelegate.decidePolicyFor`, and registers the GM message handlers (`GMMessageHandler`, owned by the GM-bridge section). **None of this can run under `swift test` on this Linux server** (no WebKit on Linux); it is verified by an Xcode build + manual smoke on a Mac/device. Each step says so explicitly.

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptController.swift`
- Modify: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/TornChatWebView.swift` (note for the Browser-tab section — left as a reference; the new `BrowserView` section wires the controller in. This task only adds a non-breaking convenience initializer hook, no behavior change to the existing chat view.)

- [ ] **Step 1: Create the controller with the configuration + injection-time mapping.** This is the only place that touches `WKUserScriptInjectionTime`, keeping the planner WebKit-free. Write `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptController.swift`:

  ```swift
  import Foundation
  import WebKit

  /// Owns the WKWebView configuration and rebuilds the injected user-script set
  /// on every navigation (Approach 1). Pure ordering/selection is delegated to
  /// `UserscriptInjectionPlanner`; this type only does the WebKit wiring.
  @MainActor
  final class UserscriptController: NSObject {

      private let registry: ScriptRegistry
      private let requireCache: RequireCache
      private let gmBridge: GMBridge

      /// Built once; handed to the WKWebView. We mutate its
      /// userContentController per navigation.
      let configuration: WKWebViewConfiguration

      private var userContent: WKUserContentController {
          configuration.userContentController
      }

      init(registry: ScriptRegistry, requireCache: RequireCache, gmBridge: GMBridge) {
          self.registry = registry
          self.requireCache = requireCache
          self.gmBridge = gmBridge

          let config = WKWebViewConfiguration()
          config.websiteDataStore = .default()          // share Torn login cookie jar
          config.allowsInlineMediaPlayback = true
          config.defaultWebpagePreferences.allowsContentJavaScript = true
          self.configuration = config
          super.init()

          // GM message handlers are registered ONCE (they outlive navigations);
          // only user scripts are torn down/rebuilt per navigation.
          gmBridge.register(on: config.userContentController)
      }

      /// Maps the planner's platform-free timing to WebKit's enum.
      private func injectionTime(_ t: InjectionTiming) -> WKUserScriptInjectionTime {
          switch t {
          case .documentStart: return .atDocumentStart
          case .documentEnd:   return .atDocumentEnd
          }
      }
  }
  ```

  NOTE for compose: `GMBridge.register(on:)` and the existence of `ScriptRegistry`/`RequireCache` are owned by other sections. If `GMBridge`'s registration method has a different name, update this single call. If the GM bridge needs a per-navigation snapshot push (sync `GM_getValue`), that snapshot is added to `bootstrapSource` by the bridge section's `bootstrapSource(for:on:)` used in Step 2 — this controller just injects whatever string it's handed.
  **Verification:** Xcode build only (WebKit). No headless command. State this in the step log: "WebKit type — verified by `xcodegen generate && xcodebuild build` on Mac, not `swift test`."

- [ ] **Step 2: Add the per-navigation rebuild method.** It gathers enabled matching scripts from the registry, resolves their `@require` sources from the cache, builds the bootstrap, asks the planner for the ordered payloads, then applies them via `removeAllUserScripts()` + `addUserScript`. Add inside the class:

  ```swift
  /// Rebuild the WKUserScript set for `url`. Called from
  /// decidePolicyFor BEFORE allowing the navigation, so WebKit applies the
  /// new scripts to the page about to load.
  func rebuildUserScripts(for url: URL) {
      // 1. Enabled scripts whose @match/@include match and aren't @excluded,
      //    in install order. Selection lives in the registry (MatchMatcher).
      let scripts = registry.enabledScripts(matching: url)

      // 2. Resolve @require sources from the on-disk cache. A cache miss means
      //    the lib isn't available; the planner drops that script's body.
      var requireSources: [String: String] = [:]
      for script in scripts {
          for req in script.requires where requireSources[req] == nil {
              if let src = requireCache.cachedSource(for: req) {
                  requireSources[req] = src
              }
          }
      }

      // 3. The GM bootstrap, carrying this navigation's per-script storage
      //    snapshots (sync GM_getValue) + GM_info, built by the bridge.
      let bootstrap = gmBridge.bootstrapSource(for: scripts, url: url)

      // 4. Pure ordering.
      let planned = UserscriptInjectionPlanner.plan(
          for: url,
          scripts: scripts,
          requireSources: requireSources,
          bootstrapSource: bootstrap
      )

      // 5. Apply. removeAllUserScripts clears the PREVIOUS navigation's set;
      //    GM message handlers (registered in init) are untouched.
      userContent.removeAllUserScripts()
      for p in planned {
          let ws = WKUserScript(
              source: p.source,
              injectionTime: injectionTime(p.timing),
              forMainFrameOnly: p.mainFrameOnly,
              in: .page                       // MAIN world: unsafeWindow === window
          )
          userContent.addUserScript(ws)
      }
  }
  ```

  NOTE: `WKContentWorld.page` (the `in: .page` argument, iOS 14+) is the **main world** — required by the spec so `unsafeWindow === window` and Torn page globals are reachable. `registry.enabledScripts(matching:)`, `requireCache.cachedSource(for:)`, and `gmBridge.bootstrapSource(for:url:)` are the cross-section contracts; if their signatures differ at compose time, adapt these three call sites only.
  **Verification:** WebKit — Xcode build, not `swift test`.

- [ ] **Step 3: Conform to `WKNavigationDelegate` and rebuild in `decidePolicyFor`.** The rebuild must happen *before* the decision handler allows the load, so the new scripts are in place when WebKit starts the page. Add an extension in the same file:

  ```swift
  extension UserscriptController: WKNavigationDelegate {

      func webView(
          _ webView: WKWebView,
          decidePolicyFor navigationAction: WKNavigationAction,
          decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
      ) {
          // Only main-frame, real-URL navigations trigger a rebuild; subframes
          // and about:blank keep the current set. (Scripts are main-frame-only.)
          if navigationAction.targetFrame?.isMainFrame == true,
             let url = navigationAction.request.url,
             url.scheme == "https" || url.scheme == "http" {
              rebuildUserScripts(for: url)
          }
          decisionHandler(.allow)
      }
  }
  ```

  NOTE: We rebuild on the *requested* URL from `decidePolicyFor`. Server-side redirects that land on a different host won't re-trigger this (WebKit may not fire a fresh main-frame `decidePolicyFor` for every redirect hop); that's an accepted limitation matching the spec's per-navigation model — a follow-up could also rebuild in `decidePolicyFor` for redirect responses, but it's out of scope here.
  **Verification:** WebKit — Xcode build, not `swift test`.

- [ ] **Step 4: Expose the configured `WKWebView` factory for the Browser-tab section.** Add a small helper so `BrowserView` (other section) gets a web view already wired to this controller as navigation delegate:

  ```swift
  extension UserscriptController {
      /// Build the WKWebView the Browser tab displays. The controller is the
      /// navigation delegate (drives the per-navigation rebuild) and must be
      /// retained by the caller for the web view's lifetime.
      func makeWebView() -> WKWebView {
          let wv = WKWebView(frame: .zero, configuration: configuration)
          wv.navigationDelegate = self
          wv.allowsBackForwardNavigationGestures = true
          wv.scrollView.contentInsetAdjustmentBehavior = .always
          return wv
      }
  }
  ```

  NOTE for compose: this is the integration point the `BrowserView`/`ScriptsView` section consumes — it instantiates one `UserscriptController` (injected with `ScriptRegistry`/`RequireCache`/`GMBridge`), calls `makeWebView()`, and retains the controller. The existing `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/TornChatWebView.swift` is left unchanged by this task; the Browser tab is a new view, not a modification of the chat view.
  **Verification:** WebKit/UIKit — Xcode build, not `swift test`.

- [ ] **Step 5: Add the controller's two source files to the build.** With xcodegen, `WarboardIOS/Sources/WarboardIOS` is already a `sources` path for the `Warboard` target (see `/root/projects/warboard-ios/project.yml` line 41), so files under `Userscripts/` are compiled automatically — **no `project.yml` edit needed** for the engine sources. (The `Tests/WarboardIOSTests` target itself is added by subsystem 6; this section assumes it exists.) Confirm by regenerating and building.
  **Verification (Mac only):** `cd /root/projects/warboard-ios && xcodegen generate && xcodebuild -scheme Warboard -destination 'generic/platform=iOS' build`. On this Linux server only `swift test --filter UserscriptInjectionPlannerTests` (Tasks 14–15) is runnable; the `UserscriptController` compiles only in Xcode because it imports WebKit.

- [ ] **Step 6: Manual smoke (Mac/TestFlight device — no headless equivalent).** Install **factionops** (has `@require socket.io` + `document-idle`) and **foreign-stock** (`GM_getValue/setValue` + `@connect`) via the Scripts screen, open the Browser tab, navigate to `factions.php?step=your`, and confirm via Safari Web Inspector attached to the device that: (a) `removeAllUserScripts` ran once per navigation (set `console.count` in the bootstrap), (b) socket.io is defined before factionops' body runs, (c) the factionops body executed after `DOMContentLoaded` (idle shim), and (d) a `document-start` test script ran before page scripts. Record the result in the step log; this is the spec's "live smoke with two real scripts."
```

### Task 17: Add the XCTest target (Package.swift for headless pure-logic tests + xcodegen unit-test target)

**Files:**
- Create: `/root/projects/warboard-ios/Package.swift`
- Create: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/.gitkeep`
- Modify: `/root/projects/warboard-ios/project.yml` (add a `WarboardIOSTests` target + wire it into the `Warboard` scheme's `test` block)

> **Executor note — do this task FIRST.** Every earlier subsystem's pure-logic XCTest (subsystems for `MetadataParser`, `MatchMatcher`, `RequireCache`, `GMStore`, etc.) is written against `Tests/WarboardIOSTests/` and verified with `swift test --filter <Name>`. That command needs a `Package.swift` declaring a test target. This task creates it. The same test files are *also* compiled by Xcode via an xcodegen `WarboardIOSTests` target so WebKit-dependent integration tests have a home on a Mac.
>
> **Reality check (this server is Linux, no Xcode, no `Package.swift` today):** The repo is an xcodegen project (`project.yml`) with no SwiftPM manifest. We add a *thin* `Package.swift` whose **only** purpose is to compile and run the pure-Swift engine sources + their unit tests headlessly via `swift test`. WebKit/UIKit sources (`GMBridge` JS-host glue, `BrowserView`, `ScriptsView`, `UserscriptController`) are **excluded** from the SwiftPM library target because they `import WebKit`/`import SwiftUI`/`import UIKit`, which don't build on Linux SwiftPM. Those are verified by `xcodebuild` on a Mac only.

- [ ] **Step 1: Create the placeholder test dir so xcodegen's source path resolves**

The xcodegen target points at `WarboardIOS/Tests/WarboardIOSTests`; create it with a tracked placeholder so `xcodegen generate` doesn't error on a missing path before any test file exists.

```bash
mkdir -p /root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests
touch /root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/.gitkeep
```

- [ ] **Step 2: Write the thin `Package.swift` for headless pure-logic tests**

Create `/root/projects/warboard-ios/Package.swift`. The library target globs only the pure engine sources (the `Userscripts/` folder) and **excludes** the WebKit/SwiftUI/UIKit files by name so SwiftPM compiles on Linux. The test target depends on it and points at the same `Tests/WarboardIOSTests` directory the earlier tasks wrote into.

```swift
// swift-tools-version:5.9
import PackageDescription

// Thin SwiftPM manifest ALONGSIDE the xcodegen project (project.yml).
// Purpose: run the pure-Swift userscript-engine unit tests headlessly
// on Linux CI via `swift test`. The full app (WebKit/SwiftUI/UIKit,
// Live Activities, Watch) builds only through xcodebuild on a Mac.
let package = Package(
    name: "WarboardUserscriptEngine",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "WarboardUserscriptEngine",
            path: "WarboardIOS/Sources/WarboardIOS/Userscripts",
            // Files that import WebKit/SwiftUI/UIKit cannot compile under
            // plain SwiftPM on Linux. They are app-only and verified by
            // xcodebuild. Keep this list in sync as the engine grows.
            exclude: [
                "GMBridge.swift",
                "GMMessageHandler.swift",
                "UserscriptController.swift",
                "BrowserView.swift",
                "ScriptsView.swift"
            ]
        ),
        .testTarget(
            name: "WarboardIOSTests",
            dependencies: ["WarboardUserscriptEngine"],
            path: "WarboardIOS/Tests/WarboardIOSTests",
            // Integration tests that import WebKit are Mac-only (xcodebuild
            // test). Exclude them from the Linux SwiftPM test run.
            exclude: [
                "GMBridgeIntegrationTests.swift",
                "InjectionPipelineTests.swift"
            ]
        )
    ]
)
```

- [ ] **Step 3: Verify the manifest resolves (no test files yet → empty run is fine)**

Run: `cd /root/projects/warboard-ios && swift build`
Expected: builds the `WarboardUserscriptEngine` library target with no errors (it compiles whatever pure-Swift engine files exist; if earlier engine tasks haven't landed yet in this executor's branch, an empty `Userscripts/` still resolves the manifest — `swift build` succeeds with "Compiling" or "Build complete").
Note: if you run this task before the engine source tasks, `swift build` over an empty `Userscripts/` dir prints "warning: ... no sources" but still succeeds; that is acceptable — the manifest is the deliverable here.

- [ ] **Step 4: Add the xcodegen `WarboardIOSTests` unit-test target**

In `/root/projects/warboard-ios/project.yml`, add a new target under `targets:` (after the `Warboard` target block, before `ChainWidget`). This bundles the SAME test files for Xcode so the WebKit integration tests run on a Mac.

```yaml
  WarboardIOSTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: WarboardIOS/Tests/WarboardIOSTests
    dependencies:
      - target: Warboard
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tornwar.warboard.tests
        DEVELOPMENT_TEAM: "DAD59U75G9"
        GENERATE_INFOPLIST_FILE: "YES"
        # Host the tests in the app so WebKit + the engine's app-only
        # sources (BrowserView, UserscriptController) are linkable in
        # integration tests.
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Warboard.app/Warboard"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 5: Wire the test target into the Warboard scheme**

In `/root/projects/warboard-ios/project.yml`, the `schemes.Warboard.test` block currently only sets `config: Debug`. Add the test target to it so `xcodebuild test` finds it.

Replace:

```yaml
    test:
      config: Debug
```

with:

```yaml
    test:
      config: Debug
      targets:
        - WarboardIOSTests
```

- [ ] **Step 6: Verify xcodegen still generates cleanly**

Run: `cd /root/projects/warboard-ios && xcodegen generate`
Expected: "Created project at .../Warboard.xcodeproj" with no error about the `WarboardIOSTests` source path.
Note (Linux): `xcodegen` is a Swift package that builds on Linux, so this command runs headlessly here. The resulting project's *Xcode build* (`xcodebuild test`) is Mac-only — say so; do not claim the test bundle compiled, only that the project graph regenerated.

- [ ] **Step 7: Commit**

```bash
cd /root/projects/warboard-ios && git add Package.swift project.yml WarboardIOS/Tests/WarboardIOSTests/.gitkeep && git commit -m "build: add WarboardIOSTests target (SwiftPM headless + xcodegen Mac host)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 18: `BrowserView` — navigable WKWebView wired to `UserscriptController`

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift`
- Reference (read, do not modify): `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/TornChatWebView.swift:30-46` (existing `WKWebViewRepresentable` pattern — persistent `.default()` data store, `allowsBackForwardNavigationGestures`, `contentInsetAdjustmentBehavior = .always`)

> **Verification for this whole task is xcodebuild + manual smoke on a Mac.** `BrowserView` imports `WebKit`/`SwiftUI`/`UIKit`, which do not compile under SwiftPM on this Linux server. There is **no** `swift test` command for it. After the code steps, the only verification is `xcodebuild -project Warboard.xcodeproj -scheme Warboard -sdk iphonesimulator build` on a Mac, then launching the Browser tab and watching a script run. State that explicitly in the commit/PR; do not claim a green unit test.

- [ ] **Step 1: Create the navigation state object (the bindable nav model)**

This `ObservableObject` is the SwiftUI-facing state the URL bar + toolbar read. It holds the live `WKWebView` so the toolbar buttons can drive it. Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift` with:

```swift
import SwiftUI
import WebKit

/// Observable navigation state for the in-app userscript browser.
/// Holds the live WKWebView so the SwiftUI URL bar + toolbar can drive
/// it, and mirrors the bits the chrome renders (URL text, progress,
/// canGoBack/Forward). The WKWebView itself is created in the
/// representable's makeUIView and handed back here via `attach`.
@MainActor
final class BrowserModel: ObservableObject {
    @Published var urlText: String = "https://www.torn.com/index.php"
    @Published var displayURL: String = ""
    @Published var progress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    /// Set once the representable builds the WebView.
    weak var webView: WKWebView?

    /// Pending load requested before the WebView existed (tab not yet
    /// mounted). Drained in `attach`.
    private var pendingLoad: URL?

    func attach(_ wv: WKWebView) {
        webView = wv
        if let url = pendingLoad {
            pendingLoad = nil
            wv.load(URLRequest(url: url))
        }
    }

    /// Navigate to whatever is in `urlText`, coercing a bare host/path
    /// into an https URL and a non-URL into a Torn search is out of
    /// scope — we only accept explicit URLs here.
    func go() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized) else { return }
        load(url)
    }

    func load(_ url: URL) {
        if let wv = webView {
            wv.load(URLRequest(url: url))
        } else {
            pendingLoad = url
        }
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }
}
```

- [ ] **Step 2: Add the `UIViewRepresentable` that builds the WebView and installs the controller**

Append to the same file. This mirrors `WKWebViewRepresentable` from `TornChatWebView.swift:33-43` (persistent `.default()` store, back/forward gestures) but additionally hands the WebView's `userContentController` + navigation delegate to the `UserscriptController` (defined in the injection-pipeline subsystem) so scripts inject per navigation.

```swift
/// Bridges the WKWebView into SwiftUI and wires the UserscriptController
/// so the engine rebuilds the injected WKUserScript set on every
/// navigation (Approach 1). Generalizes WKWebViewRepresentable from
/// TornChatWebView.swift to a navigable, script-hosting browser.
private struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    let controller: UserscriptController

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()            // shared Torn login cookies
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // The engine owns the userContentController: it installs the GM
        // message handlers once here and rebuilds the per-page user
        // scripts inside its navigation delegate.
        controller.install(into: config.userContentController)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always

        // UserscriptController is the WKNavigationDelegate (it needs
        // decidePolicyFor to rebuild scripts before each load). It
        // forwards progress/title/url updates to our Coordinator.
        controller.attach(to: wv, observer: context.coordinator)

        model.attach(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Receives navigation + KVO updates from the controller and pushes
    /// them onto the BrowserModel for the SwiftUI chrome to render.
    final class Coordinator: NSObject, UserscriptNavigationObserver {
        let model: BrowserModel
        init(model: BrowserModel) { self.model = model }

        func browser(didChangeURL url: URL?) {
            model.displayURL = url?.absoluteString ?? ""
            if let s = url?.absoluteString { model.urlText = s }
        }
        func browser(didChangeProgress p: Double) { model.progress = p }
        func browser(didChangeLoading loading: Bool) { model.isLoading = loading }
        func browser(canGoBack back: Bool, canGoForward fwd: Bool) {
            model.canGoBack = back
            model.canGoForward = fwd
        }
    }
}
```

> **Cross-subsystem contract used here (defined by the injection-pipeline + GM-bridge subsystems; do not redefine):**
> - `UserscriptController.install(into: WKUserContentController)` — registers the GM message handlers.
> - `UserscriptController.attach(to: WKWebView, observer: UserscriptNavigationObserver)` — makes the controller the WebView's `navigationDelegate` + sets up progress KVO, forwarding to `observer`.
> - `protocol UserscriptNavigationObserver` with the four `browser(...)` callbacks above.
>
> If those subsystems named these differently, adapt the call sites here to their names — keep `BrowserView` the consumer, not the definer.

- [ ] **Step 3: Add the SwiftUI chrome (URL bar + progress + toolbar)**

Append the public `BrowserView` struct. It composes the chrome above `BrowserWebView`. The script-actions sheet button (for `GM_registerMenuCommand`, owned by the GM-bridge subsystem) is surfaced via `controller.menuCommands`.

```swift
/// The Browser tab: a navigable WKWebView with a URL bar, back/forward/
/// reload, and a determinate progress bar, hosting the userscript engine.
struct BrowserView: View {
    @StateObject private var model = BrowserModel()

    /// One controller instance per Browser tab. Shares the ScriptRegistry
    /// singleton so installs from the Scripts tab take effect on next nav.
    @StateObject private var controllerBox = ControllerBox()

    var body: some View {
        VStack(spacing: 0) {
            urlBar
            progressBar
            BrowserWebView(model: model, controller: controllerBox.controller)
        }
        .navigationTitle("Browser")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var urlBar: some View {
        HStack(spacing: 10) {
            Button(action: model.goBack) { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack)
            Button(action: model.goForward) { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward)

            TextField("URL", text: $model.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { model.go() }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: model.reload) {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }

            // Per-page script actions (GM_registerMenuCommand). The
            // controller publishes the live command list for the current
            // page; the menu invokes them by id back through the bridge.
            Menu {
                if controllerBox.controller.menuCommands.isEmpty {
                    Text("No script actions").foregroundStyle(.secondary)
                }
                ForEach(controllerBox.controller.menuCommands) { cmd in
                    Button(cmd.label) { controllerBox.controller.invokeMenuCommand(cmd.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder private var progressBar: some View {
        if model.isLoading {
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
                .frame(height: 2)
        } else {
            Color.clear.frame(height: 2)
        }
    }
}

/// Holds the UserscriptController so SwiftUI's @StateObject keeps a single
/// instance across re-renders. The controller itself is the engine's
/// type (injection-pipeline subsystem); this box just owns its lifetime.
@MainActor
private final class ControllerBox: ObservableObject {
    let controller: UserscriptController = UserscriptController(registry: .shared)
}
```

> **Cross-subsystem contract (GM-bridge / registry subsystems own these):**
> - `UserscriptController(registry: ScriptRegistry)` initializer; `ScriptRegistry.shared`.
> - `controller.menuCommands: [MenuCommand]` (published) where `MenuCommand` is `Identifiable` with `id` + `label`.
> - `controller.invokeMenuCommand(_ id:)`.
> If the GM-bridge subsystem hasn't surfaced `menuCommands`/`invokeMenuCommand` yet, the executor adds those two members to `UserscriptController` as the minimal seam (publish an empty array + no-op) so this file builds; the bridge subsystem fills them in. Note this dependency in the PR.

- [ ] **Step 4: Build-verify on a Mac (no headless command exists)**

Run (Mac only): `cd /root/projects/warboard-ios && xcodegen generate && xcodebuild -project Warboard.xcodeproj -scheme Warboard -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED.
On this Linux server you CANNOT run this — `import WebKit` won't resolve under SwiftPM, and there's no iOS SDK. The only headless check available is a syntax-level read; do **not** assert the file compiles. State in the commit that build verification is pending a Mac/CI run.

- [ ] **Step 5: Manual smoke checklist (record in PR, performed on device/simulator)**

- Open the Browser tab → torn.com loads, URL bar shows the resolved URL, progress bar animates then disappears.
- Type `https://www.torn.com/factions.php?step=your` + Go → navigates; back/forward enable correctly.
- With a `@match`ing script installed (e.g. factionops), the script runs (confirm a visible effect) and the `…` menu lists its `GM_registerMenuCommand` actions.

- [ ] **Step 6: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift && git commit -m "feat(browser): navigable WKWebView tab driven by UserscriptController

Build/smoke verified on Mac CI (no headless test — imports WebKit).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 19: Version comparison helper for the update badge (pure logic — TDD)

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/VersionCompare.swift`
- Test: `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/VersionCompareTests.swift`

> This is pure Swift (no WebKit/UIKit), so it runs headlessly with `swift test`. The spec says update compares `@version` as "semver-ish, plain-number compare" (line 114). We implement exactly that: split on `.`, compare numeric components left-to-right, missing components count as 0, non-numeric components compared lexically as a tiebreak.

- [ ] **Step 1: Write the failing test**

Create `/root/projects/warboard-ios/WarboardIOS/Tests/WarboardIOSTests/VersionCompareTests.swift`:

```swift
import XCTest
@testable import WarboardUserscriptEngine

final class VersionCompareTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertEqual(VersionCompare.compare("1.2.3", "1.2.4"), .orderedAscending)
        XCTAssertEqual(VersionCompare.compare("1.2.4", "1.2.3"), .orderedDescending)
    }

    func testEqual() {
        XCTAssertEqual(VersionCompare.compare("2.0.0", "2.0.0"), .orderedSame)
    }

    func testDifferentComponentCounts() {
        // "1.2" == "1.2.0"; "1.2.1" > "1.2"
        XCTAssertEqual(VersionCompare.compare("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(VersionCompare.compare("1.2.1", "1.2"), .orderedDescending)
    }

    func testNumericNotLexical() {
        // The bug the user hit with -wbN suffixes: 10 must beat 9.
        XCTAssertEqual(VersionCompare.compare("1.2.9", "1.2.10"), .orderedAscending)
    }

    func testIsUpdateAvailable() {
        XCTAssertTrue(VersionCompare.isUpdate(installed: "1.2.3", remote: "1.2.4"))
        XCTAssertFalse(VersionCompare.isUpdate(installed: "1.2.4", remote: "1.2.4"))
        XCTAssertFalse(VersionCompare.isUpdate(installed: "1.2.5", remote: "1.2.4"))
    }

    func testNonNumericTiebreak() {
        // Equal numeric prefix, alpha suffix → lexical tiebreak, but a
        // pure-numeric component always outranks a missing one.
        XCTAssertEqual(VersionCompare.compare("1.0.0", "1.0"), .orderedDescending)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /root/projects/warboard-ios && swift test --filter VersionCompareTests`
Expected: FAIL — `cannot find 'VersionCompare' in scope` (the type doesn't exist yet).

- [ ] **Step 3: Write the minimal implementation**

Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/VersionCompare.swift`:

```swift
import Foundation

/// Tampermonkey-style `@version` comparison: numeric, dot-separated,
/// left-to-right. Missing trailing components are treated as 0 so
/// "1.2" == "1.2.0". Non-numeric components fall back to a lexical
/// compare. Deliberately numeric (not lexical) on each component so
/// 1.2.10 > 1.2.9 — the exact bug the -wbN suffix scheme caused.
enum VersionCompare {
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let pb = b.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let count = max(pa.count, pb.count)
        for i in 0..<count {
            let ca = i < pa.count ? pa[i] : "0"
            let cb = i < pb.count ? pb[i] : "0"
            if let na = Int(ca), let nb = Int(cb) {
                if na != nb { return na < nb ? .orderedAscending : .orderedDescending }
            } else {
                // At least one component isn't a plain integer: lexical
                // tiebreak on the raw strings.
                if ca != cb { return ca < cb ? .orderedAscending : .orderedDescending }
            }
        }
        return .orderedSame
    }

    /// True when `remote` is strictly newer than `installed`.
    static func isUpdate(installed: String, remote: String) -> Bool {
        compare(installed, remote) == .orderedAscending
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /root/projects/warboard-ios && swift test --filter VersionCompareTests`
Expected: PASS — all 6 test methods green.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/VersionCompare.swift WarboardIOS/Tests/WarboardIOSTests/VersionCompareTests.swift && git commit -m "feat(scripts): numeric @version compare for update badge

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 20: `ScriptsView` — add-by-URL, list, enable, update, remove, reorder

**Files:**
- Create: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift`
- Reference (read, do not modify): `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/SettingsView.swift` (existing `Form`/`Section`/`PrefsStore` SwiftUI conventions), `VersionCompare.swift` (Task 19)

> **Verification: xcodebuild + manual smoke on a Mac.** `ScriptsView` imports `SwiftUI` and drives `ScriptRegistry`/`RequireResolver`/`MetadataParser` (engine types). The *view-model logic* it calls is already unit-tested in the registry/parser/resolver subsystems; the view itself has no headless test. Build verification is Mac-only — say so.

- [ ] **Step 1: Create the view-model that wraps the registry + install flow**

Create `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift`. The view-model is the seam between SwiftUI and the already-built engine: add-by-URL fetches text, runs `MetadataParser`, resolves `@require`, and inserts into `ScriptRegistry`.

```swift
import SwiftUI

/// Drives the Scripts management screen. The heavy lifting (parse,
/// resolve @require, persist) lives in the engine types built by earlier
/// subsystems — this view-model is just the async glue + published list.
@MainActor
final class ScriptsViewModel: ObservableObject {
    @Published var scripts: [Userscript] = []
    @Published var addURLText: String = ""
    @Published var isWorking: Bool = false
    @Published var errorMessage: String?
    /// Script ids with a known-newer @version at their @updateURL.
    @Published var updatesAvailable: Set<String> = []

    private let registry: ScriptRegistry
    private let resolver: RequireResolver

    init(registry: ScriptRegistry = .shared,
         resolver: RequireResolver = RequireResolver()) {
        self.registry = registry
        self.resolver = resolver
    }

    func reload() {
        // ScriptRegistry exposes the install-ordered list.
        scripts = registry.all().sorted { $0.order < $1.order }
    }

    /// Add by URL: fetch → parse → resolve @require → store. Surfaces a
    /// clear message on a missing metadata block or a @require fetch fail.
    func add() async {
        let url = addURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: url) else {
            errorMessage = "Not a valid URL."
            return
        }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            guard let source = String(data: data, encoding: .utf8) else {
                errorMessage = "Couldn't read the script (not UTF-8)."
                return
            }
            // MetadataParser throws on a missing ==UserScript== block / no @match.
            var script = try MetadataParser.parse(source: source, downloadURL: u.absoluteString)
            // Cache every @require lib; a failure blocks the install.
            try await resolver.resolve(requires: script.requires, forScriptId: script.id)
            script.order = (scripts.map(\.order).max() ?? -1) + 1
            try registry.upsert(script)
            addURLText = ""
            reload()
        } catch let e as MetadataParser.ParseError {
            errorMessage = e.userMessage
        } catch let e as RequireResolver.ResolveError {
            errorMessage = "A @require library failed to download: \(e.userMessage)"
        } catch {
            errorMessage = "Couldn't add the script: \(error.localizedDescription)"
        }
    }

    func setEnabled(_ script: Userscript, _ enabled: Bool) {
        var s = script
        s.enabled = enabled
        try? registry.upsert(s)
        reload()
    }

    func remove(_ script: Userscript) {
        registry.remove(id: script.id)
        updatesAvailable.remove(script.id)
        reload()
    }

    /// Persist a reorder (drag to change injection order).
    func move(from source: IndexSet, to destination: Int) {
        var ordered = scripts
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, var s) in ordered.enumerated() {
            s.order = i
            try? registry.upsert(s)
        }
        reload()
    }

    /// Check every script's @updateURL (fallback @downloadURL) and flag
    /// those whose remote @version is newer.
    func checkForUpdates() async {
        var found: Set<String> = []
        for script in scripts {
            guard let urlStr = script.updateURL ?? script.downloadURL,
                  let u = URL(string: urlStr) else { continue }
            guard let (data, _) = try? await URLSession.shared.data(from: u),
                  let source = String(data: data, encoding: .utf8),
                  let remote = try? MetadataParser.parse(source: source, downloadURL: urlStr)
            else { continue }
            if VersionCompare.isUpdate(installed: script.version, remote: remote.version) {
                found.insert(script.id)
            }
        }
        updatesAvailable = found
    }

    /// Re-fetch @updateURL, re-parse, re-resolve @require, swap source —
    /// preserving id, enabled, and install order.
    func update(_ script: Userscript) async {
        guard let urlStr = script.updateURL ?? script.downloadURL,
              let u = URL(string: urlStr) else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            guard let source = String(data: data, encoding: .utf8) else { return }
            var fresh = try MetadataParser.parse(source: source, downloadURL: urlStr)
            try await resolver.resolve(requires: fresh.requires, forScriptId: script.id)
            fresh.id = script.id
            fresh.enabled = script.enabled
            fresh.order = script.order
            fresh.wildcardConnectGranted = script.wildcardConnectGranted
            try registry.upsert(fresh)
            updatesAvailable.remove(script.id)
            reload()
        } catch {
            errorMessage = "Update failed: \(error.localizedDescription)"
        }
    }
}
```

> **Cross-subsystem contract (registry/parser/resolver subsystems own these; do not redefine — adapt call sites if their names differ):**
> - `ScriptRegistry.shared`, `.all() -> [Userscript]`, `.upsert(_ Userscript) throws`, `.remove(id:)`.
> - `MetadataParser.parse(source:downloadURL:) throws -> Userscript`; `MetadataParser.ParseError` with a `.userMessage: String`.
> - `RequireResolver()` with `.resolve(requires:[String], forScriptId:) async throws`; `RequireResolver.ResolveError` with `.userMessage: String`.
> - `Userscript` fields per the shared model (`id`, `version`, `enabled`, `order`, `requires`, `updateURL`, `downloadURL`, `wildcardConnectGranted`, …).

- [ ] **Step 2: Add the SwiftUI list + add-by-URL chrome**

Append the `ScriptsView` struct to the same file.

```swift
/// The Scripts tab: add userscripts by URL and manage installed ones.
struct ScriptsView: View {
    @StateObject private var vm = ScriptsViewModel()

    var body: some View {
        List {
            addSection
            if let msg = vm.errorMessage {
                Section { Text(msg).foregroundStyle(.red).font(.footnote) }
            }
            installedSection
        }
        .navigationTitle("Scripts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.checkForUpdates() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onAppear { vm.reload() }
    }

    private var addSection: some View {
        Section("Add by URL") {
            HStack {
                TextField("https://…/script.user.js", text: $vm.addURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                Button("Add") { Task { await vm.add() } }
                    .disabled(vm.addURLText.isEmpty || vm.isWorking)
            }
            if vm.isWorking { ProgressView() }
        }
    }

    private var installedSection: some View {
        Section("Installed (\(vm.scripts.count))") {
            ForEach(vm.scripts) { script in
                ScriptRow(
                    script: script,
                    updateAvailable: vm.updatesAvailable.contains(script.id),
                    onToggle: { vm.setEnabled(script, $0) },
                    onUpdate: { Task { await vm.update(script) } }
                )
            }
            .onDelete { idx in
                idx.map { vm.scripts[$0] }.forEach(vm.remove)
            }
            .onMove(perform: vm.move)
        }
    }
}

/// One row: name + version, an enable toggle, a @match summary, and an
/// update badge/button when a newer @version is available upstream.
private struct ScriptRow: View {
    let script: Userscript
    let updateAvailable: Bool
    let onToggle: (Bool) -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(script.name).font(.headline)
                Text("v\(script.version)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(get: { script.enabled }, set: onToggle))
                    .labelsHidden()
            }
            Text(matchSummary).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if updateAvailable {
                Button(action: onUpdate) {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    /// "@match summary": first match + a "+N more" tail.
    private var matchSummary: String {
        guard let first = script.matches.first else { return "no @match" }
        let extra = script.matches.count - 1
        return extra > 0 ? "\(first)  +\(extra) more" : first
    }
}
```

- [ ] **Step 3: Build-verify on a Mac (no headless command)**

Run (Mac only): `cd /root/projects/warboard-ios && xcodegen generate && xcodebuild -project Warboard.xcodeproj -scheme Warboard -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED.
Not runnable on this Linux server (SwiftUI/engine WebKit deps). Do not assert compilation; note build verification pending Mac/CI.

- [ ] **Step 4: Manual smoke checklist (record in PR)**

- Paste a real `.user.js` URL (e.g. a Greasy Fork install URL) → Add → it appears in Installed with the right name/version and a `@match` summary.
- Paste a URL with no `==UserScript==` block → a clear red error, nothing added.
- Toggle enable/disable → next Browser navigation reflects it.
- Tap update-check → a script with a newer upstream `@version` shows the orange "Update available"; tapping it swaps the source and clears the badge.
- Swipe to delete + drag to reorder both persist across app relaunch.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift && git commit -m "feat(scripts): manage screen — add-by-URL, enable, update, remove, reorder

Build/smoke verified on Mac CI (SwiftUI view — no headless test).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 21: Integrate Browser + Scripts as new tabs in `ContentView`

**Files:**
- Modify: `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/ContentView.swift` (the `WBTab` enum at lines 72-93, the `ZStack` tab body at lines 26-54)

> **Important:** `ContentView` is **not** a SwiftUI `TabView` (read the doc comment at lines 1-17 — it's a custom `TopTabBar` + an opacity-gated `ZStack`, deliberately top-anchored so embedded WebViews aren't clipped by a bottom bar). The spec says "new tabs in ContentView's TabView" conceptually; the real integration is into this `WBTab` enum + `ZStack`. Verification is xcodebuild + manual smoke on a Mac — no headless test for a SwiftUI screen. Say so.

- [ ] **Step 1: Add the two new cases to the `WBTab` enum**

In `/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/Views/ContentView.swift`, extend the enum (line 73) and its `label`/`icon` switches. The browser is the headline userscript-host feature; place it after `war`, scripts after `faction`.

Replace:

```swift
    case status, war, faction, oc, settings
```

with:

```swift
    case status, war, browser, faction, scripts, oc, settings
```

Add to the `label` switch (after the `.faction` case):

```swift
        case .browser:  return "Browser"
        case .scripts:  return "Scripts"
```

Add to the `icon` switch (after the `.faction` case):

```swift
        case .browser:  return "globe"
        case .scripts:  return "doc.text.fill"
```

- [ ] **Step 2: Mount the two new tabs in the ZStack**

In the `ZStack` body (lines 26-54), add the two `NavigationStack`s following the existing opacity-gating pattern. Insert the Browser block after the `WarRoomView()` block (lines 31-33) and the Scripts block after the `FactionView()` block (lines 38-40).

Browser (insert after the `WarRoomView()` block):

```swift
                NavigationStack { BrowserView() }
                    .opacity(selected == .browser ? 1 : 0)
                    .allowsHitTesting(selected == .browser)
```

Scripts (insert after the `FactionView()` block):

```swift
                NavigationStack { ScriptsView() }
                    .opacity(selected == .scripts ? 1 : 0)
                    .allowsHitTesting(selected == .scripts)
```

> Note: `BrowserView` keeps its WebView mounted across tab switches because the `ZStack` never tears these down (only opacity-gates them) — exactly the state-preservation behavior the `ContentView` doc comment relies on, so an in-progress Torn session + running scripts survive a tab switch. No change to `TornChatWebView` is needed; it remains the Chat sub-tab inside `WarRoomView`.

- [ ] **Step 3: Confirm the new tabs aren't filtered out by the OC gate**

The `TopTabBar` filters visible tabs with `WBTab.allCases.filter { $0 != .oc || canManageOC }` (line 104). `browser` and `scripts` are not `.oc`, so they pass the filter and show for every user — no change needed. Verify by reading line 104; no edit required. (This step is a read-only confirmation, not a code change.)

- [ ] **Step 4: Build-verify on a Mac (no headless command)**

Run (Mac only): `cd /root/projects/warboard-ios && xcodegen generate && xcodebuild -project Warboard.xcodeproj -scheme Warboard -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED.
Cannot run on this Linux server. Confirm only that the edits are syntactically consistent with the surrounding cases; defer compile to Mac/CI.

- [ ] **Step 5: Manual smoke checklist (record in PR)**

- Seven tabs render in the top bar (Status, War, Browser, Faction, Scripts, OC[owner-only], Settings) with the new globe + doc icons.
- Browser tab loads torn.com; Scripts tab lists installed scripts.
- Switch War → Browser → War: the Browser's Torn session and any running script state survive (opacity gating, not teardown).
- Non-owner build: OC hidden, Browser + Scripts both visible.

- [ ] **Step 6: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Views/ContentView.swift && git commit -m "feat(app): add Browser + Scripts tabs to ContentView

Build/smoke verified on Mac CI (SwiftUI navigation — no headless test).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Self-Review

### Spec-coverage map

| Spec section | Requirement | Task(s) |
|---|---|---|
| §1 Injection pipeline (Approach 1) | per-navigation rebuild, `removeAllUserScripts` → ordered add, main-world `.page`, `@run-at` → injection-time, idle shim | 15, 16 |
| §2 GM bridge + storage | bootstrap `GM_*`/`GM.*`, `WKScriptMessageHandlerWithReply`, sync snapshot reads, write-through, per-script JSON store, `GM_addStyle`/`GM_registerMenuCommand`/`GM_info`/`GM_openInTab`, `unsafeWindow` | 6 (store), 10 (snapshot), 11 (bootstrap + loader), 12 (native handler), 13 (round-trip smoke) |
| §3 `@require` resolver | fetch + cache on install/update, content-hash key, re-fetch on update, fetch-failure blocks enable | 7 (cache + SHA-256), 8 (resolver) |
| §4 `@connect` / `GM_xmlhttpRequest` | `URLSession` proxy, `@connect` allowlist, `*` one-time consent, `*.torn.com` always allowed | 9 (policy), 12 (proxy + consent) |
| §5 Script registry + management | `Userscript` model, add-by-URL, list, update (`@version` compare), enable/disable/remove/reorder | 1 (model), 5 (registry), 19 (version compare), 20 (Scripts UI) |
| §6 Metadata parser (pure seam) | `MetadataParser` → model, repeated keys, defaults; `MatchMatcher` match/include/exclude; `RequireCache` key | 2 (parser), 3–4 (matcher), 7 (cache key) |
| Data flow (happy path) | add factionops → parse → cache socket.io → navigate → select → rebuild → run | end-to-end across 1,2,5,7,8,15–16,18,20 |
| Error handling | `@require` fail blocks enable; malformed metadata rejects add; non-`@connect` rejected; no-context message ignored | 8, 12, 20, 12 (dispatch guard) |
| Testing — Unit (pure XCTest) | `MetadataParser`, `MatchMatcher`, `RequireCache` key stability | 2, 3, 4, 7 (+ 5, 8, 9, 10, 14–15, 19 pure tests) |
| Testing — Integration (WKWebView host) | bootstrap + stub script, sync `GM_setValue`→`GM_getValue`, XHR proxy, `unsafeWindow === window`, `@run-at` ordering; live two-script smoke | 13 (round-trip), 16 Step 6 + 12 Step 5 (live smoke) |
| Surface (UI) — Browser tab | navigable `WKWebView`, URL bar, back/forward/reload | 18 |
| Surface (UI) — Scripts screen | add/list/enable/update/remove | 20 |
| Test target infrastructure | XCTest target (the prerequisite for every other task's tests) | **17 (runs first)** |

Every spec section maps to at least one task; the test target (§Testing prerequisite) is Task 17 and — per the execution-order note — is implemented first so all later tasks' `swift test`/`xcodebuild test` commands have a target.

### Placeholder-scan + type-consistency

- **Placeholder scan:** No `TODO`, `FIXME`, `???`, `fill in`, or unresolved stub remains. The one intentional `fatalError("not implemented")` is the RED-state stub in Task 14 and is explicitly replaced with the real body in Task 15 Step 2 (the task's own green step asserts it's gone). Every code block is complete, compilable Swift/JS — no elision.
- **Renumbering:** Tasks are 1–21, sequential, no gaps or duplicates. The XCTest-target task is **Task 17** but — per the `⚠️ Execution order` note — is implemented first; all cross-references were rewritten to point at the renumbered tasks (planner↔controller and bridge↔controller links updated).
- **Type consistency (mismatches found and fixed):**
  - `RunAt` is a single **top-level** enum (Task 1). Section 4/5 drafts used `Userscript.RunAt` — fixed to `RunAt` everywhere (planner, GM-info builder, fixtures). `gmInfoValue` folded onto the same enum.
  - `MatchMatcher` is **static-only**; `ScriptRegistry.enabledScripts(matching:)` now calls `MatchMatcher.matches(url:script:)` (Section 2 draft's instance form `MatchMatcher(script:).matches(url)` removed).
  - `MetadataParser.parse(_:) -> ScriptMetadata` is the single signature (Task 2). Section 6 draft's `parse(source:downloadURL:) -> Userscript` was removed; `ScriptsViewModel` now parses to `ScriptMetadata` then assembles a `Userscript` via `makeUserscript(from:source:downloadURL:)`.
  - `GMStore` API unified to `get/set/delete(scriptId:key:[value:])` + `snapshot`/`rawSnapshot` (Task 6). The bridge converts JS payloads to `JSONValue` via `GMBridge.jsonValue(from:)`; the integration smoke + bootstrap-source builder use `rawSnapshot(scriptId:)` (Section 4 draft's `GMStore(scriptID:)`/`rawSnapshot()` zero-arg forms reconciled).
  - `RequireResolver` is `init(cache:fetch:)` + `.live(cache:)` with `resolve(_ script:)` (Task 8). Section 6 draft's `RequireResolver()` / `resolve(requires:forScriptId:)` removed; the view-model passes a `Userscript`.
  - `JSONValue` lives only in `GMStore.swift` (single source of truth); the GM-bridge section reuses it rather than redefining.
  - `UserscriptController` seam unified to `init(registry:requireCache:gmBridge:gmStore:)` + convenience `init(registry:)`, `makeWebView()`, `register(on:)` on the bridge, `bootstrapSource(for:url:store:)`, `requireCache.read(forURL:)`. Section 6 draft's `install(into:)`/`attach(to:observer:)`/`UserscriptNavigationObserver` protocol were dropped in favor of the controller owning KVO via `BrowserModel` + being its own nav delegate. `menuCommands`/`invokeMenuCommand` are real published members on the controller (no "minimal seam" placeholder).
  - **Module name:** every test uses `@testable import WarboardIOS`; the SwiftPM library target is named `WarboardIOS` (Task 17). The Section 6 draft's `import WarboardUserscriptEngine` in `VersionCompareTests` was corrected to `WarboardIOS`.
  - `Userscript` memberwise initializer is identical in all call sites (model, registry tests, matcher tests, resolver tests, planner tests, integration fixture): `id, name, namespace, version, description, matches, includes, excludes, requires, connects, grants, runAt, icon, downloadURL, updateURL, enabled, order, source, wildcardConnectGranted`.

### Residual risks

- **WebKit tasks are not headless-testable.** Tasks 11 (bootstrap runtime), 12 (`GMBridge`), 13 (round-trip smoke), 16 (`UserscriptController`), 18 (`BrowserView`), 20 (`ScriptsView`), and 21 (`ContentView` tabs) import WebKit/SwiftUI/UIKit and only build/run via `xcodebuild` on a Mac/CI. Their pure dependencies (parser, matcher, registry, store, cache, resolver, connect policy, snapshot, planner, version compare — Tasks 1–10, 14–15, 19) are fully covered by `swift test` on Linux. The `gm-bootstrap.js` gets `node --check` syntax linting headless, but its runtime behavior is proven only by the Task 13 smoke + the live two-script smoke. **Mitigation:** every WebKit task names its Mac-only verification command explicitly and forbids claiming a headless green.
- **`@connect` wildcard-consent retry timing (Task 12).** On `.needsWildcardConsent`, the bridge sends the XHR after consent but relies on `UserscriptController` to persist `wildcardConnectGranted` + refresh `activeScripts` on the next rebuild; the in-flight request uses the granted decision but the persisted flag lands on the next navigation. This matches the spec's per-navigation snapshot model but means a second same-page XHR before the next nav re-prompts. Acceptable for Slice 1; flagged for the live smoke to confirm UX.
- **Redirect handling (Task 16).** `decidePolicyFor` rebuilds on the *requested* main-frame URL; a server redirect to a different host may not re-fire a fresh main-frame decision, so a script matching only the post-redirect URL could miss injection. Documented as an accepted Slice-1 limitation.
- **Sync `GM_getValue` staleness (spec §Risks).** The document-start snapshot won't reflect a value written by another tab/process mid-page until the next navigation — matches Tampermonkey's per-document behavior; no code change, noted for parity.
- **App Store review (spec §Risks).** Running arbitrary remote scripts is fine for TestFlight/personal (how warboard-iOS ships); a public release of a general-installer browser is deferred — out of scope for this plan.

# Visible + Manual Extension Updates — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface remote WebExtension updates in the Scripts screen + a badge on the Scripts button, and install them on tap with a live hot-swap (no relaunch) — replacing the silent at-launch auto-download.

**Architecture:** Split `RemoteExtStore.checkAndFetch` into a cheap `checkForUpdate` (version.json only) and a heavy `installUpdate` (download + sha-verify + atomic swap + cache invalidate). A shared `@MainActor ExtensionUpdateStore` holds the "update available" map for both the Scripts UI and a badge dot. Install delegates through `ExtensionRuntime.installExtensionUpdate` → `reloadExtension` (reload manifest in place, restart the background host, post `.userscriptsDidChange` so the page reloads and re-injects). The version policy is factored into a pure, Linux-testable `ExtUpdateDecision`.

**Tech Stack:** Swift / SwiftUI / WebKit (iOS, Mac-CI compile), SwiftPM unit tests (Linux), Node ESM (server packaging).

**Testability note:** Everything under `Sources/WarboardIOS/Userscripts/WebExt/` and the excluded SwiftUI files (`ScriptsView.swift`, `BrowserView.swift`) compile **only on macOS via xcodebuild** (see `Package.swift` excludes). They cannot be `swift test`-ed on this server. Therefore: Task 1 (pure policy) and Task 2 (server) get real local tests; Tasks 3–9 (WebKit/SwiftUI) are verified by (a) the Task-10 adversarial diff review and (b) Mac CI archive + on-device. Do **not** push until Task 10 passes — a push to `warboard-ios` main ships to TestFlight.

---

## File map

| File | Change |
|---|---|
| `WarboardIOS/Sources/WarboardIOS/Userscripts/ExtUpdateDecision.swift` | **Create** — pure version-policy (Linux-testable) |
| `WarboardIOS/Tests/WarboardIOSTests/ExtUpdateDecisionTests.swift` | **Create** — unit tests |
| `/opt/warboard/bin/package-torntools.mjs` | Exclude `*.map` from the package |
| `WarboardIOS/.../WebExt/RemoteExtStore.swift` | Split `checkAndFetch` → `checkForUpdate` + `installUpdate` + `invalidate`; add `RemoteExtError` |
| `WarboardIOS/.../WebExt/ExtBackgroundHost.swift` | `version` let→var; add `updateVersion` + `restart` |
| `WarboardIOS/.../WebExt/ExtInstance.swift` | `manifest` let→var; add `reloadManifest` |
| `WarboardIOS/.../WebExt/ExtensionRuntime.swift` | Remove silent launch download; add `checkExtensionUpdate` / `installExtensionUpdate` / `reloadExtension` |
| `WarboardIOS/.../WebExt/ExtensionUpdateStore.swift` | **Create** — shared `ObservableObject` update map |
| `WarboardIOS/.../Userscripts/ScriptsView.swift` | Extension-row "Install update" button + check on appear/refresh |
| `WarboardIOS/.../Userscripts/BrowserView.swift` | Badge dot on the Scripts button + launch check |

---

### Task 1: Pure update-decision policy (Linux-testable)

**Files:**
- Create: `WarboardIOS/Sources/WarboardIOS/Userscripts/ExtUpdateDecision.swift`
- Test: `WarboardIOS/Tests/WarboardIOSTests/ExtUpdateDecisionTests.swift`

This is placed under `Userscripts/` (NOT `WebExt/`) so SwiftPM includes it on Linux. It replicates the EXACT guards currently in `RemoteExtStore.checkAndFetch` (lines 74 + 76): offer only a strictly-newer version, and refuse when the bundled seed is newer than the server build's `minSeedVersion`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WarboardIOS

final class ExtUpdateDecisionTests: XCTestCase {
    func test_offersStrictlyNewerVersion() {
        XCTAssertEqual(
            ExtUpdateDecision.versionToOffer(active: "9.0.6", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"),
            "9.0.6.1")
    }
    func test_noUpdateWhenEqual() {
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.6.1", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"))
    }
    func test_noUpdateWhenRemoteOlder() {
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.7", remote: "9.0.6.1", seed: "9.0.6", minSeed: "9.0.6.1"))
    }
    func test_refusesWhenSeedNewerThanMinSeed() {
        // Server build requires seed >= 9.0.6, but our seed is 9.1.0 (newer) →
        // don't shadow the newer seed with an older server copy.
        XCTAssertNil(
            ExtUpdateDecision.versionToOffer(active: "9.0.5", remote: "9.0.6", seed: "9.1.0", minSeed: "9.0.6"))
    }
    func test_nilMinSeedSkipsFloor() {
        XCTAssertEqual(
            ExtUpdateDecision.versionToOffer(active: "9.0.6", remote: "9.0.6.1", seed: "9.0.6", minSeed: nil),
            "9.0.6.1")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /root/projects/warboard-ios && swift test --filter ExtUpdateDecisionTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ExtUpdateDecision' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Pure version policy for remote extension updates, kept out of the
/// WebKit-bound `RemoteExtStore` so it is unit-testable on Linux. Mirrors the
/// guards in `RemoteExtStore` exactly: offer only a strictly-newer version, and
/// refuse when the bundled seed is newer than the server build's `minSeedVersion`
/// floor (so a newer in-app seed is never shadowed by an older server copy).
enum ExtUpdateDecision {
    static func versionToOffer(active: String, remote: String,
                               seed: String, minSeed: String?) -> String? {
        guard VersionCompare.isUpdate(installed: active, remote: remote) else { return nil }
        if let minSeed, VersionCompare.compare(seed, minSeed) == .orderedDescending { return nil }
        return remote
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /root/projects/warboard-ios && swift test --filter ExtUpdateDecisionTests 2>&1 | tail -20`
Expected: PASS — 5 tests.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/ExtUpdateDecision.swift WarboardIOS/Tests/WarboardIOSTests/ExtUpdateDecisionTests.swift
git commit -m "feat(ios/webext): pure ExtUpdateDecision version policy + tests"
```

---

### Task 2: Server — drop `*.map` from the TornTools package

**Files:**
- Modify: `/opt/warboard/bin/package-torntools.mjs` (the copy loop in `packageTornTools`)

Sourcemaps are devtools-only; the 4 biggest packaged files are all `.map` (~15 MB of 31 MB). Excluding them ~halves the download.

- [ ] **Step 1: Modify the copy loop**

In `packageTornTools`, change:
```js
  for (const rel of walk(stockDir)) copy(join(stockDir, rel), join(verDir, rel));
```
to:
```js
  // Sourcemaps are devtools-only; skip them to ~halve the on-device download.
  for (const rel of walk(stockDir)) {
    if (rel.endsWith(".map")) continue;
    copy(join(stockDir, rel), join(verDir, rel));
  }
```

- [ ] **Step 2: Verify exclusion against the live 9.0.6.1 tree (proxy fixture)**

Run (packages the current served tree as a throwaway version and asserts no `.map`):
```bash
cd /opt/warboard
node -e '
const {packageTornTools}=await import("./bin/package-torntools.mjs");
const fs=await import("node:fs"), path=await import("node:path");
const src="server/public/ext/torntools/9.0.6.1";
const out="/tmp/tt-maptest";
fs.rmSync(out,{recursive:true,force:true});
// stock fixture needs background.js + manifest.json + content-scripts/extension.js
fs.mkdirSync(path.join(out,"stock/content-scripts"),{recursive:true});
fs.copyFileSync(path.join(src,"manifest.json"),path.join(out,"stock/manifest.json"));
fs.writeFileSync(path.join(out,"stock/background.js"),"//bg");
fs.writeFileSync(path.join(out,"stock/content-scripts/extension.js"),"//cs");
fs.writeFileSync(path.join(out,"stock/content-scripts/extension.js.map"),"{}");
const r=packageTornTools({stockDir:path.join(out,"stock"),outDir:path.join(out,"public"),version:"0.0.1-test"});
const vj=JSON.parse(fs.readFileSync(path.join(out,"public/version.json"),"utf8"));
const maps=vj.files.filter(f=>f.path.endsWith(".map"));
console.log("files:",vj.files.length,"| .map files:",maps.length);
if(maps.length!==0){console.error("FAIL: .map present");process.exit(1)}
console.log("OK: no .map in package");
' 2>&1 | tail -5
```
Expected: `OK: no .map in package`.

- [ ] **Step 3: Commit (server repo) — do NOT deploy yet**

```bash
cd /opt/warboard
git add bin/package-torntools.mjs
git commit -m "package-torntools: exclude *.map sourcemaps (~halve the download)"
```
(Deploy of a repackaged version happens in Task 11, AFTER the new iOS build is live, so the current app's silent updater doesn't grab it first.)

---

### Task 3: `RemoteExtStore` — split check from install

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift` (replace `checkAndFetch`, add `checkForUpdate`, `installUpdate`, `invalidate`, `RemoteExtError`)

- [ ] **Step 1: Add the error type + invalidate (after the `RemoteVersionManifest` struct)**

```swift
    enum RemoteExtError: Error { case badSource, manifestUnavailable, downloadFailed, badStage }

    /// Drop the per-launch memoized container choice for `id` so the next
    /// `containerBase(for: id)` re-resolves (picks a freshly-installed cache).
    func invalidate(id: String) {
        lock.lock(); defer { lock.unlock() }
        containerCache[id] = nil
    }
```

- [ ] **Step 2: Add `checkForUpdate` (cheap; version.json only) using the pure policy**

```swift
    /// Cheap: fetch only `version.json` and return the version to OFFER as an
    /// update (or nil). No download. Used by the in-app "check for updates".
    func checkForUpdate(id: String, source: URL) async -> String? {
        guard let (data, resp) = try? await URLSession.shared.data(from: source),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data)
        else { return nil }
        let activeVer = manifestVersion(at: containerBase(for: id).appendingPathComponent("\(id)/manifest.json")) ?? "0"
        let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
        return ExtUpdateDecision.versionToOffer(active: activeVer, remote: man.version,
                                                seed: seedVer, minSeed: man.minSeedVersion)
    }
```

- [ ] **Step 3: Replace `checkAndFetch` with `installUpdate` (throws; invalidates; returns new version)**

Delete the entire existing `func checkAndFetch(id:source:) async { … }` and replace with:
```swift
    /// Heavy: download every file (sha256-verified) into a staging dir and
    /// atomic-swap into `…/webext-remote/<id>/`. On success invalidate the
    /// memo and return the new version. Throws on any failure (the live cache is
    /// untouched until the swap, so a failure never half-installs).
    @discardableResult
    func installUpdate(id: String, source: URL) async throws -> String {
        guard let remoteDir, let scheme = source.scheme, let host = source.host else {
            throw RemoteExtError.badSource
        }
        let origin = "\(scheme)://\(host)" + (source.port.map { ":\($0)" } ?? "")
        let (data, resp) = try await URLSession.shared.data(from: source)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data) else {
            throw RemoteExtError.manifestUnavailable
        }

        let staging = remoteDir.appendingPathComponent("\(id).incoming", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        for f in man.files {
            guard let fileURL = URL(string: origin + man.base + f.path) else {
                try? fm.removeItem(at: staging); throw RemoteExtError.downloadFailed
            }
            let (fdata, fresp) = try await URLSession.shared.data(from: fileURL)
            let sha = SHA256.hash(data: fdata).map { String(format: "%02x", $0) }.joined()
            guard (fresp as? HTTPURLResponse)?.statusCode == 200, sha == f.sha256 else {
                try? fm.removeItem(at: staging); throw RemoteExtError.downloadFailed
            }
            let dest = staging.appendingPathComponent(f.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fdata.write(to: dest)
        }
        guard manifestVersion(at: staging.appendingPathComponent("manifest.json")) != nil else {
            try? fm.removeItem(at: staging); throw RemoteExtError.badStage
        }

        let live = remoteDir.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: remoteDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: live.path) {
            _ = try fm.replaceItemAt(live, withItemAt: staging)
        } else {
            try fm.moveItem(at: staging, to: live)
        }
        defaults.set(man.version, forKey: "webext-remote-version.\(id)")
        invalidate(id: id)
        WebDiag.log("webext-remote-updated", ["id": id, "version": man.version])
        return man.version
    }
```

- [ ] **Step 4: Sanity-check the edit**

Run: `cd /root/projects/warboard-ios && grep -n "checkAndFetch\|func checkForUpdate\|func installUpdate\|func invalidate" WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift`
Expected: no `checkAndFetch` remains; the three new funcs are present.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift
git commit -m "feat(ios/webext): RemoteExtStore split — checkForUpdate + installUpdate + invalidate"
```

---

### Task 4: `ExtBackgroundHost` — restart for hot-swap

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtBackgroundHost.swift`

- [ ] **Step 1: Make `version` mutable**

Change `private let version: String` to `private var version: String`.

- [ ] **Step 2: Add `updateVersion` + `restart` (after `func start()`)**

```swift
    /// Update the version used by `maybeFireInstalled` (so a hot-swap fires
    /// `onInstalled(update)` and the extension migrates). Call before `restart()`.
    func updateVersion(_ v: String) { version = v }

    /// Tear down the hidden bg webview and start a fresh one — reloads
    /// `_background.js` from the (now-updated) cache. Safe if never started.
    @MainActor
    func restart() {
        webView?.navigationDelegate = nil
        webView = nil
        isReady = false
        start()
    }
```

- [ ] **Step 3: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "private var version\|func updateVersion\|func restart" WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtBackgroundHost.swift`
Expected: all three present.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtBackgroundHost.swift
git commit -m "feat(ios/webext): ExtBackgroundHost.restart for live update hot-swap"
```

---

### Task 5: `ExtInstance` — reloadable manifest

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtInstance.swift`

- [ ] **Step 1: Make `manifest` mutable**

Change `let manifest: ExtManifest` to `var manifest: ExtManifest`.

- [ ] **Step 2: Add `reloadManifest` (after `startIfEnabled()`)**

```swift
    /// Re-read this extension's manifest from the (post-invalidate) container so
    /// `info.version`, the injection `header`, and the content-script list all
    /// reflect a freshly-installed update. Syncs the bg host's version too.
    func reloadManifest() {
        if let m = ExtManifest.load(id: id) {
            manifest = m
            backgroundHost.updateVersion(m.version)
        }
    }
```

- [ ] **Step 3: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "var manifest: ExtManifest\|func reloadManifest" WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtInstance.swift`
Expected: both present.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtInstance.swift
git commit -m "feat(ios/webext): ExtInstance.reloadManifest (mutable manifest)"
```

---

### Task 6: `ExtensionRuntime` — remove silent download; add check/install/reload

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionRuntime.swift`

- [ ] **Step 1: Remove the silent launch download**

Delete this block from `init()` (the `Task.detached { checkAndFetch }` and its comment, currently lines ~56–62):
```swift
        // Silent background check for newer server copies of remote-sourced
        // extensions. Applies on the NEXT launch (this session's containerBase
        // is already fixed). Capture value-type (id, URL) pairs, not self.
        let remote = instances.compactMap { inst in inst.remoteSource.map { (inst.id, $0) } }
        Task.detached(priority: .utility) {
            for (id, src) in remote { await RemoteExtStore.shared.checkAndFetch(id: id, source: src) }
        }
```

- [ ] **Step 2: Add check / install / reload methods (after `setExtensionEnabled`)**

```swift
    /// Cheap update check for one remote-sourced extension (nil if not remote
    /// or up to date). Drives `ExtensionUpdateStore`.
    func checkExtensionUpdate(id: String) async -> String? {
        guard let inst = instance(id), let src = inst.remoteSource else { return nil }
        return await RemoteExtStore.shared.checkForUpdate(id: id, source: src)
    }

    /// Download + install the newest server copy, then hot-swap it in. Returns
    /// the new version. Throws on download failure (nothing applied).
    func installExtensionUpdate(id: String) async throws -> String {
        guard let inst = instance(id), let src = inst.remoteSource else {
            throw RemoteExtStore.RemoteExtError.badSource
        }
        let newVersion = try await RemoteExtStore.shared.installUpdate(id: id, source: src)
        await reloadExtension(id: id)
        return newVersion
    }

    /// Apply a freshly-installed update live: reload the manifest, restart the
    /// background host (re-runs `_background.js` + fires onInstalled→migrate),
    /// and post `.userscriptsDidChange` so the page reloads and re-injects the
    /// new content scripts. The cache is already updated, so even if this is a
    /// no-op a relaunch applies cleanly.
    @MainActor
    func reloadExtension(id: String) {
        guard let inst = instance(id) else { return }
        inst.reloadManifest()
        inst.backgroundHost.restart()
        NotificationCenter.default.post(name: .userscriptsDidChange, object: nil)
    }
```

- [ ] **Step 3: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "checkAndFetch\|checkExtensionUpdate\|installExtensionUpdate\|reloadExtension" WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionRuntime.swift`
Expected: no `checkAndFetch`; the three new funcs present.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionRuntime.swift
git commit -m "feat(ios/webext): manual update API; drop silent at-launch download"
```

---

### Task 7: `ExtensionUpdateStore` — shared update state

**Files:**
- Create: `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionUpdateStore.swift`

- [ ] **Step 1: Create the store**

```swift
import Foundation
import Combine

/// Shared, observable "which extensions have an update available" map. One
/// source of truth for both the Scripts screen (per-row Install button) and the
/// browser-chrome badge dot. Populated by a cheap `version.json` check — never
/// downloads. `@MainActor` so `@Published` mutations are UI-safe.
@MainActor
final class ExtensionUpdateStore: ObservableObject {
    static let shared = ExtensionUpdateStore()
    private init() {}

    /// extension id → available newer version.
    @Published private(set) var available: [String: String] = [:]

    var hasUpdates: Bool { !available.isEmpty }

    /// Re-check every installed extension (remote-sourced ones return a version;
    /// others return nil). Cheap: version.json only.
    func check() async {
        var found: [String: String] = [:]
        for info in ExtensionRuntime.shared.installedExtensions {
            if let v = await ExtensionRuntime.shared.checkExtensionUpdate(id: info.id) {
                found[info.id] = v
            }
        }
        available = found
    }

    func clear(id: String) { available.removeValue(forKey: id) }
}
```

- [ ] **Step 2: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "class ExtensionUpdateStore\|func check\|var hasUpdates" WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionUpdateStore.swift`
Expected: present.

- [ ] **Step 3: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/ExtensionUpdateStore.swift
git commit -m "feat(ios/webext): shared ExtensionUpdateStore (update-available map)"
```

---

### Task 8: `ScriptsView` — Install-update button + checks

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift`

- [ ] **Step 1: ViewModel — add install method (after `func update(_ script:)`)**

```swift
    func installExtensionUpdate(_ id: String) async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await ExtensionRuntime.shared.installExtensionUpdate(id: id)
            ExtensionUpdateStore.shared.clear(id: id)
        } catch {
            errorMessage = "Extension update failed: \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 2: Observe the store on the view**

In the `ScriptsView` struct (the `View`, where `@StateObject private var vm` / `@State private var extTick` live), add:
```swift
    @ObservedObject private var updateStore = ExtensionUpdateStore.shared
```

- [ ] **Step 3: Show the Install button in `extensionsSection`**

Replace the `VStack(alignment: .leading, spacing: 2)` label inside the `Toggle` with one that appends an Install button when an update is available:
```swift
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ext.name)
                        Text("v\(ext.version) · \(ext.attribution)")
                            .font(.caption).foregroundStyle(.secondary)
                        if let newVersion = updateStore.available[ext.id] {
                            Button {
                                Task { await vm.installExtensionUpdate(ext.id) }
                            } label: {
                                Label("Install update: \(newVersion)", systemImage: "arrow.down.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .tint(.orange)
                            .disabled(vm.isWorking)
                        }
                    }
```

- [ ] **Step 4: Check on appear + on the refresh toolbar button**

Change the toolbar refresh action (currently `Task { await vm.checkForUpdates() }`) to also check extensions:
```swift
                Button {
                    Task { await vm.checkForUpdates(); await updateStore.check() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
```
And change `.onAppear { vm.reload() }` to:
```swift
        .onAppear { vm.reload(); Task { await updateStore.check() } }
```

- [ ] **Step 5: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "updateStore\|installExtensionUpdate\|Install update" WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift`
Expected: the observed store, the VM method, and the button label present.

- [ ] **Step 6: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift
git commit -m "feat(ios): Scripts screen — per-extension Install update button + checks"
```

---

### Task 9: `BrowserView` — badge dot on the Scripts button

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift`

- [ ] **Step 1: Observe the store**

In the `BrowserView` struct (where `@State private var showScripts` lives), add:
```swift
    @ObservedObject private var extUpdates = ExtensionUpdateStore.shared
```

- [ ] **Step 2: Badge the `doc.text.fill` button (line ~444)**

Change:
```swift
            Button { showScripts = true } label: {
                Image(systemName: "doc.text.fill")
            }
```
to:
```swift
            Button { showScripts = true } label: {
                Image(systemName: "doc.text.fill")
                    .overlay(alignment: .topTrailing) {
                        if extUpdates.hasUpdates {
                            Circle().fill(.red).frame(width: 8, height: 8).offset(x: 5, y: -3)
                        }
                    }
            }
```

- [ ] **Step 3: Check at launch (no download) in `.onAppear`**

In the existing `.onAppear { ExtensionRuntime.shared.onOpenExtPage = … }` block (line ~304), add as the first line inside the closure:
```swift
            Task { await ExtensionUpdateStore.shared.check() }
```

- [ ] **Step 4: Sanity-check**

Run: `cd /root/projects/warboard-ios && grep -n "extUpdates\|hasUpdates\|ExtensionUpdateStore.shared.check" WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift`
Expected: observed store, badge condition, launch check present.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios
git add WarboardIOS/Sources/WarboardIOS/Userscripts/BrowserView.swift
git commit -m "feat(ios): badge the Scripts button when an extension update is available"
```

---

### Task 10: Adversarial diff review (compensates for no local Swift compile)

**Files:** none (review only)

The WebKit/SwiftUI tasks can't be compiled here. Before the TestFlight-shipping push, run a multi-agent adversarial review of the full diff for Swift compile errors, Swift-6 concurrency (`@MainActor` / Sendable), lifecycle bugs (bg restart, memo invalidation, retain cycles), and SwiftUI observation correctness.

- [ ] **Step 1: Produce the diff**

Run: `cd /root/projects/warboard-ios && git diff 0869f7d..HEAD -- WarboardIOS > /tmp/ext-updates.diff && wc -l /tmp/ext-updates.diff`

- [ ] **Step 2: Run the review workflow** (Workflow tool; dimensions = compile-correctness, concurrency, lifecycle, SwiftUI-observation; adversarial verify each finding; Opus agents). Fix any Critical/Important findings, re-commit.

- [ ] **Step 3: Verify the package still builds the SwiftPM (Linux) half**

Run: `cd /root/projects/warboard-ios && swift build 2>&1 | tail -5 && swift test --filter ExtUpdateDecisionTests 2>&1 | tail -5`
Expected: build succeeds (Linux half), 5 ExtUpdateDecision tests pass.

---

### Task 11: Ship + sequenced deploy

**Files:** none (release)

- [ ] **Step 1: Push iOS (ships the new build to TestFlight)**

```bash
cd /root/projects/warboard-ios && git push origin HEAD
```
Then verify CI: `gh run list --repo russianrob/warboard-ios --limit 3` → the run archives + uploads. Confirm "ARCHIVE SUCCEEDED" + TestFlight upload in the log.

- [ ] **Step 2: After the user is on the new build, deploy the repackaged update**

Re-package stock 9.0.6 as **9.0.6.2** (now `.map`-excluded + the hide-chat fix carried by patch #4), regenerate `version.json`, commit + push the server, deploy:
```bash
cd /opt/warboard
node bin/package-torntools.mjs <stockDir-9.0.6> 9.0.6.2
git add bin/package-torntools.mjs server/public/ext/torntools
git commit -m "TornTools 9.0.6.2: drop sourcemaps (smaller download)"
git push origin HEAD
# served statically; verify:
curl -s https://tornwar.com/ext/torntools/version.json | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['version'], len(d['files']), 'files', '| .map:', sum(1 for f in d['files'] if f['path'].endswith('.map')))"
```
Expected: `9.0.6.2 … files | .map: 0`.

- [ ] **Step 3: On-device verification (user)**

On the new build: a red dot appears on the Scripts button; the Extensions row shows "Install update: 9.0.6.2"; tapping it downloads, the Torn page reloads, the label flips to `v9.0.6.2`, and the badge clears — no relaunch.

---

## Self-Review

**Spec coverage:** check/install split (T3) ✓; ExtensionUpdateStore (T7) ✓; reloadExtension/live-apply (T6) ✓; ExtBackgroundHost.restart (T4) ✓; ExtInstance manifest var (T5) ✓; ScriptsView row + checks (T8) ✓; BrowserView badge + launch check (T9) ✓; server `.map` exclusion (T2/T11) ✓; remove silent download (T6) ✓; tab/button badge (T9) ✓; pure policy + tests (T1) ✓; error handling (T3 throws; T8 surfaces) ✓; sequenced deploy so the current app doesn't pre-empt the test (T2/T11) ✓.

**Type consistency:** `RemoteExtStore.RemoteExtError` referenced in T3 + T6 ✓; `checkForUpdate`/`installUpdate`/`invalidate` names consistent T3↔T6 ✓; `ExtensionUpdateStore.shared.available/check/clear/hasUpdates` consistent T7↔T8↔T9 ✓; `reloadExtension`/`reloadManifest`/`updateVersion`/`restart` consistent T4↔T5↔T6 ✓; `ExtUpdateDecision.versionToOffer` consistent T1↔T3 ✓.

**Placeholders:** none — every code step has complete code.

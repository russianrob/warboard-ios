# Remote-Extension Loader — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax. Claude implements directly (Codex discontinued).

**Goal:** The warboard-iOS WebExt runtime fetches TornTools' files from the warboard server and serves them through the existing resolvers (bundle = offline seed), so TornTools updates ship server-side without a TestFlight cycle; this build also seeds patched TornTools 9.0.6.

**Architecture:** Centralize the "where do `<id>`'s files live" decision in a new `RemoteExtStore.containerBase(for:)` (server cache `…/Application Support/webext-remote/` when valid + version ≥ seed, else `Bundle.main.resourceURL`), and route the **four** existing bundle reads through it. A background `checkAndFetch` on launch downloads a newer version per-file (sha256-verified, atomic install), applied next launch. Server `package-torntools.mjs` patches a stock build (14-line prelude + re-seed version) and emits `version.json` + the file tree.

**Tech Stack:** Swift (Foundation + CryptoKit; WebExt files compile only on Mac CI), Node ESM (server packaging), static hosting via `express.static(public)`.

**Build order:** Part S (server, fully testable locally) → Part I (iOS). Within I: `RemoteExtStore` core (I1) → route the 4 sites (I2) → runtime wiring (I3) → `checkAndFetch` (I4) → seed 9.0.6 (I5) → ship (I6).

**Spec:** `docs/superpowers/specs/2026-06-13-remote-ext-loader-design.md`.

---

## File structure

| File | Responsibility |
|---|---|
| `server/data/torntools-prelude.js` (create) | source-controlled 14-line `_background.js` prelude |
| `server/bin/package-torntools.mjs` (create) | patch a stock TornTools build → `public/ext/torntools/<ver>/` + `version.json` |
| `server/public/ext/torntools/version.json` + `<ver>/…` (generated) | served manifest + file tree |
| `WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift` (create) | `containerBase(for:)`, `compareVersions`, `checkAndFetch` |
| `…/WebExt/ExtResourceScheme.swift` (modify L37) | base via `RemoteExtStore` |
| `…/WebExt/ExtManifest.swift` (modify L47) | base via `RemoteExtStore` |
| `…/WebExt/ExtInstance.swift` (modify L188) | `bundledText` base via `RemoteExtStore` |
| `…/WebExt/ExtBackgroundHost.swift` (modify L195) | `bundled` base via `RemoteExtStore` |
| `…/WebExt/ExtensionRuntime.swift` (modify init) | TornTools `remoteSource` + launch `checkAndFetch` |
| `…/WebExt/ExtInstance.swift` (modify init) | carry `remoteSource` |
| `WarboardIOS/Resources/torntools/*` (replace) | patched 9.0.6 seed |

> Reality check: every Swift file above is in `Userscripts/WebExt/`, which compiles **only on Mac CI**. Pure logic (`compareVersions`) gets an XCTest that runs on CI; locally I sanity-check the algorithm with a standalone `swift` snippet. The fetch/cache/serve integration is verified on-device via TestFlight + WebDiag.

---

# PART S — Server (packaging + hosting)

### Task S1: prelude file + `package-torntools.mjs`

**Files:** Create `server/data/torntools-prelude.js`, `server/bin/package-torntools.mjs`. Test: `server/bin/package-torntools.test.mjs`.

- [ ] **Step 1: Write the prelude file** — `server/data/torntools-prelude.js` (verbatim, the exact 14-line prelude currently in the bundle):

```js
/* warboard: TornTools' background is an MV3 service worker; we run it in a plain
   hidden page. Stub the service-worker-only globals + chrome.offscreen so the
   bundle doesn't throw on load. Runs after the browser shim (injected first). */
(function () {
  try {
    var g = self;
    if (typeof g.skipWaiting !== 'function') g.skipWaiting = function () { return Promise.resolve(); };
    if (typeof g.clients === 'undefined') g.clients = { claim: function () { return Promise.resolve(); }, matchAll: function () { return Promise.resolve([]); }, openWindow: function () { return Promise.resolve(null); } };
    if (typeof g.registration === 'undefined') g.registration = { showNotification: function () { return Promise.resolve(); }, getNotifications: function () { return Promise.resolve([]); }, scope: location.origin + '/', update: function () { return Promise.resolve(); } };
    if (typeof g.importScripts !== 'function') g.importScripts = function () {};
    var c = window.chrome || window.browser;
    if (c && !c.offscreen) c.offscreen = { createDocument: function () { return Promise.resolve(); }, closeDocument: function () { return Promise.resolve(); }, hasDocument: function () { return Promise.resolve(false); } };
  } catch (e) { console.log('[warboard] tt prelude error', e); }
})();
```

- [ ] **Step 2: Write the failing test** — `server/bin/package-torntools.test.mjs`:

```js
import assert from "node:assert";
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { packageTornTools } from "./package-torntools.mjs";

// minimal fake stock build
const stock = mkdtempSync(join(tmpdir(), "tt-stock-"));
writeFileSync(join(stock, "manifest.json"), JSON.stringify({ name: "TornTools", version: "9.0.6" }));
writeFileSync(join(stock, "background.js"), "/*stockbg*/console.log('bg');");
mkdirSync(join(stock, "content-scripts"));
writeFileSync(join(stock, "content-scripts", "extension.js"), "/*cs*/");
writeFileSync(join(stock, "_bg.html"), "<html></html>");

const out = mkdtempSync(join(tmpdir(), "tt-out-"));
const res = packageTornTools({ stockDir: stock, outDir: out, version: "9.0.6.1", baseUrlPath: "/ext/torntools/" });

const verDir = join(out, "9.0.6.1");
// prelude prepended to _background.js
const bg = readFileSync(join(verDir, "_background.js"), "utf8");
assert.ok(bg.includes("warboard: TornTools' background"), "prelude prepended");
assert.ok(bg.includes("/*stockbg*/"), "stock bg retained");
// manifest version is the re-seed marker
assert.strictEqual(JSON.parse(readFileSync(join(verDir, "manifest.json"), "utf8")).version, "9.0.6.1");
// version.json shape + sha256 self-consistency
const vj = JSON.parse(readFileSync(join(out, "version.json"), "utf8"));
assert.strictEqual(vj.version, "9.0.6.1");
assert.strictEqual(vj.base, "/ext/torntools/9.0.6.1/");
assert.ok(vj.files.find(f => f.path === "_background.js"), "_background.js listed");
import { createHash } from "node:crypto";
for (const f of vj.files) {
  const sha = createHash("sha256").update(readFileSync(join(verDir, f.path))).digest("hex");
  assert.strictEqual(sha, f.sha256, `sha256 matches for ${f.path}`);
}
console.log("OK", res.fileCount, "files");
```

- [ ] **Step 3: Run it, verify it fails** → `node server/bin/package-torntools.test.mjs` → FAIL (module missing).

- [ ] **Step 4: Implement** `server/bin/package-torntools.mjs`:

```js
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, rmSync, existsSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PRELUDE = readFileSync(join(__dirname, "..", "data", "torntools-prelude.js"), "utf8");

function walk(dir, base = dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p, base));
    else out.push(relative(base, p).split("\\").join("/"));
  }
  return out;
}
const copy = (src, dst) => { mkdirSync(dirname(dst), { recursive: true }); writeFileSync(dst, readFileSync(src)); };

// stockDir = unpacked stock TornTools; version = manifest re-seed marker; outDir = public/ext/torntools
export function packageTornTools({ stockDir, outDir, version, baseUrlPath = "/ext/torntools/" }) {
  const verDir = join(outDir, version);
  if (existsSync(verDir)) rmSync(verDir, { recursive: true, force: true });
  mkdirSync(verDir, { recursive: true });

  for (const rel of walk(stockDir)) copy(join(stockDir, rel), join(verDir, rel));

  // patch #1: _background.js = prelude + stock background.js
  writeFileSync(join(verDir, "_background.js"), PRELUDE + "\n" + readFileSync(join(stockDir, "background.js"), "utf8"));
  // patch #2: manifest version = re-seed marker
  const mani = JSON.parse(readFileSync(join(verDir, "manifest.json"), "utf8"));
  mani.version = version;
  writeFileSync(join(verDir, "manifest.json"), JSON.stringify(mani));

  // version.json over the FINAL tree (incl _background.js)
  const files = walk(verDir).map((path) => {
    const data = readFileSync(join(verDir, path));
    return { path, sha256: createHash("sha256").update(data).digest("hex"), bytes: data.length };
  });
  const versionJson = { id: "torntools", version, upstream: mani.upstream ?? version,
    minSeedVersion: version, base: baseUrlPath + version + "/", files };
  writeFileSync(join(outDir, "version.json"), JSON.stringify(versionJson, null, 2));
  return { fileCount: files.length, versionDir: verDir };
}

// CLI: node package-torntools.mjs <stockDir> <version>
if (process.argv[1] && process.argv[1].endsWith("package-torntools.mjs") && process.argv[2]) {
  const out = join(__dirname, "..", "public", "ext", "torntools");
  const r = packageTornTools({ stockDir: process.argv[2], outDir: out, version: process.argv[3] || "9.0.6" });
  console.log(`packaged ${r.fileCount} files -> ${r.versionDir}`);
}
```

- [ ] **Step 5: Run it, verify it passes** → `node server/bin/package-torntools.test.mjs` → `OK <n> files`.
- [ ] **Step 6: Commit** → `git add server/data/torntools-prelude.js server/bin/package-torntools.mjs server/bin/package-torntools.test.mjs && git commit -m "server: package-torntools.mjs (patch stock build -> /ext/torntools + version.json)"`

### Task S2: package + serve real 9.0.6

**Files:** generated `server/public/ext/torntools/version.json` + `9.0.6/…`.

- [ ] **Step 1: Fetch + unpack the stock 9.0.6 Chrome build**

```bash
cd /opt/warboard/server
curl -sL -o /tmp/tt-9.0.6.zip "https://github.com/Mephiles/torntools_extension/releases/download/9.0.6/torntools-extension-9.0.6-chrome.zip"
mkdir -p /tmp/tt-9.0.6 && (cd /tmp/tt-9.0.6 && unzip -oq /tmp/tt-9.0.6.zip)
ls /tmp/tt-9.0.6/manifest.json /tmp/tt-9.0.6/background.js   # sanity: expected stock files
```
(`unzip` exists on the Linux server even though iOS lacks it.)

- [ ] **Step 2: Package** → `node server/bin/package-torntools.mjs /tmp/tt-9.0.6 9.0.6` → writes `public/ext/torntools/version.json` + `public/ext/torntools/9.0.6/…`. Expected: `packaged <n> files`.

- [ ] **Step 3: Verify served** (static, no reload) →

```bash
curl -s "http://127.0.0.1:3000/ext/torntools/version.json" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['version'],d['base'],len(d['files']))"
curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:3000/ext/torntools/9.0.6/manifest.json"   # expect 200
curl -s "http://127.0.0.1:3000/ext/torntools/9.0.6/_background.js" | head -1   # expect the warboard prelude banner
```

- [ ] **Step 4: Commit** → `git add server/public/ext/torntools && git commit -m "server: publish patched TornTools 9.0.6 at /ext/torntools" && git push origin HEAD`

---

# PART I — iOS

### Task I1: `RemoteExtStore` core (`containerBase` + `compareVersions`)

**Files:** Create `…/WebExt/RemoteExtStore.swift`. Test: `…/WebExtTests/RemoteExtStoreTests.swift` (Mac-CI XCTest).

- [ ] **Step 1: Write the failing test** (version compare — the pure, testable core):

```swift
import XCTest
@testable import WarboardIOS

final class RemoteExtStoreTests: XCTestCase {
    func testCompareVersions() {
        XCTAssertEqual(RemoteExtStore.compareVersions("9.0.6", "9.0.5.1"), 1)   // 9.0.6 > 9.0.5.1
        XCTAssertEqual(RemoteExtStore.compareVersions("9.0.5.1", "9.0.5"), 1)   // 4-part > 3-part
        XCTAssertEqual(RemoteExtStore.compareVersions("9.0.6", "9.0.6"), 0)
        XCTAssertEqual(RemoteExtStore.compareVersions("9.0.5", "9.0.6"), -1)
        XCTAssertEqual(RemoteExtStore.compareVersions("10.0.0", "9.9.9"), 1)
    }
}
```
Locally sanity-check the algorithm: `swift -e 'func c(_ a:String,_ b:String)->Int{let pa=a.split(separator:".").map{Int($0) ?? 0};let pb=b.split(separator:".").map{Int($0) ?? 0};for i in 0..<max(pa.count,pb.count){let x=i<pa.count ?pa[i]:0,y=i<pb.count ?pb[i]:0;if x != y {return x<y ? -1:1}};return 0}; print(c("9.0.6","9.0.5.1"), c("9.0.5.1","9.0.5"), c("9.0.6","9.0.6"))'` → expect `1 1 0`.

- [ ] **Step 2: Implement** `RemoteExtStore.swift`:

```swift
import Foundation

/// Decides, per launch, whether each WebExtension's files are served from a
/// server-fetched cache (…/Application Support/webext-remote/<id>/) or the app
/// bundle (the seed). The cache wins only when it is valid and its version is
/// >= the bundled seed's. Also performs the background update fetch (checkAndFetch).
final class RemoteExtStore {
    static let shared = RemoteExtStore()

    private let fm = FileManager.default
    private let defaults = UserDefaults(suiteName: "group.com.tornwar.warboard") ?? .standard
    private var containerCache: [String: URL] = [:]
    private let lock = NSLock()

    private var remoteDir: URL? {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("webext-remote", isDirectory: true)
    }
    private var bundleBase: URL { Bundle.main.resourceURL ?? URL(fileURLWithPath: "/") }

    /// Directory callers append "<id>/<path>" to. Memoized per launch.
    func containerBase(for id: String) -> URL {
        lock.lock(); defer { lock.unlock() }
        if let c = containerCache[id] { return c }
        let chosen = resolveContainer(for: id)
        containerCache[id] = chosen
        return chosen
    }

    private func resolveContainer(for id: String) -> URL {
        guard let remoteDir,
              let cacheVer = manifestVersion(at: remoteDir.appendingPathComponent("\(id)/manifest.json"))
        else { return bundleBase }
        let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
        return Self.compareVersions(cacheVer, seedVer) >= 0 ? remoteDir : bundleBase
    }

    func manifestVersion(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let v = obj["version"] as? String else { return nil }
        return v
    }

    /// Numeric component-wise compare of dotted versions. -1 / 0 / 1.
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}
```

- [ ] **Step 3: Verify** — local snippet prints `1 1 0`; the XCTest runs on Mac CI (Step 6 of I6). Commit:
`git add WarboardIOS/Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift WarboardIOS/Tests/WebExtTests/RemoteExtStoreTests.swift && git commit -m "RemoteExtStore: containerBase + version compare (cache-vs-bundle seed resolution)"`

### Task I2: route the 4 bundle reads through `containerBase`

**Files:** Modify `ExtResourceScheme.swift:37`, `ExtManifest.swift:47`, `ExtInstance.swift:188`, `ExtBackgroundHost.swift:195`.

- [ ] **Step 1: `ExtResourceScheme.swift`** — replace the bundle base (keep `relative = host + url.path`):

```swift
        // was: guard let base = Bundle.main.resourceURL else { … }
        let base = RemoteExtStore.shared.containerBase(for: host)
        let fileURL = base.appendingPathComponent(relative)
```

- [ ] **Step 2: `ExtManifest.swift`** — `load(id:)` base:

```swift
    static func load(id: String) -> ExtManifest? {
        let base = RemoteExtStore.shared.containerBase(for: id)
        let url = base.appendingPathComponent("\(id)/manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ExtManifest.self, from: data)
        else { return nil }
        return manifest
    }
```

- [ ] **Step 3: `ExtInstance.swift`** — `bundledText`:

```swift
    private func bundledText(_ relativePath: String) -> String? {
        let base = RemoteExtStore.shared.containerBase(for: id)
        guard let data = try? Data(contentsOf: base.appendingPathComponent("\(id)/\(relativePath)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
```

- [ ] **Step 4: `ExtBackgroundHost.swift`** — `bundled`:

```swift
    private func bundled(_ name: String) -> String? {
        let base = RemoteExtStore.shared.containerBase(for: id)
        guard let data = try? Data(contentsOf: base.appendingPathComponent("\(id)/\(name)")),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
```

- [ ] **Step 5: Commit** → `git commit -am "WebExt: resolve all 4 bundle reads through RemoteExtStore.containerBase"`
  (Compile verified on Mac CI in I6. Note: `_bg.html` is loaded via `webext://<id>/_bg.html` → already routed through ExtResourceScheme in Step 1.)

### Task I3: `ExtInstance.remoteSource` + runtime wiring

**Files:** Modify `ExtInstance.swift` (init), `ExtensionRuntime.swift` (catalog + launch check).

- [ ] **Step 1: `ExtInstance.swift`** — add a stored `remoteSource` and accept it in init:

```swift
    let remoteSource: URL?
    // …
    init?(id: String, name: String, attribution: String, remoteSource: URL? = nil,
          mainWorldInjects: [String] = [], injectorSuffix: String? = nil, debug: Bool = false) {
        guard let manifest = ExtManifest.load(id: id) else { return nil }
        self.id = id
        self.name = name
        self.attribution = attribution
        self.remoteSource = remoteSource
        self.manifest = manifest
        // … rest unchanged …
```

- [ ] **Step 2: `ExtensionRuntime.swift`** — set TornTools' `remoteSource` in the catalog (line ~46):

```swift
            ExtInstance(id: "torntools", name: "TornTools", attribution: "Mephiles",
                        remoteSource: URL(string: "https://tornwar.com/ext/torntools/version.json")),
```

- [ ] **Step 3: `ExtensionRuntime.swift`** — kick the silent launch check at the end of `init()`:

```swift
        // Background: check the server for newer copies of remote-sourced
        // extensions. Applies on the NEXT launch (containerBase is fixed now).
        Task.detached(priority: .utility) { [instances] in
            for inst in instances {
                guard let src = inst.remoteSource else { continue }
                await RemoteExtStore.shared.checkAndFetch(id: inst.id, source: src)
            }
        }
```

- [ ] **Step 4: Commit** → `git commit -am "WebExt: TornTools remoteSource + silent launch update check"`

### Task I4: `RemoteExtStore.checkAndFetch` (download + verify + atomic install)

**Files:** Modify `RemoteExtStore.swift` (add `checkAndFetch` + sha256 + the manifest model).

- [ ] **Step 1: Implement** (append to `RemoteExtStore.swift`):

```swift
import CryptoKit

private struct RemoteVersionManifest: Decodable {
    let version: String
    let base: String
    let minSeedVersion: String?
    let files: [Entry]
    struct Entry: Decodable { let path: String; let sha256: String }
}

extension RemoteExtStore {
    /// Silent: fetch version.json; if newer than the active copy (and the bundled
    /// seed isn't newer than minSeedVersion), download every file (sha256-verified)
    /// into staging and atomic-swap into …/webext-remote/<id>/. Applies next launch.
    func checkAndFetch(id: String, source: URL) async {
        guard let remoteDir,
              let host = source.scheme.flatMap({ s in source.host.map { "\(s)://\($0)" } }) else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: source)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let man = try? JSONDecoder().decode(RemoteVersionManifest.self, from: data) else { return }

            let activeVer = manifestVersion(at: containerBase(for: id).appendingPathComponent("\(id)/manifest.json")) ?? "0"
            guard Self.compareVersions(man.version, activeVer) > 0 else { return }
            let seedVer = manifestVersion(at: bundleBase.appendingPathComponent("\(id)/manifest.json")) ?? "0"
            if let minSeed = man.minSeedVersion, Self.compareVersions(seedVer, minSeed) > 0 { return }

            let staging = remoteDir.appendingPathComponent("\(id).incoming", isDirectory: true)
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)

            for f in man.files {
                guard let fileURL = URL(string: host + man.base + f.path) else { throw URLError(.badURL) }
                let (fdata, fresp) = try await URLSession.shared.data(from: fileURL)
                guard (fresp as? HTTPURLResponse)?.statusCode == 200,
                      SHA256.hash(data: fdata).map({ String(format: "%02x", $0) }).joined() == f.sha256 else {
                    try? fm.removeItem(at: staging); return
                }
                let dest = staging.appendingPathComponent(f.path)
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fdata.write(to: dest)
            }
            guard manifestVersion(at: staging.appendingPathComponent("manifest.json")) != nil else {
                try? fm.removeItem(at: staging); return
            }
            let live = remoteDir.appendingPathComponent(id, isDirectory: true)
            try fm.createDirectory(at: remoteDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: live.path) {
                _ = try fm.replaceItemAt(live, withItemAt: staging)
            } else {
                try fm.moveItem(at: staging, to: live)
            }
            defaults.set(man.version, forKey: "webext-remote-version.\(id)")
            WebDiag.log("webext-remote-updated", ["id": id, "version": man.version])
        } catch {
            WebDiag.log("webext-remote-fetch-error", ["id": id, "error": "\(error)"])
        }
    }
}
```

- [ ] **Step 2: Commit** → `git commit -am "RemoteExtStore: checkAndFetch — per-file download, sha256 verify, atomic install"`
  (Verified on-device in I6: bump the server version, relaunch twice, confirm `webext-remote-updated` in WebDiag + the new TornTools version active.)

### Task I5: seed patched TornTools 9.0.6 into the app bundle

**Files:** Replace `WarboardIOS/Resources/torntools/*`.

- [ ] **Step 1: Produce the patched seed** (reuse the packaging output — the seed and the first server copy are byte-identical):

```bash
# on the box that has the packaged tree (from Task S2):
rm -rf /root/projects/warboard-ios/WarboardIOS/Resources/torntools/*
cp -R /opt/warboard/server/public/ext/torntools/9.0.6/. /root/projects/warboard-ios/WarboardIOS/Resources/torntools/
```

- [ ] **Step 2: Verify the seed** — `_background.js` starts with the warboard prelude, `manifest.json` version is the re-seed marker, `_bg.html` present:

```bash
cd /root/projects/warboard-ios/WarboardIOS/Resources/torntools
head -1 _background.js                                   # warboard prelude banner
python3 -c "import json;print(json.load(open('manifest.json'))['version'])"  # 9.0.6 (re-seed marker)
ls _bg.html background.js manifest.json content-scripts >/dev/null && echo "seed structure OK"
```

- [ ] **Step 3: Commit** → `git add WarboardIOS/Resources/torntools && git commit -m "Seed patched TornTools 9.0.6 (replaces 9.0.5.1)"`

### Task I6: ship — version bump, CI build, on-device verify

**Files:** Modify `MARKETING_VERSION` (project), tag.

- [ ] **Step 1: Bump `MARKETING_VERSION`** (find current, +0.0.1) in the Xcode project / build settings.
- [ ] **Step 2: Push branch + tag** (CI builds on the **tag**, per the pipeline):
```bash
cd /root/projects/warboard-ios
git commit -am "Bump version for remote-ext loader + TornTools 9.0.6"
git push origin HEAD
git tag v<MARKETING_VERSION> && git push origin v<MARKETING_VERSION>
```
- [ ] **Step 3: Watch CI** → `gh run watch <id> --exit-status`; confirm "TestFlight upload succeeded" / SIGNED_IPA and the RemoteExtStoreTests pass on the Mac runner.
- [ ] **Step 4: On-device (TestFlight)** — install; open Torn; WebDiag/`webext-bg-health` shows TornTools `onMessage` listeners > 0, no `webext-dispatch-null` storm; TornTools reports **9.0.6**. Airplane-mode launch still loads TornTools (seed).
- [ ] **Step 5: Server-update round-trip** — bump the server (`package-torntools.mjs … 9.0.6.1`, push), relaunch the app **twice**; confirm `webext-remote-updated` in the logs and TornTools now serves from the cache (no app rebuild).

---

## Self-review

- **Spec coverage:** RemoteExtStore/containerBase → I1; 4-site base-swap → I2; remoteSource + launch check → I3; checkAndFetch (download/verify/atomic, minSeedVersion, silent) → I4; server packaging + prelude + version.json + hosting → S1/S2; seed 9.0.6 → I5; ship + on-device verify → I6. The spec's `max(bundle,cached)` is `resolveContainer` (`compareVersions(cache, seed) >= 0`); re-seed is automatic (manifest version differs → existing `maybeFireInstalled`). Covered.
- **Placeholder scan:** every code step is complete; no "add error handling" (each failure path returns/keeps last-good explicitly). `<MARKETING_VERSION>`/`<id>` in I6 are real shell substitutions, not placeholders.
- **Type consistency:** `containerBase(for:) -> URL` used identically at all 4 sites + in `checkAndFetch`/`resolveContainer`; `manifestVersion(at:)`, `compareVersions(_:_:)`, `remoteSource: URL?`, the `version.json` shape (`version`/`base`/`minSeedVersion`/`files[].{path,sha256}`) match between `package-torntools.mjs` and `RemoteVersionManifest`.
- **Risk:** Swift compiles only on Mac CI — keep diffs mechanical; the one substantive new file (`RemoteExtStore`) has a CI XCTest for the pure core; integration verified on-device (I6 steps 4–5).

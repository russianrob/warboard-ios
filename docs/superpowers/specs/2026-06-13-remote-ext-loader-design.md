# Remote-Extension Loader (warboard-iOS) — Design

**Date:** 2026-06-13
**Status:** Approved (design)
**Repos:** `/root/projects/warboard-ios` (iOS app) + `/opt/warboard` (server)

## Goal

Let the warboard-iOS WebExtension runtime **fetch a bundled extension's files from the warboard server at runtime** and serve them through the existing `ExtResourceScheme`, with the in-app bundled copy as the **offline seed / fallback** — so **TornTools updates ship from the server with no App Store / TestFlight cycle**. The first app build carrying this loader also bundles the **patched TornTools 9.0.6** as the new seed, so 9.0.6 is live immediately and the server takes over thereafter.

## Background (verified by assessment, 2026-06-13)

- The WebExt runtime is **generic + manifest-driven**. `ExtensionRuntime` holds a catalog of `ExtInstance(id:…)` (currently `retorn` + `torntools`, TornTools opt-in). Per-extension files live in `Resources/<id>/`. `ExtManifest` parses `<id>/manifest.json`. `ExtResourceScheme.webView(_:start:)` resolves `webext://<id>/<path>` → `relative = host + url.path` → `Bundle.main.resourceURL.appendingPathComponent(relative)` → `Data(contentsOf:)`. `ExtBackgroundHost` loads the `_`-prefixed `_background.js` + navigates `_bg.html` (the manifest's `service_worker` is ignored).
- Bundled TornTools = **stock upstream 9.0.5 + exactly two local patches**: (1) `torntools/_background.js` = a 14-line warboard prelude (stubs `skipWaiting/clients/registration/importScripts` + `chrome.offscreen`) prepended to the stock `background.js`; (2) `torntools/manifest.json` `version` bumped (`9.0.5`→`9.0.5.1`) to trigger `maybeFireInstalled` → re-seed settings. The stock `background.js` is kept alongside, unused by the host.
- **All real runtime shims are in Swift** (off-main `@MainActor` dispatch in `ExtBackgroundHost`, NSNull-safe `ExtStorage`, `maybeFireInstalled`/`fireStartup` seeding, `browser.alarms` + native timers, `Notification` stub in `WebExtShimJS`) — they **survive a file swap**. Only the 14-line prelude + the manifest re-seed version are baked into the TornTools files and must be re-applied per update.
- App storage: `.applicationSupportDirectory` (userscript caches: `RequireCache`, `GMStore`, `ScriptRegistry`) + App-Group `UserDefaults(suiteName: "group.com.tornwar.warboard")` (`ExtStorage`, `ExtensionPrefs`).
- Precedent: `ScriptsView.checkForUpdates()` already fetches a remote version and compares `installed.version` vs `remote.version` for userscripts.
- Latest upstream TornTools = **9.0.6** (prebuilt Chrome zip on the GitHub release; bundled is 9.0.5.1, one release behind). 9.0.6 needs **no new MV3 permissions/capabilities** vs 9.0.5.

## Scope

**In:** the remote loader (`RemoteExtStore` + a base-swap in `ExtResourceScheme`/`ExtManifest` + an `ExtInstance.remoteSource`), **silent auto-check on launch, apply on next launch**, server hosting + a packaging script, and bundling patched **9.0.6** as the seed. The mechanism is **general (id-keyed)**; only **TornTools** is wired to a server source initially.

**Out (YAGNI):** remote-serving ReTorn (stays bundle-only), live in-session hot-swap, a manual "check for updates" button, delta/partial updates, code signing beyond per-file sha256.

## Transport — per-file download from a manifest (refinement of the design's "zip")

The design said "download the zipped extension," but **iOS has no public Foundation API to unzip a `.zip`**, and a zip library would be a new SwiftPM dependency. Instead the server exposes a **manifest + the files**, and the app downloads files individually — dependency-free, binary-safe, resumable, and aligned with how warboard already serves userscripts per-URL.

**`GET /ext/torntools/version.json`:**
```jsonc
{
  "id": "torntools",
  "version": "9.0.6.1",              // the manifest version (re-seed marker), 4-part
  "upstream": "9.0.6",              // informational
  "minSeedVersion": "9.0.6",        // refuse-to-apply if the BUNDLED seed is newer than this
  "base": "/ext/torntools/9.0.6.1/", // version-pinned dir so a half-published update is never mixed
  "files": [
    { "path": "manifest.json", "sha256": "…", "bytes": 1796 },
    { "path": "_background.js", "sha256": "…", "bytes": 320811 },
    { "path": "content-scripts/extension.js", "sha256": "…", "bytes": … }
    // … every file in the extension tree, relative paths
  ]
}
```
Files are served as static assets at `/ext/torntools/<version>/<path>` (same static mechanism as `/scripts/*`).

## Architecture & boundaries

- **`RemoteExtStore.swift`** (new — the one real new unit). Responsibilities:
  - `activeBase(for id: String) -> URL` — the directory `ExtResourceScheme`/`ExtManifest` resolve `<id>` against: the cached server copy at `…/Application Support/webext-remote/<id>/` **iff** it exists, its `manifest.json` parses, and its version ≥ the bundled seed's version; otherwise `Bundle.main.resourceURL`. Pure + synchronous (called on every resource request — caches the decision per launch).
  - `checkAndFetch(_ inst: ExtInstance) async` — if `inst.remoteSource` is set: `GET version.json`; parse; if `remote.version > activeVersion` **and** `bundleSeedVersion <= remote.minSeedVersion`, download each `files[]` entry to `…/webext-remote/<id>.incoming/<path>`, verify per-file sha256, then **atomically** `replaceItemAt` `…/webext-remote/<id>/` with the staging dir; record the installed version in App-Group `UserDefaults` (`webext-remote-version.<id>`). Any failure → discard staging, keep current. Applies on **next launch** (`activeBase` is fixed for the session).
  - version compare helper for 4-part versions (`9.0.6` vs `9.0.5.1`): split on `.`, pad, numeric-compare component-wise.
- **`ExtResourceScheme.swift`** — change the one line: `base = RemoteExtStore.shared.activeBase(for: host)` instead of `Bundle.main.resourceURL` (then `base.appendingPathComponent(host + url.path)` becomes `activeBase + url.path`, since `activeBase` already includes `<id>`). Keep the existing failure path.
- **`ExtManifest.swift`** — read `<id>/manifest.json` from `RemoteExtStore.shared.activeBase(for: id)` rather than `Bundle.main.resourceURL/<id>`.
- **`ExtInstance.swift`** — add `let remoteSource: URL?` (default `nil`). `ExtensionRuntime` sets it only for TornTools (`URL(string: "https://tornwar.com/ext/torntools/version.json")`).
- **`ExtensionRuntime`** — after the runtime boots at launch, fire `Task { for inst in instances where inst.remoteSource != nil { await RemoteExtStore.shared.checkAndFetch(inst) } }` (background, non-blocking, silent).
- **Server** — host `version.json` + the version-pinned file tree under `server/public/ext/torntools/` (served by the existing `express.static(public)`). `bin/package-torntools.mjs` (new) produces them.

## Data flow

1. **At launch:** `activeBase(torntools)` = the valid cached copy (version ≥ seed) if present, else the bundle. The extension loads from that base for the whole session.
2. **Just after launch (silent, background):** `checkAndFetch` GETs `version.json`. If a newer version is offered (and the bundled seed isn't newer than `minSeedVersion`), it downloads the file tree to `…/torntools.incoming/`, verifies every sha256, atomic-swaps to `…/torntools/`, records the version. **Applies next launch.**
3. **Seed / offline:** first run, server unreachable, or any failure → the **bundle**. A future app build bundling a *newer* seed wins via `max(bundleVersion, cachedVersion)`, so the cache never shadows a newer bundled TornTools (and `minSeedVersion` lets the server explicitly refuse to downgrade a newer seed).

## Server side — `bin/package-torntools.mjs`

Input: a stock TornTools build (the unpacked 9.0.6 Chrome zip). Steps:
1. Copy the stock tree to `server/public/ext/torntools/<version>/`.
2. Apply patch #1: write `_background.js` = the 14-line warboard prelude (kept in `server/data/torntools-prelude.js`, source-controlled) + the stock `background.js`. Ensure `_bg.html` exists (copy the convention file).
3. Apply patch #2: set `manifest.json` `version` to `<version>` (the re-seed marker — distinct from upstream when upstream is unchanged).
4. Walk the tree, compute per-file sha256 + bytes, write `version.json` (with `base`, `minSeedVersion`, `files[]`).
5. Idempotent; re-runnable per upstream release.

`/ext/*` is served by the existing `express.static(public)` (no route code). Attribution + read-only; the prelude lives in the warboard repo, not fetched from Crimehub/TornTools.

## Error handling & safety

- **Atomic install only on full success** (all files downloaded + every sha256 matches + `manifest.json` parses); otherwise discard staging, keep the last good copy. Never half-apply.
- **Corrupt cache at launch** (manifest won't parse) → `activeBase` falls back to the bundle.
- **Server unreachable / 404 / malformed `version.json`** → silent no-op.
- Every failure is **silent** (no user-facing error); the extension always runs from the last known-good copy.
- **Re-seed:** when the applied `manifest.json` version differs from the last-seeded `storedVersion`, the existing `maybeFireInstalled` fires `onInstalled(reason:update)` → settings migrate. (`version.json.version` IS the manifest version, so this is automatic.)

## App Store & security

- The **bundled seed** makes the app fully functional offline / on first launch with **no download** — the server fetch is an *update*, not a requirement. This is the defensible framing for the remote-code gray area (already accepted): warboard is a browser host already running remote userscript JS in web views; this serves an extension's web files the same way.
- HTTPS to warboard's own server; **per-file sha256 verified** before an atomic apply; no third-party host.

## This build: seed TornTools 9.0.6

Replace `Resources/torntools/` with the **patched 9.0.6** (stock 9.0.6 + the 14-line `_background.js` prelude + the manifest re-seed version), so 9.0.6 is live immediately even before any server fetch. Produced by the same `package-torntools.mjs` (the seed and the first server copy are byte-identical).

## Testing / verification

- **Locally (node):** `package-torntools.mjs` output (file tree, prelude correctly prepended, manifest version, `version.json` sha256s self-consistent).
- **Locally (Swift logic):** the 4-part version compare + `activeBase` selection (newer-cache-wins, newer-seed-wins, corrupt-cache-falls-back) as pure unit tests where the SwiftPM package builds on Linux; the WebExt/WebKit pieces compile **only on Mac CI**.
- **On-device (TestFlight):** WebDiag / `webext-bg-health` shows TornTools `onMessage` listeners > 0, no `webext-dispatch-null` storm; force a server bump and confirm the app picks it up on the **second** launch; airplane-mode launch still loads TornTools from the seed.

## Files

**iOS — create:** `Sources/WarboardIOS/Userscripts/WebExt/RemoteExtStore.swift`.
**iOS — modify:** `ExtResourceScheme.swift` (base via `RemoteExtStore`), `ExtManifest.swift` (base via `RemoteExtStore`), `ExtInstance.swift` (`remoteSource`), `ExtensionRuntime.swift` (set TornTools `remoteSource` + launch `checkAndFetch`), `Resources/torntools/*` (seed 9.0.6 + prelude + manifest version), `MARKETING_VERSION` bump + `v<version>` tag (CI → TestFlight).
**Server — create:** `bin/package-torntools.mjs`, `server/data/torntools-prelude.js`, `server/public/ext/torntools/version.json` + `server/public/ext/torntools/<version>/…`.
**Server — modify:** none (static serving already covers `/ext/*`).

## Open items / risks

- **Mac-only compile:** the WebExt Swift changes can't be compiled locally (Linux Package.swift excludes WebKit/SwiftUI). Mitigation: keep the diff small + mechanical, lean on the pure-logic unit tests, verify on CI + on-device.
- **Prelude drift:** the 14-line prelude must be re-applied by `package-torntools.mjs` every update — it's source-controlled in `server/data/torntools-prelude.js` and applied by the script, so it can't be forgotten.
- **Version-compare edge cases** (4-part `9.0.5.1` vs 3-part `9.0.6`): covered by the padded numeric compare + unit tests.
- **First-fetch timing:** a server update applies on the *second* launch after it's published (launch N fetches, launch N+1 applies) — acceptable per the silent-auto choice.

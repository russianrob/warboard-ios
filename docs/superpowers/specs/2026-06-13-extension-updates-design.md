# Visible + Manual Extension Updates — Design Spec

**Date:** 2026-06-13
**Status:** Approved (design + tab badge)

## Goal

Make WebExtension updates (TornTools, and any future remote-sourced extension)
**visible** and **manually installed**, instead of silently auto-downloaded in
the background. The user wants to *see* that an update exists and choose to
install it. When they install, it applies **live (no relaunch)**.

This replaces the current behavior: `ExtensionRuntime.init` fires a
`Task.detached { RemoteExtStore.checkAndFetch }` at every launch that silently
downloads the whole new version and applies it on the *next* launch — opaque,
uses data without consent, and confusing (the user saw the version lag for hours
with no feedback).

## Background (current runtime, verified)

- `RemoteExtStore` chooses, per launch, whether each extension loads from the
  server cache (`…/Application Support/webext-remote/<id>/`) or the app bundle
  seed. `containerBase(for:)` is **memoized per launch**; `resolveContainer`
  picks the cache when the cache `manifest.json` `version` ≥ the seed version.
- Every resource read is cache-aware through `containerBase`: content scripts
  (`ExtInstance.bundledText` → injection), the manifest (`ExtManifest.load`),
  the version label (`ScriptsView` → `ExtInstance.info.version`), the background
  script (`ExtBackgroundHost.bundled`), and `webext://` page fetches
  (`ExtResourceScheme`). There is **no** bundle-hardcoded bypass.
- `ExtInstance.manifest` is a `let`, loaded once in `init`; `instances` is built
  once in the `ExtensionRuntime` singleton init. So a freshly-downloaded update
  only surfaces on the next launch — that is the *only* reason the current model
  needs a relaunch.
- Applying script changes live already works: the extension on/off toggle posts
  `.userscriptsDidChange`; `BrowserView` observes it (`BrowserView.swift:299`)
  and calls `model.reload()`, which re-runs `rebuildUserScripts` and re-injects
  content scripts from `containerBase`. The live-apply path reuses this.
- The Scripts screen is a sheet opened from a `doc.text.fill` button in the
  browser chrome (`BrowserView.swift:444`) — there is **no `TabView`**, so the
  "tab badge" is a badge dot on that button.

## Components

### 1. `RemoteExtStore` — split check from install

Refactor today's monolithic `checkAndFetch(id:source:)` into two public methods
and a cache invalidator. Keep `resolveContainer` / `containerBase` unchanged.

- `func checkForUpdate(id:source:) async -> String?`
  - Fetch only `version.json` (~15 KB). Parse `RemoteVersionManifest`.
  - Compute `activeVer` via `containerBase` (as today, line 73).
  - Apply the same guards: `VersionCompare.isUpdate(installed: activeVer, remote: man.version)`
    and the `minSeedVersion` floor (`compare(seedVer, minSeed) == .orderedDescending → nil`).
  - Return `man.version` when a valid newer version exists, else `nil`.
  - **No file download.**
- `func installUpdate(id:source:) async throws -> String`
  - The existing download body: stage dir, per-file sha256-verified download,
    validate the staged manifest parses, atomic swap into `webext-remote/<id>/`,
    persist `webext-remote-version.<id>`, log `webext-remote-updated`.
  - On success call `invalidate(id:)` and return the new version. Throw on any
    failure (caller surfaces it); the live cache is left untouched until the
    atomic swap, so a failure never half-installs.
- `func invalidate(id:)` — `lock`; `containerCache[id] = nil`. So the next
  `containerBase(for: id)` re-resolves and picks the new cache.

`checkAndFetch` is removed (its body moves into `installUpdate`); its launch
call site is deleted.

### 2. `ExtensionUpdateStore` (new) — shared update state

A small `@MainActor final class ExtensionUpdateStore: ObservableObject` singleton
so both the Scripts screen and the browser-chrome badge observe one source.

- `@Published private(set) var available: [String: String]` — extension id →
  available newer version.
- `func check() async` — for each `ExtInstance` with a `remoteSource`, call
  `RemoteExtStore.checkForUpdate`; build the dict; assign on the main actor.
- `func clear(id:)` — remove an id after a successful install.
- `var hasUpdates: Bool { !available.isEmpty }` — drives the badge.

### 3. `ExtensionRuntime` — live reload

- `ExtInstance.manifest`: `let` → `var`; add `func reloadManifest()`:
  `if let m = ExtManifest.load(id: id) { manifest = m; backgroundHost.updateVersion(m.version) }`.
- `ExtensionRuntime.reloadExtension(id:)`:
  1. (cache already invalidated by `installUpdate`)
  2. `instance(id)?.reloadManifest()` — updates `info.version` (UI) + the
     content-script list read by the next injection.
  3. `instance(id)?.backgroundHost.restart()` — recreate the hidden bg webview so
     the new `_background.js` runs; `maybeFireInstalled` then fires
     `onInstalled(update)` (storedVersion ≠ new version) → TornTools migration.
  4. `NotificationCenter.post(.userscriptsDidChange)` → `BrowserView` reloads the
     Torn page → new content scripts inject from the new cache.
- `func checkExtensionUpdate(id:) async -> String?` and
  `func installExtensionUpdate(id:) async throws -> String` — thin wrappers that
  look up the instance's `remoteSource`, delegate to `RemoteExtStore`, and (for
  install) call `reloadExtension(id:)`. Keeps `ScriptsView` talking to
  `ExtensionRuntime`, not `RemoteExtStore` directly.
- Delete the silent `Task.detached { checkAndFetch }` from `init`.

### 4. `ExtBackgroundHost` — restart

- `version`: `let` → `var`; add `func updateVersion(_:)`.
- `func restart()`:
  - Tear down: set `webView?.navigationDelegate = nil`, `webView = nil`,
    `isReady = false`, resume/clear `readyWaiters` is not needed (new start will
    repopulate), reset the install/startup one-shots so they re-evaluate.
  - Call `start()` again (guards on `webView == nil`, now true) → fresh config,
    shim, `_background.js` from the new cache, loads `_bg.html`.
  - On `didFinish`, `maybeFireInstalled` compares `storage.storedVersion` to the
    updated `version` and fires `onInstalled(update)` so the extension migrates.

### 5. `ScriptsViewModel` / `ScriptsView`

- ViewModel observes `ExtensionUpdateStore.shared`. Add
  `func installExtensionUpdate(_ id:) async` → `isWorking = true`;
  `try await ExtensionRuntime.shared.installExtensionUpdate(id)`;
  `ExtensionUpdateStore.shared.clear(id:)`; surface errors in `errorMessage`.
- `extensionsSection`: under each extension show, when
  `ExtensionUpdateStore.shared.available[ext.id]` is set, an orange
  "Install update: `<version>`" button (mirrors the userscript `ScriptRow`
  "Update available" button) calling `installExtensionUpdate(ext.id)`; show a
  `ProgressView` while `isWorking`.
- The existing toolbar refresh button (`arrow.triangle.2.circlepath`, today only
  `vm.checkForUpdates()`) also runs `ExtensionUpdateStore.shared.check()`.
- `ScriptsView.onAppear` runs `ExtensionUpdateStore.shared.check()` (cheap).

### 6. `BrowserView` — badge

- Observe `ExtensionUpdateStore.shared`.
- Overlay a small red dot on the `doc.text.fill` Scripts button
  (`BrowserView.swift:444`) when `hasUpdates`.
- At launch (`BrowserView.onAppear`, already present) kick
  `Task { await ExtensionUpdateStore.shared.check() }` — the cheap version.json
  check, **no download**, so the badge appears without opening Scripts.

### 7. Server `bin/package-torntools.mjs` — drop sourcemaps

- Exclude `*.map` files when copying the stock tree (skip in `walk`/copy, or
  filter before writing). They are devtools-only; the 4 biggest packaged files
  are all `.map` (~15 MB of 31 MB), so this ~halves the download and makes manual
  installs fast. `version.json` then omits them; the app fetches fewer files.
- Re-package stock 9.0.6 as **9.0.6.2** (supersedes 9.0.6.1) — this is the first
  real exercise of the new flow: the user's device will show "Install update:
  9.0.6.2".

## Data flow

```
Launch / open Scripts / tap refresh
        │  ExtensionUpdateStore.check()  (version.json only, per remoteSource ext)
        ▼
available[id] = newerVersion   ──►  badge dot on doc.text.fill (BrowserView)
                               ──►  "Install update: X" row (ScriptsView)
        │  user taps Install
        ▼
ExtensionRuntime.installExtensionUpdate(id)
   └─ RemoteExtStore.installUpdate  (download 16 MB, sha-verify, atomic swap, invalidate)
   └─ reloadExtension(id): reloadManifest → bg restart (onInstalled→migrate)
                          → post .userscriptsDidChange
        ▼
BrowserView reloads Torn page → new content scripts inject from new cache
ScriptsView version label → 9.0.6.2 ; store.clear(id) → badge clears
```

## Error handling

- **Check offline / non-200 / parse fail** → `checkForUpdate` returns `nil`; no
  update shown. Never throws to the UI.
- **Install download fails / sha mismatch** → `installUpdate` throws; the staged
  dir is discarded; the live cache is untouched (no half-install). `ScriptsView`
  shows the error; the badge/row stay (retry available).
- **Live-apply glitch** → best-effort on top of the proven path: the cache is
  already the new version, so a relaunch applies cleanly regardless. The bg
  restart and page reload are independently safe (a nil webview is a no-op).
- **minSeedVersion floor** → an update whose `minSeedVersion` exceeds the bundled
  seed is not offered (the app is too old); same guard as today.

## Testing

- **Linux SwiftPM unit tests** (pure logic):
  - `VersionCompare` 4-component ordering (already covered) — keep.
  - `ExtensionUpdateStore` dict logic: given fake `checkForUpdate` results,
    `available` reflects only true updates; `clear(id:)` removes; `hasUpdates`.
  - `checkForUpdate` decision: a small testable comparator (active vs remote vs
    minSeed) returns the right version / nil. Inject the version.json via a
    stubbed fetch or factor the pure comparison out.
- **Mac CI compile** — the SwiftUI + WebKit changes (`reloadExtension`, bg
  `restart`, badge, row) compile only on macOS; CI archives + ships.
- **On-device** — the live hot-swap (page reload re-injects, version label flips,
  badge clears) verified by installing 9.0.6.2.
- **Server** — assert `version.json` lists zero `*.map` files and total bytes
  drop ~half after the packaging change.

## Out of scope (YAGNI)

- Lifting userscript update state into the shared store / badging userscript
  updates — the badge reflects **extension** updates only (the request). Userscript
  updates keep their current in-sheet behavior.
- Auto-install or scheduled checks — checks run at launch, on Scripts `onAppear`,
  and on the manual refresh button. No background timer.
- Per-file delta updates / partial downloads — full version swap as today.
- A progress bar with byte counts — a `ProgressView` spinner is enough for a
  ~16 MB install.

# WebExt Extension Manager — Design

**Status:** Designed 2026-06-12. **Build queued AFTER ReTorn is confirmed working + WebExt Phase 4.** Do not implement before then (user: "build the manager after retorn").

**Goal:** Let the user turn bundled WebExtensions (ReTorn now, TornTools later) on/off from the in-app Scripts manager screen, so there's a clean kill-switch and a place to manage multiple extensions.

## Decisions (from brainstorming)
- **Scope:** an **Extensions list** (forward-looking for a second extension), not just a single ReTorn toggle.
- **Placement:** inside the existing **Scripts / userscript manager screen** (`ScriptsView`), as its own section — one place that manages everything that runs on Torn pages.

## Architecture

Four small units. Everything lives in the framework target (`Sources/WarboardIOS/Userscripts/`), same target as `ScriptsView` and `ExtensionRuntime`, so no app↔framework closure plumbing is needed.

### 1. `ExtensionPrefs` (Userscripts/ root — NOT WebExt/)
Per-extension enabled flags over App-Group UserDefaults (`group.com.tornwar.warboard`), key `webext.<id>.enabled`, **default `true`** (so existing users keep ReTorn on after the update).
- `isEnabled(_ id: String) -> Bool` (missing key ⇒ true)
- `setEnabled(_ id: String, _ on: Bool)`
- Foundation-only and placed OUTSIDE `WebExt/` so it is included in the Linux `Package.swift` build and unit-testable on Linux CI (the WebExt/ files are WebKit-only and Linux-excluded).

### 2. `ExtensionInfo` + catalog
A value type describing a bundled extension: `id`, `name`, `version`, `attribution` (author/source). `ExtensionRuntime` exposes `installedExtensions: [ExtensionInfo]` built from the loaded manifest(s). For now a single entry: ReTorn (id `retorn`, name "ReTorn", version from `ExtManifest.version`, attribution "Heasleys4hemp").

### 3. `ExtensionRuntime` gating
Gate injection on the enabled flag so a disabled extension does nothing on pages:
- `contentWorldScripts(for:)` returns `[]` for a disabled extension (no shim, no content scripts, no CSS).
- `install(on:)` may still register the resource scheme + relay + start the background host (cheap, hidden), but with no content scripts injected ReTorn is inert. (Keeping the host alive avoids teardown complexity; revisit only if it has side effects.)
- Reads `ExtensionPrefs.isEnabled(id)` at injection time, so a flag change is picked up on the next navigation with no app restart.

### 4. `ScriptsView` — Extensions section
A section above the userscripts list: a row per `ExtensionRuntime.installedExtensions` entry showing name + version + a SwiftUI `Toggle` bound to `ExtensionPrefs`. Flipping the toggle writes the flag and surfaces a subtle "Reload the page to apply" hint. (Optional enhancement, deferred: trigger a reload of the current web view on toggle via an existing closure.)

## Data flow
`ScriptsView` Toggle → `ExtensionPrefs.setEnabled(id, on)` → on the **next** page navigation, `UserscriptController.rebuildUserScripts(for:)` calls `ExtensionRuntime.contentWorldScripts(for:)`, which now returns `[]` for the disabled extension → ReTorn stops injecting.

## Behavior / edge cases
- Toggle is **not** retroactive to an already-loaded page; it applies on next load (content scripts are rebuilt per-navigation). The "reload to apply" hint covers this.
- Default-on means the update is invisible to current users (ReTorn stays on) until they choose to disable it.
- Disabling does not wipe ReTorn's stored data (the App-Group storage + seeded settings persist); re-enabling resumes with prior state.

## Testing
- **Linux CI:** unit-test `ExtensionPrefs` (default-true, set/clear round-trip) — it's Foundation-only and Linux-included.
- **On-device:** verify the Scripts screen lists ReTorn with its version, the toggle persists across launches, and disabling stops ReTorn from affecting Torn pages on the next load.

## Out of scope (YAGNI)
- Installing arbitrary extensions from a URL (only bundled extensions for now).
- Per-feature toggles (ReTorn's own options page covers that — that's WebExt Phase 4).
- Live teardown/reload of the background host on disable.

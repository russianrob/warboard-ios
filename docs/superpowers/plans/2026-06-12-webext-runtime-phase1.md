# WebExtension Runtime — Phase 1 Implementation Plan

> **For agentic workers:** execute task-by-task, CI-green per task. This is native
> WebKit + injected-JS integration: there is **no local compile/test** (the app
> target only builds on macOS CI; behavior is verified on-device) — matching the
> rest of warboard-iOS. So each task's "verify" = (a) CI compiles, (b) a named
> on-device check. TDD applies only to the pure-JS/pure-Swift helpers noted.

**Goal:** Stand up the generic WebExtension host far enough that ReTorn's
shared bootstrap (`retorn.js` → settings/features via `sendMessage` to its
`background.js`) runs, and the ~30 "read/decorate" content scripts inject and
work (spy columns, gym graph, networth, valuations, filters).

**Architecture:** Bundle the ReTorn tree as app resources; serve `getURL()` via a
`WKURLSchemeHandler`; inject a `window.browser` shim + ReTorn's content scripts
into a dedicated `WKContentWorld("retorn")`; run `background.js` as-is in a hidden
`WKWebView`; relay `runtime.sendMessage` content↔background natively; back
`storage` with the GM store and the API proxy with `GM_xmlhttpRequest`.

**Tech Stack:** Swift / WKWebView / WKContentWorld / WKURLSchemeHandler / xcodegen
(project.yml) ; injected JS (the `browser` shim).

---

## File structure

| File | Responsibility |
|---|---|
| `WarboardIOS/Resources/retorn/**` | The bundled ReTorn tree (js/, lib/, files/, pages/, css/, images/, background.js, manifest.json), copied from source. **`lib/jscolor` excluded** (GPLv3 — Phase 4 concern; not needed in P1). |
| `…/Userscripts/WebExt/ExtResourceScheme.swift` | `WKURLSchemeHandler` serving `webext://retorn/<path>` from the bundle (for `getURL`). |
| `…/Userscripts/WebExt/ExtManifest.swift` | Parse the bundled `manifest.json` → content-script entries (matches, run_at, js[]) + version. |
| `…/Userscripts/WebExt/ExtBackgroundHost.swift` | A hidden `WKWebView` that loads a blank doc + the shim + `background.js`; exposes `dispatch(message) async -> reply`. |
| `…/Userscripts/WebExt/ExtMessageRelay.swift` | `WKScriptMessageHandlerWithReply` named `webextBridge`: content/background → native → background host; routes `storage.*`, `runtime.sendMessage`, API proxy. |
| `…/Userscripts/WebExt/ExtStorage.swift` | `browser.storage.{local,sync,session}` backing over the GM store / UserDefaults, per-area namespaces. |
| `…/Userscripts/WebExt/ExtensionRuntime.swift` | Orchestrator: owns manifest + scheme + background host + relay; builds the content-world WKUserScripts for a URL; wired into `UserscriptController`. |
| `…/Userscripts/WebExt/webext-shim.js` (Swift const) | The injected `window.browser`/`chrome` object (runtime/storage/getURL/getManifest/alarms-noop/notifications-noop/tabs/i18n/permissions). Injected first in both the content world and the background host. |
| `…/Userscripts/UserscriptController.swift` | MODIFY: register the scheme on `configuration`; after `rebuildUserScripts`, also add the runtime's content-world scripts for the URL. |
| `project.yml` | MODIFY: copy `WarboardIOS/Resources/retorn` into the app bundle as resources. |

---

## Task 1 — Bundle the ReTorn tree + the resource scheme (the `getURL` foundation)

**Files:** copy `/tmp/retorn/ReTorn/{js,lib,files,css,images,pages,background.js,manifest.json}` → `WarboardIOS/Resources/retorn/` (omit `lib/jscolor`, `firefox_manifest.json`, `.git`); Create `…/WebExt/ExtResourceScheme.swift`; Modify `project.yml`, `UserscriptController.swift`.

- [ ] **Step 1 — copy the tree** (shell):
```bash
mkdir -p WarboardIOS/Resources/retorn
cp -R /tmp/retorn/ReTorn/{js,lib,files,css,images,pages,background.js,manifest.json} WarboardIOS/Resources/retorn/
rm -rf WarboardIOS/Resources/retorn/lib/jscolor   # GPLv3 — not needed in P1
```
- [ ] **Step 2 — project.yml**: under the `Warboard` app target add a resources entry so the folder is copied as a blue folder reference:
```yaml
    sources:
      - path: WarboardIOS/Sources/WarboardIOS
      - path: WarboardIOS/Sources/Shared
      - path: WarboardIOS/Resources/retorn   # bundled as folder reference (getURL serves from Bundle.main)
        buildPhase: resources
```
- [ ] **Step 3 — ExtResourceScheme.swift**: a `WKURLSchemeHandler` for scheme `webext`. On `webView(_:start:)`, map `webext://retorn/<path>` → `Bundle.main.url(forResource: "retorn/<path>")`, read data, infer MIME from extension (js→text/javascript, json→application/json, css→text/css, png→image/png, html→text/html), respond; 404 on miss. Implement `stop` as a no-op.
- [ ] **Step 4 — register the scheme**: in `UserscriptController.init` where `config` is built (UserscriptController.swift:64), add:
```swift
config.setURLSchemeHandler(ExtResourceScheme(), forURLScheme: "webext")
```
- [ ] **Step 5 — commit + push (CI compile-gate)**. **On-device verify (after build):** in the browser, load `webext://retorn/manifest.json` → the manifest JSON renders. That proves the bundle + scheme.

---

## Task 2 — Manifest parse + the `browser` shim skeleton (no behavior yet)

**Files:** Create `…/WebExt/ExtManifest.swift`, `…/WebExt/webext-shim.js` (as a Swift const file `WebExtShimJS.swift`).

- [ ] **Step 1 — ExtManifest.swift**: `Decodable` for the subset we use: `version`, `content_scripts: [{matches:[String], run_at:String?, js:[String]}]`. A `static func load() -> ExtManifest` reads `retorn/manifest.json` from `Bundle.main`. (Pure Swift — add a `WarboardIOSTests` case asserting it parses 24 entries: TDD-able.)
- [ ] **Step 2 — WebExtShimJS.swift**: a Swift `static let source: String` holding the `window.browser` shim. Phase-2-of-this-task scope = STRUCTURE ONLY: define `browser`/`chrome` with `runtime.sendMessage(msg,cb)`, `runtime.getURL(p)=>'webext://retorn/'+p`, `runtime.getManifest()`, `runtime.onMessage`, `storage.local/sync/session` get/set/remove/clear, `runtime.lastError`, `alarms`/`notifications` as no-ops, `tabs.create`, `i18n.getMessage(k)=>k`, `permissions.*`=>granted. All async methods post to `window.webkit.messageHandlers.webextBridge.postMessage({kind,…})` and resolve via a pending-callback map keyed by a request id. (No native handler yet — calls just queue.)
- [ ] **Step 3 — commit + push (CI)**. Verify: CI compiles; `ExtManifest` test passes.

---

## Task 3 — The core: storage + relay + background host (interdependent; the heart of Phase 1)

**Why one task:** ReTorn's bootstrap `retorn.js` immediately `sendMessage`s the
background for settings/features; nothing renders until that round-trips. So the
relay + background host + storage come online together.

**Files:** Create `…/WebExt/ExtStorage.swift`, `…/WebExt/ExtMessageRelay.swift`, `…/WebExt/ExtBackgroundHost.swift`, `…/WebExt/ExtensionRuntime.swift`.

- [ ] **Step 1 — ExtStorage.swift**: per-area key/value over the GM store (or App-Group UserDefaults), namespaced `webext.retorn.<area>.<key>`. `get(area, keysOrNull) -> [String:Any]`, `set(area, dict)`, `remove`, `clear`. Emit a change record `(area, {key:{oldValue,newValue}})` for each `set` (needed by Phase 3, but build the accurate-diff now to avoid rework).
- [ ] **Step 2 — ExtBackgroundHost.swift**: a hidden `WKWebView` (offscreen, retained). Configure with: the `webextBridge` relay handler (content world `.page`), the shim injected at document start, then `background.js` injected at document start (read from `Bundle.main` `retorn/background.js`). Load `about:blank` (or a `webext://retorn/_bg.html` we add). Expose `func dispatch(_ message: [String:Any]) async -> Any?` that evaluates `window.__webext_handleMessage(<json>)` in the host and returns the reply. (ReTorn's `background.js` registers `browser.runtime.onMessage` handlers; the shim's `onMessage` collects them so `__webext_handleMessage` can invoke + await them, honoring `return true` async replies.)
- [ ] **Step 3 — ExtMessageRelay.swift**: `WKScriptMessageHandlerWithReply` `webextBridge`. Route by `kind`: `storage.*` → `ExtStorage`; `apiProxy` (fetchAPI/fetchTornStats) → `GMBridge`'s `GM_xmlhttpRequest` path (reuse, `@connect` api.torn.com + www.tornstats.com); `sendMessage` → `ExtBackgroundHost.dispatch` and return its reply. All replies go back through the `WKScriptMessageHandlerWithReply` reply, which the shim's pending-callback map resolves.
- [ ] **Step 4 — ExtensionRuntime.swift**: orchestrator. Holds the manifest, an `ExtStorage`, an `ExtBackgroundHost`, an `ExtMessageRelay`. `func install(on config: WKWebViewConfiguration)` registers the relay handler + the scheme. `func contentWorldScripts(for url: URL) -> [WKUserScript]` returns, for each manifest content-script entry whose `matches` accept the URL: the shim (once) + each `js` file's source (read from bundle) as `WKUserScript`s at the mapped `run_at`, `in: WKContentWorld.world(name: "retorn")`. Also synthesize `onInstalled`: compare stored `version` vs manifest `version`; on first run, let `background.js` seed defaults; **never reseed if a version is already stored** (guards the settings-wipe risk).
- [ ] **Step 5 — wire into UserscriptController**: in `init`, build an `ExtensionRuntime`, call `extRuntime.install(on: config)`. In `rebuildUserScripts(for:)` (after the userscript loop, ~line 162), append `extRuntime.contentWorldScripts(for: url)` to `userContent`. Background host is created once (lazily) in the runtime.
- [ ] **Step 6 — commit + push (CI)**. **On-device verify:** load a Torn page; ReTorn's bootstrap should fetch settings/features without console errors (check via the eruda console — toggle Dev Tools — for `[ReTorn]` logs and the `browser is not defined` error being ABSENT). First real integration signal.

---

## Task 4 — Inject ReTorn's content scripts; bring up the "light-shim" pages

**Files:** Modify `ExtensionRuntime.contentWorldScripts` only (already injects per manifest); this task is verification + per-page fixes.

- [ ] **Step 1**: confirm content scripts inject in the dedicated world with their bundled libs (jQuery etc.) ahead of them (manifest order preserved). The world isolation keeps ReTorn's jQuery off Torn's page + off the user's userscripts.
- [ ] **Step 2 — on-device verify the read/decorate pages** (the ~30): Stocks page → ticker acronyms; Bazaar → Max button; profile/faction (with TornStats key set via the preferences page) → spy columns; gym → stats graph; home → effective stats/networth. Fix per-page breakages (most will be a missing shim method surfaced in the eruda console).
- [ ] **Step 3 — commit per fix; ship a TestFlight build at the milestone** (~30 scripts working).

---

## Known unknowns (resolve by building, not by guessing here)
- Whether `background.js` runs cleanly as a plain script in a hidden WKWebView (vs a real SW) — the shim stubs `self`/`registration` so it takes the non-SW branches. Verify in Task 3.
- `WKContentWorld` isolation vs ReTorn's `<script src=getURL()>` main-world injects — those 3 are **Phase 2**, deferred; Phase 1 only needs the isolated-world scripts.
- Exact `run_at` mapping (`document_start`→`.atDocumentStart`, else `.atDocumentEnd`).

## Self-review
- Spec coverage: P1 spec row = shim + sendMessage/storage/getURL + background host → Tasks 1–4. ✅
- `onInstalled`-wipe risk → Task 3 Step 4 guard. ✅ `storage.onChanged` accurate diff → Task 3 Step 1 (built early). ✅ jQuery isolation → dedicated content world, Task 3 Step 4 / Task 4. ✅
- Types consistent: `ExtensionRuntime`/`ExtBackgroundHost`/`ExtMessageRelay`/`ExtStorage`/`ExtManifest` referenced consistently; relay handler name `webextBridge` consistent; scheme `webext` consistent.

# Remote Inspect Bridge — design

Status: approved (design), pre-implementation
Date: 2026-06-30
Branch: `remote-inspect-bridge`

## Problem / goal

iOS Safari and WKWebView speak Apple's Web Inspector protocol, not the Chrome
DevTools protocol our server-side agent uses to drive the user's desktop Chrome.
So there is currently no way for the agent to inspect or drive the warboard-iOS
app's in-app browser remotely.

Goal: a **wireless** channel that lets the server-side operator (a) run JS in the
app's live WKWebView and read the result, and (b) capture a PNG screenshot — over
the internet, no USB, no same-Wi-Fi requirement — so the userscripts and app UI
can be inspected/debugged on the real device.

## Non-goals (YAGNI for v1)

- Native coordinate-tap / touch synthesis (JS `.click()`/scroll/`location` covers
  most "drive" needs; native taps are phase 2 if JS proves insufficient).
- Full-page (beyond-viewport) screenshots.
- Socket.IO / sub-second push delivery (phase-2 latency upgrade).
- Multi-device targeting (assume a single owner device for v1).
- Safari Web Inspector (`isInspectable`) — orthogonal; can be enabled separately.
- Torn game-actions. The operator stays clear of clicking travel/attack/etc.

## Architecture

Four small pieces; every primitive already exists in the codebase.

```
operator (agent on server)                 phone (warboard-iOS, owner, toggle ON)
  |                                            |
  | POST /api/inspect/cmd  {js|action}         | GET /api/inspect/cmd   (drain, ~2-3s)
  |  (localhost-only)        ----> [relay] ---->| InspectClient → UserscriptController
  |                            _cmds  _results  |   runJS / snapshotPNG  (@MainActor, .page)
  | GET /api/inspect/result  <---- [relay] <----| POST /api/inspect/result  {result|png}
  v  (localhost-only)                           v
 read value / Read the PNG file
```

### 1. Swift — WebView capability (`UserscriptController.swift`)

`UserscriptController` is `@MainActor`, owns the `WKWebViewConfiguration` and the
canonical `weak var webView` (set in `makeWebView()`, ~L416-424), is the
`WKNavigationDelegate`, and **already** calls `callAsyncJavaScript`/
`evaluateJavaScript` (e.g. `invokeMenuCommand` L141, eruda dev-tools L533, and
`BrowserView.useQuickItem` L508-546 which returns a value). Add:

- `func runJS(_ src: String) async throws -> Any?` — wraps
  `webView?.callAsyncJavaScript(src, arguments: [:], in: nil, contentWorld: .page)`.
  `.page` so it sees the live, logged-in Torn DOM (mirrors the userscript world).
  Guard the `weak`/nil case (Browser tab not mounted → throw/return nil).
- `func snapshotPNG() async -> Data?` — wraps `WKWebView.takeSnapshot(with:)` →
  `UIImage.pngData()`. **New primitive** (`takeSnapshot` is unused today). Visible
  viewport only in v1.

Both are main-actor bound (the controller already is).

### 2. Swift — dedicated poll loop (`InspectClient.swift`, new)

A small client that **only runs while the toggle is on**:
`while !Task.isCancelled { drain GET /api/inspect/cmd; dispatch each cmd to
UserscriptController.runJS / snapshotPNG on @MainActor; POST result; sleep ~2-3s }`.
- Reads base URL from `PrefsStore` (`warboard.baseUrl`, App-Group suite
  `group.com.tornwar.warboard`) — **not** the APNs `UserDefaults.standard`
  `warboard_base_url` key (store-mismatch landmine).
- Authenticates with the app's existing JWT (`PrefsStore.cachedJwt()`,
  `Authorization: Bearer`).
- Started/stopped from `WarboardIOSApp.swift` based on the toggle; auto-disables
  after an idle timeout.

### 3. Server — relay (`server/inspect-relay.js`, new)

A clone of `server/pending-broadcasts.js`: two in-memory `Map`s keyed by owner id
(v1 single device) — `_cmds` (operator→device) and `_results` (device→operator) —
with the same `QUEUE_CAP` (20) and `STALE_AFTER_MS` (5 min) bounding/eviction.
Functions: `queueCmd`, `drainCmds`, `putResult`, `drainResults`.

### 4. Server — routes (`server/routes.js`, near the stakeout block ~L349)

> **Two-copies trap:** edit `/opt/warboard/server/{routes,server}.js`, NOT the
> stale root `/opt/warboard/{routes,server}.js` duplicates.

- `POST /api/inspect/cmd` — operator enqueues `{js}` or `{action:"screenshot"}`.
  **localhost-only** (`req.socket.remoteAddress` is `127.0.0.1`/`::1`; do not trust
  `X-Forwarded-File`/proxy headers). The agent curls `localhost:3000` directly,
  bypassing nginx, so command injection is not internet-reachable.
- `GET /api/inspect/cmd` — device drains. `requireAuth` (JWT) + `playerId === "137558"`.
- `POST /api/inspect/result` — device posts `{id, result}` or base64 PNG. Same
  owner-JWT gate. Raise this one route's `express.json` limit (~8 MB) for base64.
- `GET /api/inspect/result` — operator drains. localhost-only.

`/api/*` is gate-exempt (gateMiddleware), so no gate cookie; the per-route auth
above is the enforcement.

## Safety / auth model (load-bearing)

The explicit anti-goal: do **not** replicate the always-on, unauthenticated
`WebDiag`/`ExtCrashDiag` POSTs. Four independent gates:

1. **Default-OFF toggle** `warboard.inspect.enabled` (PrefsStore). The
   `InspectClient` loop does not run unless the owner turns it on, and a
   **persistent on-screen banner** shows while active — it can never run silently.
2. **Owner-only UI**: the toggle renders only when `CachedAuth.isOwner` (playerId
   137558), mirroring the existing owner-only PM2-logs section in `SettingsView`.
3. **Server-enforced**: device routes require an owner-scoped JWT; operator routes
   are localhost-only. Client gates are defense-in-depth; the server is authoritative.
4. **Expiry**: relay entries inherit 5-min stale eviction; the device loop
   auto-disables the toggle after an idle timeout.

⚠️ **Ship discipline:** `build-ipa.yml` triggers on `push: branches:[main]` and
uploads to TestFlight whenever signing secrets are present (regardless of the
"no upload" header comment). Therefore: all work stays on `remote-inspect-bridge`;
it merges to main only when gated and the user approves. Even docs-only pushes to
main trigger a build, so do not push this branch's commits to main casually.

## How the operator drives it

```bash
curl -s localhost:3000/api/inspect/cmd -H 'content-type: application/json' \
  -d '{"js":"return document.title"}'                # enqueue
# device drains in ~2-3s, runs in .page, posts back
curl -s localhost:3000/api/inspect/result            # → {id, result}
# screenshot:
curl -s localhost:3000/api/inspect/cmd -d '{"action":"screenshot"}'
# device posts base64 PNG; operator decodes to a file and Reads it (per the
# gyazo/remote-screenshot memory workflow) to actually see the screen.
```

A thin server-side wrapper script can enqueue + poll-for-result + decode in one
call for ergonomics.

## MVP vs phase 2

- **MVP**: `runJS` + `snapshotPNG`, owner-only, toggle-gated, ~2-3s poll, single
  device, base64 screenshot transport.
- **Phase 2**: native tap/scroll/navigate helpers, full-page screenshots,
  Socket.IO push delivery, multi-device targeting, optional `isInspectable`.

## Risks & gotchas (from analysis)

- `runJS(contentWorld:.page)` runs in the live authenticated Torn origin and can
  perform real actions — the owner + default-off + localhost gates must be airtight.
- `webView` refs are `weak`/nil before the Browser tab mounts; runJS/snapshot must
  handle nil and callers hop to `@MainActor`.
- In-memory relay queues are lost on restart and not cluster-shared (fine for
  ephemeral commands); cap + stale-evict + rate-limit to prevent memory exhaustion.
- Base-URL store mismatch: `InspectClient` must read `PrefsStore` `warboard.baseUrl`
  (App-Group suite), the same store `WarboardAPI` uses.
- No `#if DEBUG` infra exists today; treat the runtime toggle + server identity
  check as the load-bearing gates, not a compile guard.

## Verification plan

- Swift unit-testable seams where practical (the repo has `Tests/`); the live
  WKWebView path is integration-tested on device.
- End-to-end: build the branch → TestFlight → user enables the toggle → operator
  `curl`s `runJS` (confirm a known value returns) and a screenshot (confirm the PNG
  decodes and shows the app). No success claim until that round-trips on device.

## Files touched

- `WarboardIOS/Sources/WarboardIOS/Userscripts/UserscriptController.swift` (runJS, snapshotPNG)
- `WarboardIOS/Sources/WarboardIOS/Networking/InspectClient.swift` (new poll loop)
- `WarboardIOS/Sources/WarboardIOS/WarboardIOSApp.swift` (start/stop on toggle)
- `WarboardIOS/Sources/WarboardIOS/Utilities/PrefsStore.swift` (toggle key)
- `WarboardIOS/Sources/WarboardIOS/Views/SettingsView.swift` (owner-only toggle + banner)
- `/opt/warboard/server/inspect-relay.js` (new)
- `/opt/warboard/server/routes.js` (4 routes), `/opt/warboard/server/server.js` (rate limiter)

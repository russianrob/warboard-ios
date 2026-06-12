# WebExtension Runtime (run ReTorn / TornTools in warboard-iOS) — Design

**Date:** 2026-06-12
**Status:** Approved direction (full port) — architecture for review
**Basis:** feasibility report (workflow `wf_7bbc5632-d35`) — verdict *feasible-with-major-caveats*

## Goal

Build a **generic WebExtension (MV3) runtime inside warboard-iOS** so the app can
host real Torn browser extensions — starting with **ReTorn**, designed so
**TornTools** drops into the same runtime later. Not ReTorn-hardcoded.

## Honest ceiling (set expectations up front)

A *faithful* "ReTorn on iOS" is **not** achievable. What's achievable is
**~75–80% of ReTorn's features** with **best-effort (~40%) background
notifications**. Permanent limits:
- **One web view, not N tabs** — `tabs.create` / notification-click-to-URL must be
  re-plumbed to navigate-or-ignore per call site.
- **No reliable 30s background timer** — iOS `BGAppRefreshTask` is minutes-to-hours;
  foreground notifications are solid, backgrounded ones lag.
- **No cross-device `storage.sync`** — collapses to local-only.

## Host

The Swift app **warboard-iOS** (`WKWebView` + `UserscriptController` + the GM
bridge + the userscript injection engine). The runtime extends that controller;
it does **not** replace the userscript engine — userscripts and the extension
runtime coexist.

## Architecture

```
┌────────────────────────── warboard-iOS (Swift) ──────────────────────────┐
│                                                                          │
│  ExtensionRuntime (new)                                                  │
│   ├─ bundles the ReTorn tree as app resources (js/ lib/ files/ pages/ …) │
│   ├─ ResourceScheme (WKURLSchemeHandler) → serves getURL() resources     │
│   ├─ MessageRelay (native) → content-world ⇄ background relay            │
│   ├─ Storage (browser.storage.* ⇄ GM store / native, per-area namespaces)│
│   ├─ NotificationBridge → UNUserNotificationCenter + app-icon badge      │
│   └─ BackgroundHost: a HIDDEN WKWebView running ReTorn's background.js    │
│                                                                          │
│  Visible BrowserView WKWebView (the page)                                │
│   ├─ Content world "retorn": browser.* shim + ReTorn content scripts     │
│   │      injected per manifest matches/run_at (extends the engine)       │
│   └─ Page (main) world: ReTorn's 3 inject scripts (fetch intercept etc.) │
└──────────────────────────────────────────────────────────────────────────┘
```

### Core seam (why this is tractable)
The entire content↔background contract is **one `runtime.sendMessage` seam** (a
single `m.name` discriminator → a ~22-case `handleMessage` dispatcher in
`background.js`) plus **one storage layer** plus **`getURL`**. Get those three
shims to behave like Chrome's callback APIs and ~30 of 42 content scripts work.

### The `browser` shim (injected JS, content world)
A single `window.browser` object (+ `chrome` alias — every ReTorn file does
`var browser = browser||chrome`). Provides: `runtime.sendMessage/onMessage/
getURL/getManifest/lastError/id`, `storage.{local,sync,session}` (callback
style), `alarms`, `notifications`, `tabs` (→ app browser, approximate),
`action` (→ badge), `i18n.getMessage`, `permissions.*` (always-granted stubs).

### Background host
ReTorn's `background.js` (1,713 lines) runs **as-is** in a hidden WKWebView with
the same `browser` shim, wired to native: `storage` → GM/native, the
Torn/TornStats API proxy → `GM_xmlhttpRequest` (bypasses CORS), `tabs.create` →
open-in-app, `alarms` → a native timer, `notifications` → native local
notifications. `runtime.sendMessage` from content scripts is relayed natively
into the background's `handleMessage` and the reply relayed back (honoring the
`return true` deferred-async pattern).

### World isolation
ReTorn assumes per-page **isolated content-script worlds** (no `world:MAIN`).
We run its content scripts in a dedicated `WKContentWorld("retorn")` so its
bundled jQuery 3.6 / jQuery-UI / touch-punch / countdown / jscolor / Chart / trie
don't collide with Torn's own libs or the user's other userscripts. The 3
main-world inject scripts (fetch intercept, 3D, ajaxComplete) are injected as raw
**text** at `document_start` into the page world, with the `CustomEvent`
handshake re-wired both directions.

## Phases (each = build → verify on-device → ship)

| # | Name | Delivers | Effort |
|---|---|---|---|
| **0** | Licensing | User waived for personal builds; **replace/verify `jscolor` (GPLv3-or-commercial)** before any non-personal ship. Retain MIT/OFL notices. | S |
| **1** | Browser shim + sendMessage/storage/getURL seam + background host | ~30/42 scripts: TornStats spy columns (profile/faction/memberlist/rankedwar), gym graph, home effective-stats/networth, sidebar loot timers, bazaar/amarket/city/war valuations, jail/bounty filters, forums block-list, preferences connect panel. **DOM/read features. No live notifications.** | L |
| **2** | Main-world fetch-intercept + lib isolation | Quick Items/Crimes (RFC POST — reuse the item.php useItem path the app already has), live ranked-war online counts, miniprofile last-action, 3D. → **~75% of features.** | L |
| **3** | Notification + badge engine | Cooldown / bar / travel / chain notifications + badge. **Background fidelity ~40% (iOS-throttled) — worst effort-to-value; a stop/ship checkpoint precedes it.** | XL |
| **4** | Popup / options pages + lifecycle polish | Full settings UI (per-feature toggles, color config) + login/status popup; harden install/update migration so settings aren't pruned. → feature-complete-as-portable. | M |

**Checkpoint:** ship after **Phase 1+2 (~75%, no notifications)** and reassess
before committing to the XL Phase 3.

## Highest risks (carry into the plan)
1. **`storage.onChanged` old/new diff fidelity** — the whole notification engine
   diffs `oldValue` vs `newValue` of `re_user_data` on every write. The shim MUST
   deliver accurate old+new, not a bare "changed" signal. Single highest-risk shim.
2. **`onInstalled` mis-fire wipes settings** — no WKWebView equivalent; synthesize
   install-vs-update by comparing stored `version` to bundle version.
   `validate_sync_data` prunes any key absent from bundled `default_*.json` →
   ship the EXACT defaults or lose user settings.
3. **iOS background vs 30s heartbeat** (Phase 3) — unavoidable; design notifications
   foreground-solid, background-best-effort.
4. **jQuery-world collision** — real isolation (dedicated content world), not just
   shimming.
5. **Dual notification path** (SW `registration.showNotification` AND
   `browser.notifications.create`) — neither exists in WKWebView; both collapse to
   native + native click routing.

## Out of scope
- Faithful desktop parity (see ceiling).
- TornTools (same runtime, later — design generic now).
- The `jscolor` GPLv3 lib in any non-personal/non-GPL distribution.

## Success criteria
- **Phase 1:** on a Torn profile/faction/gym page, ReTorn's spy columns / graphs /
  valuations render from cached data; the preferences page connects ReTorn +
  TornStats keys; no crash; userscripts still work alongside.
- Each later phase: its feature set works on-device; settings survive
  install/update; ships via `build-ipa.yml`.

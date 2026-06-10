# warboard-iOS — Userscript Host (Tampermonkey-class engine with `@require`)

**Date:** 2026-06-10
**Status:** Approved design
**Project:** warboard-iOS (`github.com/russianrob/warboard-ios`).

## Summary

Add a **userscript host** to warboard-iOS: a navigable in-app Torn browser plus an
engine that runs *arbitrary* installed userscripts with full Tampermonkey-class
semantics — crucially **`@require`** (external library includes), which TornPDA does
not support, so scripts like factionops (`@require .../socket.io.js`) can finally run on
iOS. Because we own the `WKWebView` directly (not a Safari extension), we have full
access to `WKUserScript`, message handlers, and native `URLSession`.

### This is Slice 1 of a larger effort (decomposition)

A full userscript manager is multiple subsystems × two platforms; it was decomposed:

- **Slice 1 (this spec):** the engine + general installer on **iOS**, inside warboard-iOS.
- Slice 2: Android (`warboard-native`) — reuse the engine design, swap the WebView layer.
- Slice 3: cross-script niceties (sync, cloud backup, richer management).
- (ReTorn feature ports are separate — ordinary userscripts that then run on this host.)

### Owner decisions

1. **Platform:** iOS first.
2. **Codebase:** extend warboard-iOS (reuse app shell + the existing Torn `WKWebView` in
   `TornChatWebView.swift` + the CI→TestFlight pipeline).
3. **Script source:** **general installer** — add/enable any userscript by URL, not just a
   curated own-scripts list.
4. **Injection:** **Approach 1** — native rebuilds the `WKUserScript` set per navigation
   (true `@run-at` + native `@match` + per-page lib loading).

## GM surface to support (from a survey of the real scripts)

Ships covering 100% of RussianRob's scripts: `GM_getValue`/`GM_setValue` (synchronous),
`GM_deleteValue`, `GM_listValues`, `GM_xmlhttpRequest`, `GM_addStyle`,
`GM_registerMenuCommand`, `GM_setClipboard`, `GM_openInTab`, `GM_info`, and
`unsafeWindow`. Metadata in use: `@require` (socket.io), `@connect` to ~11 hosts plus
`*`, and `@run-at` of `document-start` / `document-end` / `document-idle`.

## Surface (UI)

- **Browser tab:** a new tab in warboard-iOS — a navigable `WKWebView` with URL bar,
  back / forward / reload, loading torn.com, where scripts run. (Generalizes the existing
  chat-only `TornChatWebView`.)
- **Scripts screen:** manage installed scripts (add / list / enable / update / remove).

## Architecture

Native (Swift) owns state + privileged operations; injected JS owns the in-page API.

### 1. Injection pipeline (Approach 1)

- On `WKNavigationDelegate.decidePolicyFor` (before the load commits), native reads the
  destination URL and computes the set of **enabled** scripts whose `@match`/`@include`
  match (and not `@exclude`).
- Native rebuilds `userContentController`: `removeAllUserScripts()`, then adds, in order:
  1. the **GM bootstrap** `WKUserScript` at `.atDocumentStart`, **main world**
     (`forMainFrameOnly` per script; main world so `unsafeWindow === window`);
  2. for each matching script (in install order): its `@require` lib sources, then its
     body — each at the script's `@run-at` (`document-start` → `.atDocumentStart`;
     `document-end` / `document-idle` → `.atDocumentEnd`).
- Allow the navigation → WebKit injects with correct timing.
- `document-idle` = `.atDocumentEnd` + a small JS shim that defers the body to
  `requestIdleCallback` / after `DOMContentLoaded`.

### 2. GM bridge + storage

- The bootstrap builds a per-script `GM` context and the `GM_*`/`GM.*` functions, backed
  by `window.webkit.messageHandlers`. Async APIs (`GM_xmlhttpRequest`, `GM_setValue`,
  `GM_deleteValue`, `GM_openInTab`, `GM_setClipboard`) use `WKScriptMessageHandlerWithReply`
  (return Promises natively).
- **Synchronous storage:** `GM_getValue` / `GM_listValues` are synchronous in Tampermonkey.
  At document-start, native injects a **snapshot** of the script's stored K/V into the
  bootstrap; `GM_getValue` reads the snapshot synchronously; `GM_setValue`/`GM_deleteValue`
  write through to native **and** update the in-page snapshot so subsequent sync reads are
  consistent.
- **Storage backend:** native per-script namespaced key/value store — **one file-backed
  JSON document per script id** (MVP simplicity; revisit only if a script's store grows
  large). Values are JSON; raw-string coercion documented (matching GM semantics).
- `GM_addStyle` injects a `<style>`; `GM_registerMenuCommand` registers callbacks surfaced
  in a per-page **script-actions sheet** (toolbar button); `GM_info` returns script + engine
  metadata; `GM_openInTab` opens in the browser tab (or system browser per options).
- **`unsafeWindow`** is the page `window` (main-world injection). The GM shims and the
  bridge handle live behind a private symbol so page code can't reach them.

### 3. `@require` resolver

- On **install/update**, native fetches every `@require` URL and caches the JS to disk,
  keyed by URL + content hash. Injection reads from cache (re-fetch on script update or
  cache miss). A `@require` that fails to fetch blocks enabling the script with a clear
  error (it can't run without its lib).

### 4. `@connect` / `GM_xmlhttpRequest`

- The JS `GM_xmlhttpRequest` shim posts the request to a native handler; native performs it
  via `URLSession` (no WebView CORS), streaming status / headers / body back to the JS
  `onload`/`onerror`/`onprogress` callbacks.
- The request host is checked against the script's `@connect` allowlist. `*` is honored as
  Tampermonkey does, gated by a **one-time per-script consent** prompt recorded in the
  registry. Same-origin (`*.torn.com`) is always allowed.

### 5. Script registry + management

- **Model `Userscript`:** id, name, namespace, version, description, `@match`/`@include`/
  `@exclude`, `@require[]`, `@connect[]`, `@grant[]`, `@run-at`, `@icon`, `downloadURL`/
  `updateURL`, enabled, install order, source text, granted-wildcard-connect flag.
- **Add by URL:** fetch the URL (Greasy Fork install URL or raw `.user.js`) → parse the
  `==UserScript==` block → resolve `@require` → store. Reject if no metadata block.
- **List:** name, version, enabled toggle, `@match` summary, update-available badge.
- **Update:** re-fetch `@updateURL` (fallback `@downloadURL`), compare `@version`
  (semver-ish, plain-number compare), swap source + re-resolve `@require`.
- Enable/disable, remove, reorder (install order defines injection order).

### 6. Metadata parser (pure, the unit-test seam)

- A pure Swift `MetadataParser` turning a script's text into the `Userscript` model:
  parse the `// ==UserScript== … // ==/UserScript==` block, each `// @key value` line,
  repeated keys (`@match`, `@require`, `@connect`, `@grant`) into arrays, defaults
  (`@run-at` → `document-idle`). No WebKit/UIKit deps.
- A pure `MatchMatcher`: Tampermonkey `@match` (scheme/host/path globbing) + `@include`/
  `@exclude` (string/regex) → `matches(url) -> Bool`.
- A pure `RequireCache` key function (URL + hash → cache path).

## Data flow (happy path)

1. User adds `https://greasyfork.org/.../factionops.user.js` on the Scripts screen.
2. Native fetches → `MetadataParser` → `Userscript`; fetches `@require socket.io.js` → cache.
3. User opens the Browser tab → navigates to `factions.php?step=your`.
4. `decidePolicyFor` → `MatchMatcher` selects factionops → native rebuilds `userScripts`
   (bootstrap + cached socket.io + factionops body at `document-idle`).
5. Page loads; bootstrap wires `GM_*`; socket.io + factionops run; `GM_xmlhttpRequest` to
   tornwar.com goes through the native `URLSession` proxy.

## Error handling

- `@require` fetch failure → script can't enable; surfaced inline with retry.
- Malformed metadata (no block / no `@match`) → reject add with a clear message.
- `GM_xmlhttpRequest` to a non-`@connect` host → rejected (logged, error to script).
- Navigation to a non-Torn host → engine still available, but only `@match`-ing scripts run.
- Bridge message from a frame with no active script context → ignored.

## Testing

- **Unit (XCTest, pure Swift):** `MetadataParser` (real headers incl. multi-`@match`,
  multi-`@require`, `@connect`, defaults, malformed), `MatchMatcher` (match/include/
  exclude/regex, scheme+host+path globs), `RequireCache` key stability.
- **Integration (WKWebView in a test host):** load a fixture page, inject the bootstrap +
  a stub script, assert `GM_setValue`→`GM_getValue` round-trips synchronously,
  `GM_xmlhttpRequest` reaches the native proxy, `unsafeWindow === window`, and `@run-at`
  ordering. Live smoke with two real scripts — **factionops** (`@require socket.io` +
  `GM_xmlhttpRequest`) and **foreign-stock** (`GM_getValue/setValue` + `@connect`).

## Scope

- **In:** iOS engine + general installer + browser tab covering the GM surface above,
  `@require`, `@connect`, all three `@run-at`, install/enable/update/remove.
- **Out (later slices):** Android; iCloud/script sync; per-script settings UIs;
  `GM_download`/`GM_notification`/menu sub-features beyond the surveyed surface; a curated
  "recommended scripts" gallery.

## Risks / notes

- **App Store review:** running arbitrary remote scripts is fine for **TestFlight/personal**
  (how warboard-iOS ships today); a public App Store release of a general-installer browser
  could draw scrutiny (Userscripts/Stay avoid it by being Safari extensions). Decision
  deferred to a wider-release point.
- **Main-world injection** trades sandbox isolation for `unsafeWindow` + page access, which
  the Torn scripts require; acceptable for a user-curated install list.
- **Sync `GM_getValue`** depends on the document-start snapshot; a value written by another
  tab/process mid-page won't reflect until the next navigation (matches Tampermonkey's
  per-document snapshot behavior closely enough).

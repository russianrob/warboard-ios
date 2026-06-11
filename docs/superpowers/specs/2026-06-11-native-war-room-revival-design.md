# Native War Room Revival — Design

**Date:** 2026-06-11
**Status:** Approved (brainstorming) — ready for implementation planning
**Author:** RussianRob + Claude

## Goal

Surface the app's existing native **War Room** screen — currently built but
unreachable — from the browser-first app, so the user can see live war targets
(FF scores, online/hospital, call/uncall/deal) and the post-war report without
loading torn.com in the webview. This is **sub-project 1 of group "war &
faction native"**; OC Manager and payouts/war-history follow as separate passes.

## Background

The app was originally a full faction suite behind an `AuthGateView → TabView`
root (War Room, OC Manager, Dashboard, Faction, Chat, Post-War Report). When it
was stripped to "just a browser + script manager," those screens were **left in
the codebase but unplugged** — `ContentView` now renders only `BrowserView`.

Key facts confirmed during exploration:

- **`WarRoomView.swift`** (~1,313 lines) is complete: sub-tabs (targets / chat /
  report / heatmap), `HeaderCard`, `TargetList`, target actions (call, uncall,
  deal), `WarEndedBanner`, `PostWarReportView`.
- **`WarRoomViewModel`** is self-sufficient: `bind(prefs:)`, `start()`, `tick()`;
  authenticates with the stored Torn key, calls `WarboardAPI.fetchWars` +
  `fetchPoll` (+ heatmap), drives `RealtimeClient` (SSE) and the war Live
  Activity. It already has `.noKey`, `.noWar`, loading, and war-ended states.
- **`WarboardAPI`** already has `fetchWars` (`GET /api/faction/<fid>/war`) and
  `fetchPoll` (`GET /api/poll?warId=…`) wired to the warboard server.
- **Auth still runs.** The app root is `AuthGateView()` (in `WarboardIOSApp`),
  which authenticates (Torn key → warboard JWT + faction id) and only then shows
  `ContentView`. So a valid session already exists by the time the browser loads.

So the War Room is **fully wired and authenticated; it is simply not reachable.**
The work is to make it reachable and verify it still runs against the current
server — not to build it.

## Approach (chosen: A)

**A — Reuse `WarRoomView` as-is, surfaced via a shield button.** Add a 🛡 icon to
`BrowserView`'s URL bar that fires a new `onShowWarRoom` closure; the app presents
the existing `WarRoomView` full-screen. This mirrors the existing
`onShowNotifications` and `onEditQuickItems` closures, which already cross the
framework→app boundary the same way.

Rejected alternatives:
- **B — Rebuild a slimmer war board** from `fetchWars`/`fetchPoll`. Throws away
  1,300 lines of working targets/calling/report UI. Kept only as a fallback if
  on-device testing shows the existing view is too rotted to revive cheaply.
- **C — Restore the original `AuthGate → TabView` app** with the War Room as a
  tab. Rejected: the user chose sheet-from-browser to preserve the browser-first
  app, not tabs.

## Architecture

The browser remains the app's home. The framework `BrowserView` cannot reference
app-target types (dependency is app→framework only), so it exposes the War Room
trigger as a closure that the app fulfils — identical to the existing pattern.

```
ContentView (app)
  ├─ BrowserView(                         (framework)
  │     personalItems:…, factionItems:…,
  │     onEditQuickItems:…,
  │     onShowNotifications:…,
  │     onShowWarRoom: { showWarRoom = true }   ← NEW closure
  │  )
  │     └─ URL bar: … 🛡(new) ⋯           tapping 🛡 → onShowWarRoom?()
  └─ .fullScreenCover(isPresented: $showWarRoom) {
        WarRoomView()                     (app, reused unchanged)
     }
```

## Components / files

| File | Target | Change |
|---|---|---|
| `Userscripts/BrowserView.swift` | framework | Add `onShowWarRoom: (() -> Void)?` init param; add a 🛡 button in the URL bar that calls it. |
| `Views/ContentView.swift` | app | Add `@State showWarRoom`; pass `onShowWarRoom: { showWarRoom = true }`; add `.fullScreenCover { WarRoomView() }`. |
| `Views/WarRoomView.swift` | app | Reused, plus **add a dismiss button** (X / "Done") to its toolbar. It was a TabView tab, so it has no self-dismiss; a `.fullScreenCover` needs one to return to the browser. (Confirmed it reads `prefs` via `@EnvironmentObject` + `.onAppear { vm.bind(prefs:) }`, so the cover inherits it.) |
| `ViewModels/WarRoomViewModel.swift` | app | Reused unchanged unless verification (below) reveals API drift. |

No new files; no `Package.swift` exclude changes (all touched app files are
outside `Userscripts/`).

## Data flow

```
tap 🛡 → onShowWarRoom?() → showWarRoom = true
  → .fullScreenCover presents WarRoomView()
    → WarRoomView binds prefs (already in environment) + vm.start()
      → vm.tick(): stored Torn key → warboard JWT (already authed)
        → fetchWars(factionId) + fetchPoll(warId) [+ heatmap, RealtimeClient SSE]
          → state = .active(war) → TargetList renders targets
             (name, level, online/idle/offline, hospital countdown, FF score)
             with call / uncall / deal actions + post-war report when ended
```

## Auth

No new auth. `AuthGateView` (app root) already produces the JWT + faction id
before the browser appears, and `WarRoomViewModel` re-uses the stored Torn key.
If the user has cleared their key, the VM already surfaces `.noKey`.

`WarRoomView` is presented as a `.fullScreenCover` from `ContentView`, which sits
*inside* the `AuthGateView`/environment scope, so `prefs` (and any other injected
environment objects the view needs) are inherited by the cover.

## States (already implemented in WarRoomView)

- **Loading** — spinner while the first `tick()` runs.
- **No key** — prompt to set the Torn API key (set in the Notifications screen).
- **No active war** — "No active war." message.
- **Active war** — header (scores/ETA) + target list + actions.
- **War ended** — VICTORY/DEFEAT/DRAW banner + link to the post-war report.

## The one real risk = the main work: verification

`WarRoomView`/`WarRoomViewModel` have not run in the current build for ~3 weeks.
Implementation MUST verify the revived screen **end-to-end on-device against the
live warboard server** and fix any drift:

1. `fetchWars` / `fetchPoll` response shapes still match `parseWar` / `WarPoll`.
2. `RealtimeClient` (SSE) connect/join still works.
3. The war **Live Activity** still starts/updates (or is gated off if broken).
4. Target actions (call/uncall/deal) still hit the right endpoints.

Outcome ranges from "works as-is" to "a few API-shape fixes." If it is badly
rotted, fall back to Approach B for a slimmer board. We will know only after it
is surfaced and tested on a real device against the live server.

## Out of scope (this pass)

- OC Manager, payouts/war-history viewer, Faction/Dashboard screens — later
  sub-projects in group "war & faction native."
- Retaliation list (not part of the existing War Room) — separate feature.
- Any redesign of the War Room UI itself.

## Success criteria

- Tapping 🛡 in the browser opens the native War Room full-screen; dismiss
  returns to the browser with no state loss.
- During an active war, the target list shows live online/hospital/FF data and
  call/uncall/deal work.
- With no war / no key, the appropriate empty state shows (no crash).
- Ships to TestFlight via the existing `build-ipa.yml` pipeline.

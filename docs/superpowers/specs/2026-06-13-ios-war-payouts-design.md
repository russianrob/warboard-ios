# War Payouts (iOS app) — Design

**Date:** 2026-06-13
**Status:** Approved (design)

## Goal

Add a **War Payouts** screen to the warboard-iOS app so a faction admin can, after a war ends, see each member's owed cut of the war loot and pay them — mirroring the warboard web `/payouts` page, scoped to mobile.

## Scope (v1)

- **Latest ended war only** — no war picker.
- **No paid/unpaid tracking** — show amounts owed + a Pay deep-link per member, like the web.
- **Read-only compute** — uses the server's `dynamic` payout mode; no loot/settings editing in the app.

**Out of scope (v1):** war picker / history, paid-state tracking, the loot/settings admin panel, static-vs-dynamic toggle, multi-war heatmap.

## Where it lives

A standalone full-screen **War Payouts** screen, launched from the browser chrome next to **War Room** and **OC Manager** (the established `.fullScreenCover` + closure pattern). It is *not* a War Room sub-tab: War Room shows the *active* war, but payouts exist only for *ended* wars.

## Data flow

The app already has `Networking/WarboardAPI.swift` (base URL `prefs.baseUrl`, default `https://tornwar.com`) and `Auth/AuthRepository.ensureAuth()` for the JWT Bearer flow (same as War Room). War Payouts uses the JWT `-admin` endpoints (they enforce the faction-admin gate):

1. `AuthRepository.ensureAuth()` → JWT.
2. `GET /api/war/admin-list` (Bearer) → `{ wars: [{ warId, enemyFactionName, warResult, warEndedAt }] }`, most-recent ended first. Take `wars.first`.
3. `GET /api/war/<warId>/payouts-admin?mode=dynamic` (Bearer) → the payout object:
   - top-level: `enemyFactionName`, `warResult`, `lootTotal`, `payoutPool`, `payoutPct`, `members[]`.
   - each member: `playerId` (String), `name`, `dollarPayout` (number), `attackCount`, `sharePct`.

Empty `admin-list` → "No completed wars yet." 403 → "Admin role required." 5xx/transport → transient (keep prior data if any, else error message).

## Screen

`WarPayoutsView` (SwiftUI, app target) backed by `WarPayoutsViewModel` (`@MainActor ObservableObject`), following the OC Manager conventions:

- **`LoadState<T>`** enum (`idle/loading/ready/error`) on the VM; the view switches over it (ProgressView / `OCMessageView` / List).
- **Header** (when ready): enemy faction + Win/Loss, and pool math — `"Pool $<payoutPool> · <payoutPct>% of $<lootTotal> loot"`. Money via the canonical `formatMoney` (B/M/K).
- **Member list:** `List`, sorted by `dollarPayout` desc. Row = name · `<attackCount> hits` · **owed $** (green) · a **Pay** button.
- **Toolbar:** "Done" (dismiss) + refresh.
- On-demand fetch on `.onAppear` (`vm.bind(prefs:)` then `vm.start()`), 60s staleness gate, keep prior `.ready` data while refetching (OC Manager pattern).

## Pay flow

Tapping **Pay** for a member:
1. (Optional) `UIPasteboard.general.string = "\(amount)"` as a fallback.
2. `BrowserRouter.shared.open(URL("https://www.torn.com/factions.php?step=your#/tab=controls&addMoneyTo=<playerId>&money=<dollarPayout>"))` — loads in the logged-in warboard browser tab.
3. `dismiss()` the cover so the user lands on Torn's pre-filled give-money form and confirms there (same as the web; the server tracks nothing).

`dollarPayout` is rounded to an integer for the `money=` param.

## Files

- **New:** `Sources/WarboardIOS/Views/WarPayoutsView.swift` (app target), `Sources/WarboardIOS/ViewModels/WarPayoutsViewModel.swift` (app target).
- **Modify:** `Sources/WarboardIOS/Networking/WarboardAPI.swift` — add `fetchPayoutWars(baseUrl:jwt:)` + `fetchWarPayouts(baseUrl:jwt:warId:)` and the `Decodable` models (`PayoutWarSummary`, `WarPayouts`, `PayoutMember`).
- **Modify (entry point):** `Sources/WarboardIOS/Views/ContentView.swift` (`@State showWarPayouts` + `.fullScreenCover` + `onShowWarPayouts` closure) and `Sources/WarboardIOS/Userscripts/BrowserView.swift` (a `((() -> Void)?)` init param + a toolbar/menu button).

## Module-boundary notes (must respect)

- Views/ViewModels/Networking live in the **app target** (module `Warboard`); `BrowserView`/`BrowserRouter` live in the **framework** (`WarboardIOS`). `ContentView` already `import WarboardIOS`. The `onShowWarPayouts` closure is declared in `BrowserView` (framework, `public`) and provided by `ContentView` (app) — so the closure type must use only `public`/standard types (it's `(() -> Void)?`, fine). `BrowserRouter.shared` is `public` and reachable from the app target.

## Error handling

Reuse `OCAPIError`/`OCMessageView` conventions. Distinguish: no-ended-wars (empty list → friendly empty state), 403 admin gate, and transient 5xx/transport (ret, keep prior data).

## Testing / verification

SwiftUI + networking in the app target compiles only on Mac CI (the Linux engine build excludes it), so verification is: a pre-build review pass for the framework/app module boundary + access control, then the CI build, then on-device (load a Torn page → open War Payouts → confirm the latest ended war's members + amounts render and Pay opens the pre-filled Torn page). No headless unit tests (project convention).

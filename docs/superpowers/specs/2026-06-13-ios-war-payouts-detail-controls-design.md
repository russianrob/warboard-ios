# War Payouts — Detail + Admin Controls (iOS) — Design

**Date:** 2026-06-13
**Status:** Approved (design)
**Builds on:** the v1 War Payouts screen (2026-06-13-ios-war-payouts-design.md).

## Goal

Bring the iOS War Payouts screen to parity with the web/server: show each member's **attack count and breakdown** ("what kind of attacks"), show the **mode**, and let an admin **change the loot, payout %, attack weights, and mode** and re-compute. App-only; no server change.

## Scope

- **Per-member detail:** tap a row to expand its attack breakdown + totals.
- **Mode:** shown in the header; toggleable (Dynamic / Static).
- **Controls (gear → settings sheet):** loot override, payout %, assist/non-war/failed weights, mode → Apply re-computes.
- **Fresh-wars-only:** controls recompute only for wars still live on the server. An archived war (e.g. The Zoo) is **read-only** — full detail + frozen amounts, controls disabled with a note. Detected via the response's `scoreSource == "archive"` (set by the server's `serveArchivedPayout`).

Out of scope: war picker, paid tracking, archived-war re-derivation (user chose fresh-only).

## Server endpoints used (already exist; JWT `-admin` flavor)

- `GET /api/war/<warId>/payouts-admin?mode=dynamic|static` (Bearer) — the payout object. Already returns per member: `attackCount`, `totalAttacks`, `breakdown` (object of `{war_hit,retal,overseas_war,assist,chain_hit,os_chain,non_war,failed}` → counts, only nonzero present), `score`, `sharePct`, `dollarPayout`; and top-level `mode`, `scoreSource`, `lootTotal`, `payoutPool`, `payoutPct`, `settings`, `totalScore`.
- `POST /api/war/<warId>/payout-settings-admin` (Bearer), JSON body — **sparse**, only fields the admin set: `lootOverride` (≥0), `payoutPct` (0..1), `assistWeight` (≥0), `nonWarWeight` (≥0), `failedWeight` (≥0). Server persists + invalidates the war's payout cache. After POST, re-fetch the payouts.

Mode is a query param (transient); loot/% /weights persist via the settings POST.

## Breakdown labels (server order, most-valuable first)

`war_hit`→"War hits", `retal`→"Retals", `overseas_war`→"Overseas war", `assist`→"Assists", `chain_hit`→"Chain hits", `os_chain`→"OS chain", `non_war`→"Non-war", `failed`→"Losses". Render only categories with a nonzero count, in this order.

## Screen

Enhance the existing `WarPayoutsView` (app target) + `WarPayoutsViewModel`:

- **Header:** existing pool/loot line + the active **mode** (Dynamic/Static), and the war result pill.
- **Member rows:** compact row unchanged (name · `<attackCount> hits` · owed $). Tap toggles an expanded section showing the breakdown chips (`Label: count`, only nonzero, in the order above), `total attacks`, `score`, and `share %`. Implement with a per-row `@State`/`Set<playerId>` expansion (or `DisclosureGroup`).
- **Toolbar gear** → a settings **sheet** (`@State showSettings`): a Form with Mode (segmented), Loot override (numeric `TextField`, placeholder = current `lootTotal`), Payout % (e.g. a stepper/field 0–100, maps to 0..1), Assists / Non-war / Losses weights (numeric fields, default to current `settings` values), and an **Apply** button. Apply: if the war is archived → disabled (the gear shows but inputs are read-only with the note); else POST changed fields + re-fetch, then dismiss the sheet.
- **Archived note:** when `scoreSource == "archive"`, show a caption under the header: "Archived war — amounts frozen (settings apply only to a war still being computed)." Disable loot/weight inputs; keep the mode toggle (re-fetch with the other mode — may or may not have a cached result, handled by the existing empty/error states).
- **State while applying:** keep prior `.ready` data on screen, show a progress indicator on the Apply button; on error surface the message (reuse OCAPIError copy).

## Data model (extend `WarboardAPI` — app target)

- `PayoutMember`: add `breakdown: [String: Int]` (decode the object, coercing values to Int; default `[:]`), `totalAttacks: Int`, `score: Double`. Keep existing fields.
- `WarPayouts`: add `mode: String` (default "dynamic"), `scoreSource: String?`, `totalScore: Double`, and `settings: PayoutSettings?` where `PayoutSettings` decodes `lootOverride/payoutPct/assistWeight/nonWarWeight/failedWeight` (all optional Doubles). Keep existing fields. `var isArchived: Bool { scoreSource == "archive" }`.
- `fetchWarPayouts(baseUrl:jwt:warId:mode:)` — add a `mode: String = "dynamic"` param → `?mode=<mode>`.
- New `setPayoutSettings(baseUrl:jwt:warId:settings:) async throws` — POST `/api/war/<warId>/payout-settings-admin`, body = a sparse `[String: Double]` of only the changed fields. Throws `OCAPIError` (same as the fetchers). Returns Void (caller re-fetches).

## View-model

`WarPayoutsViewModel` gains: the loaded `warId` (from `admin-list`'s first war — store it on load so settings POST + re-fetch target it), `@Published var mode: String` (default "dynamic"), and an `apply(loot:payoutPct:assistWeight:nonWarWeight:failedWeight:)` that builds the sparse settings dict (only non-nil/changed), calls `setPayoutSettings`, then re-fetches with the current mode. A `setMode(_:)` that re-fetches with the new mode. Guard all admin actions on `!state.isArchived` (no-op + keep read-only when archived).

## Files

- Modify: `Networking/WarboardAPI.swift` (decoder additions + `setPayoutSettings` + `mode` param), `ViewModels/WarPayoutsViewModel.swift` (warId/mode/apply/setMode), `Views/WarPayoutsView.swift` (expandable rows + header mode + settings sheet + archived note).
- No new files, no entry-point changes, no framework/app-boundary changes (all app target).

## Error handling / verification

Reuse `OCAPIError`/`OCMessageView`. 403 → "Admin role required." A settings POST that fails → surface the error, keep prior data, don't dismiss the sheet. Verification: pre-build review of the app-module code (no boundary crossings), CI build, then on-device — open War Payouts on The Zoo (archived → detail + frozen + disabled controls), and (when a fresh war exists) change loot/weights and confirm amounts recompute. No headless tests (project convention).

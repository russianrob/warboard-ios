# In-App Agent: Install Scripts On Its Own — Design

**Status:** Approved for planning
**Date:** 2026-07-02
**Author:** RussianRob (with Claude)
**Repos:** `warboard-ios` (iOS app) + `warboard` server (`/opt/warboard/server`)
**Lineage:** Extends [2026-07-01-in-app-agent-chat-design.md]; see also the page-inspection and screenshot-share specs.

## Goal

When the owner approves a script the in-app agent proposes, the app **installs it into the on-device userscript engine** so it runs immediately and appears in the Scripts manager — and the agent's context reflects the owner's **real installed set** instead of a server directory. One tap on **Approve** = installed, running, and manageable.

## Background — why "deploy" doesn't install today

There are two entirely separate script stores:

1. **Server collection** — `/opt/warboard/server/public/scripts/*.user.js`. The agent's `/api/agent/deploy` writes here (+ git). The agent's context is built by `userscriptContext()` in `agent-service.js:103`, which does `readdirSync(SCRIPTS_DIR)` and (until 2026-07-02) labelled the whole directory "Installed userscripts (N)". This is the owner's **published** collection, not what runs in the app.
2. **On-device registry** — `ScriptRegistry.shared` (`warboard-ios .../Userscripts/ScriptRegistry.swift`), a JSON file at `applicationSupport/Userscripts/userscripts.json`. This is what the app's injector (`UserscriptController.rebuildUserScripts(for:)`) actually runs, and what the Scripts tab (`ScriptsView`) lists.

The Apply card's **Approve & deploy** button → `AgentChatViewModel.deployProposal()` (`AgentChatViewModel.swift:150`) → `AgentClient.deploy(filename:content:)` (`AgentClient.swift:82`) → `POST /api/agent/deploy`. **It never touches `ScriptRegistry`.** So the script is saved server-side but never installed. The agent then overclaimed ("deployed into the app / added to your userscripts") because it conflated the two stores.

A first fix already landed (server commit `058feb1`): the context no longer calls the directory "installed", and the system prompt forbids claiming a deploy installed/activated anything. This spec adds the real capability.

## Approved approach: **C**

Two parts, both gated behind the owner's existing **Approve** tap (no autonomous install):

- **Part 1 — Local install.** Approve installs the proposal's text into `ScriptRegistry` (runs immediately, shows in the Scripts manager). A server backup copy is still saved.
- **Part 2 — Real installed set.** The app sends its live installed list (from the registry) with every agent message; the server builds the agent's `USERSCRIPTS` context from that instead of the server directory. The agent now knows exactly what the owner has installed (correct count/names) and can read/edit **any** of them, including scripts installed from Greasy Fork that the server has never seen.

Rejected alternatives:
- **A (local install, server dir stays the agent's truth):** simplest, but leaves the "wrong installed set" problem — the whole reason the owner raised this.
- **B (reuse the existing install sheet via the tornwar.com URL):** least new code, but adds a second confirmation sheet after the Apply card and re-downloads content already in memory. Worse UX than C's Part 1.

## Architecture / data flow

```
Owner taps Approve on the Apply card
        │
        ▼
AgentChatViewModel.deployProposal()
        ├── (existing) AgentClient.deploy → POST /api/agent/deploy   [server backup + git + publish]
        └── (NEW) LocalInstaller.install(filename, content)
                     │  MetadataParser.parse(content)  → ScriptMetadata
                     │  ScriptFactory.make(meta, source, downloadURL) → Userscript   [shared factory]
                     │  RequireResolver.resolve(script)                 [fetch @require]
                     │  ScriptRegistry.shared.upsert(script)            [keyed by stable id]
                     ▼
              persist() posts .userscriptsDidChange
                     ├── BrowserView observer → model.reload() → rebuildUserScripts → SCRIPT RUNS
                     └── ScriptsView.reload() → appears in Scripts manager

Every agent message:
AgentClient.stream(text, sessionId, installedManifest)
        │  body += { installedScripts: [ {filename,name,version,enabled,source}, ... ] }
        ▼
POST /api/agent/message  (route exempted from the global 1mb cap)
        ▼
runAgentTurn builds "=== USERSCRIPTS ===" from the manifest (not readdir)
   ├── lists real installed scripts + accurate count
   └── ===SOURCE: <filename>=== resolves from the manifest (not SCRIPTS_DIR)
```

## Detailed design

### Part 1 — Local install (iOS)

**New shared factory.** `ScriptFactory.make(meta:source:downloadURL:) -> Userscript` (new file `Userscripts/ScriptFactory.swift`). Extract the logic currently duplicated as `private static func makeScript` in `InstallScriptView.swift:144` and `ScriptsView.swift:154`, and repoint both call sites at it. This removes existing duplication (a targeted cleanup, in-scope because we're adding a third caller). Maps `ScriptMetadata` 1:1 onto `Userscript`, setting `enabled: true`, `order: 0`, `source`, `wildcardConnectGranted: false`, and `id = SHA256Pure.hexDigest(downloadURL)`.

**New install entry point.** `LocalInstaller.install(filename:content:) async throws -> Userscript` (new file `Userscripts/LocalInstaller.swift`, `@MainActor`), reused by the agent path and available for future callers:
1. `let meta = try MetadataParser.parse(content)` — throws on a missing/broken `==UserScript==` block.
2. Reject if `meta.matches.isEmpty && meta.includes.isEmpty` (same guard as the browser install, `InstallScriptView.swift:67`) — a script with no `@match`/`@include` would never run.
3. Synthesize `downloadURL = <scriptsBaseURL>/scripts/<filename>` (the tornwar.com URL the server publishes to). Set the script's `downloadURL`/`updateURL` to it so the app's existing update-check works, and so `id = SHA256(downloadURL)` is **stable per filename**.
4. `let script = ScriptFactory.make(meta:source:content, downloadURL:...)`.
5. `try await RequireResolver.resolve(script)` — fetch `@require` deps (the injector drops the body on a require cache-miss, `UserscriptController.swift:188`).
6. `try ScriptRegistry.shared.upsert(script)` — **upsert, never add**, so redeploying the same filename updates in place (preserving `order`/`enabled`) instead of creating a duplicate row (`ScriptRegistry.swift:62` `add` appends unconditionally; `:70` `upsert` replaces by `id`).

**Wiring.** `AgentChatViewModel.deployProposal()` (`AgentChatViewModel.swift:150`): after the server `deploy` returns, call `LocalInstaller.install(filename:draft.filename, content:draft.content)`. `draft.content` already holds the full text (`ProposalDraft`, `AgentChatViewModel.swift:17`) — no re-fetch. Set `deployStatus` from the combined result (installed vs. save-only-on-failure).

**Re-injection is automatic.** `upsert → persist()` posts `.userscriptsDidChange` (`ScriptRegistry.swift:42`). If the browser tab is open, its observer reloads and the script runs immediately (`BrowserView.swift:362`); otherwise it runs on the next navigation (`rebuildUserScripts` re-reads the registry every nav, `UserscriptController.swift:359`). The status message tells the owner it's installed and to reload the Torn page to see it.

**Button label.** Rename **Apply & deploy** → **Approve & install** (`AgentChatView.swift:167`) to match the new behavior.

### Part 2 — Real installed set (iOS + server)

**iOS — send the manifest.** `AgentClient.stream(text:sessionId:)` (`AgentClient.swift:16`) gains an `installedScripts` array in its JSON body, built from `ScriptRegistry.shared.all()`. Each entry: `{ filename, name, version, enabled, source }`.
- `filename` is the **stable key** the agent uses in `===SOURCE:===`/`===FILE:===`. For agent/server scripts it's the real filename (derive from the `downloadURL` basename); for other scripts (e.g. Greasy Fork) derive `basename(downloadURL)` or a slug of `@name`. Uniqueness is enforced by suffixing collisions.
- `AgentChatViewModel` reads the registry when composing a turn and passes the manifest through.

**Server — build context from the manifest.** `userscriptContext(userText, installed)` (`agent-service.js:103`) changes signature to accept the app-provided `installed` array instead of reading `SCRIPTS_DIR`:
- Header **when built from the manifest**: "The owner's installed userscripts (N):" — now **accurate**, because it's the app's live list.
- Lists `filename — name (vX) — description`.
- Injects full `source` **only** for scripts the owner named in the message (unchanged token-efficiency; sources travel in the payload but aren't all dumped into the prompt).
- **Backward-compatibility fallback:** if the request carries no `installedScripts` (older app build), fall back to the current `readdirSync(SCRIPTS_DIR)` behavior **and keep the current directory header** ("The owner's userscripts on the Warboard server (N) — … NOT the set installed …", shipped in `058feb1`). The header must never claim "installed" for the directory fallback — only the manifest is a real installed set.

**Server — `===SOURCE:===` from the manifest.** `runAgentTurnResolvingSources` / `readScriptSource` (`agent-service.js:169`) resolve a requested filename from the manifest passed into the turn, not `SCRIPTS_DIR`. Falls back to `SCRIPTS_DIR` when no manifest (compat).

**Server — body limit.** `/api/agent/message` (`routes.js:467`) currently declares `express.json({ limit: "64kb" })`, but the global parser at `server.js:96` (`_json1mb`) runs first and shadows it (the documented `req._body` gotcha). Add `/api/agent/message` to the `server.js:96` exemption list (like `/api/screenshot`) and give the route its own `express.json({ limit: "8mb" })`, so the manifest+sources fit. 8mb mirrors the screenshot route's precedent and is ample for dozens of userscripts.

## Error handling

- **Bad header / no `@match`:** `LocalInstaller` throws; `deployProposal` surfaces "Saved to your collection, but couldn't install: <reason>". The server save still succeeded, so nothing is lost.
- **`@require` fetch fails:** surface the failure; do not half-install (the injector would drop the body).
- **Server deploy fails but parse succeeds:** still install locally (the owner gets the working script); status notes the backup didn't save.
- **Manifest too large / malformed:** server ignores unparseable entries and logs; falls back to `SCRIPTS_DIR` if the whole array is missing.
- **Filename-key collisions in the manifest:** suffix to keep keys unique so `===SOURCE:===` is unambiguous.

## Security

- **No autonomous install.** Install happens only on the owner's explicit **Approve** tap — the same human gate that exists today. A prompt-injected proposal can be *offered* but never installs without the owner approving the card (which shows a plain-language summary + "View file"). This preserves the project's core posture (agent has zero tools; every consequential action is owner-approved).
- **Trust of installed scripts** is identical to the owner installing from Greasy Fork — the script runs in the authenticated Torn webview because the owner chose to install it. No new trust boundary.
- **The manifest** is the owner's own data sent to the owner's own server over the existing authenticated HTTPS channel — no new exposure.
- The Apply card must remain informative enough for an informed approve (existing summary + file viewer).

## Testing

**iOS (XCTest; iOS compiles via CI only — adversarial review before shipping):**
- `ScriptFactory.make` maps every `ScriptMetadata` field correctly (extend `UserscriptModelTests`).
- Identity stability: same filename → same `id`; redeploy → `upsert` updates in place, `registry.all().count` unchanged (no duplicate).
- `LocalInstaller` rejects a no-`@match` script and a broken header.
- Manifest builder produces unique filename keys under collision.

**Server (node --check + unit):**
- `userscriptContext(text, installed)` lists the manifest, correct count, injects source only for named scripts.
- Fallback to `SCRIPTS_DIR` when `installed` is absent.
- `===SOURCE:===` resolves from the manifest; falls back to dir.
- `/api/agent/message` accepts a >1mb body after the exemption.

**Manual E2E:** propose a script → Approve → appears in Scripts tab, runs after a Torn reload → redeploy an edit → updates in place (no dup) → agent's next turn lists the real installed set with the correct count and can `===SOURCE:===` a Greasy-Fork-only script.

## Out of scope (future)

- **Payload optimization:** a session-scoped source sync so full sources aren't re-sent every turn (send lightweight manifest per message, sources once per session). Do this only if per-message size becomes a problem.
- **Agent-initiated uninstall/disable/reorder** — the owner does that in the Scripts manager for now.
- **Publish-to-Greasy-Fork as a distinct action** — server backup stays automatic; deliberate publishing is a later feature.
- **Approach A/B** paths.

## Open questions

_None — resolved during brainstorming:_ approval model = **Approve → it installs** (no autonomous install); server backup **kept** (but no longer the agent's source of truth for "installed"); scripts **do** appear in the Scripts manager (they enter the one registry the manager reads).

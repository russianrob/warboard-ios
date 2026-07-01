# Agent read-only page inspection — design

**Goal:** let the owner's in-app agent see much more of the live Torn page — DOM,
CSS, console errors, network — read-only, with the owner approving each custom
query. Builds on the agent chat, the inspect bridge (`runJsOnDevice`), and the
`--resume` continuity.

## Decisions (owner-approved)
- **Access:** BOTH — a light always-on enrichment of every turn's snapshot, PLUS
  on-demand drill-down.
- **Power:** arbitrary JS, but the owner **approves each run** before it touches
  the page (the review is the read-only / no-interaction guarantee).
- **Console hook:** injected **only when signed in as owner**.

## A. Light default (every turn)
`SNAPSHOT_JS` grows to also capture:
- **DOM skeleton** of the main content — tag + id + class, depth-capped, length-
  capped (NOT full HTML). One-shot, cheap.
- **Recent console errors/warnings + uncaught errors** — read from a ring buffer
  (`window.__wbInspect.console`) maintained by an owner-only document-start hook.
  Absent (skipped) for non-owners / before the hook installs.

Full HTML and network stay drill-down-only.

## B. Drill-down loop (on-demand, owner-approved)
1. Agent emits a query in a protocol block: `===INSPECT===\n<js>\n===` (mirrors
   the `===FILE:` proposal protocol).
2. `runAgentTurn` detects it (`parseInspect`) and emits `{t:"inspectRequest", js}`;
   the turn ends.
3. iOS shows an approval card: the JS + **[Approve & run] / [Decline]**.
4. Approve → `POST /api/agent/inspect {js, sessionId}` (owner SSE): server runs the
   JS via `runJsOnDevice` (page world), trims the result, then calls
   `runAgentTurn({ text: "=== INSPECTION RESULT ===…", sessionId })` (`--resume`) and
   streams the continuation.
5. The continuation may answer, or emit another `inspectRequest` (loop). Cap ~5
   cycles/question. A per-question **"trust this session"** toggle auto-approves.
6. Decline → agent is told ("owner declined") and answers without it.

## Safety
Owner-only end to end (`_inspectIsOwner`). Every custom JS run is shown to the
owner before it runs — the gate that enforces read-only/no-interaction. Result
size-capped (~20KB). Runs only against the owner's own device via the existing
inspect relay. The console hook only wraps console/error (no data exfiltration
surface beyond what the owner already sees).

## Components
**Server** (`agent-service.js`, `routes.js`): enrich `SNAPSHOT_JS`; add
`parseInspect` (+ tests) and the `{t:"inspectRequest"}` emit in `runAgentTurn`;
`POST /api/agent/inspect` (owner SSE, runs JS then resumes); teach the protocol in
`SYSTEM_PROMPT`; import `runJsOnDevice` into routes.

**iOS** (`AgentEvent`, `AgentClient`, `AgentChatViewModel`, `AgentChatView`,
userscript engine): `inspectRequest` event; `AgentClient.inspect(js:sessionId:)`
streaming the continuation; approval card + "trust this session" toggle; the
client loop (request → card → approve → inspect → continue); an owner-only
document-start console-capture hook injected by the engine.

## Reuse
`parseProposal`→`parseInspect`; proposal card→inspect card; deploy run-pattern→
`runJsOnDevice`; `--resume` continuity (built earlier today); document-start
injection for the console hook.

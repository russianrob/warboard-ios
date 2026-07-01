# In-App Agent Chat — Design

**Status:** draft for review
**Date:** 2026-07-01
**Repos touched:** `warboard-ios` (iOS chat UI, keep-awake) and `warboard` server at `/opt/warboard` (agent service, scoped tools)

## Goal

Let the owner chat with a Claude agent *inside* the Warboard iOS app. The agent can **see and drive the live Torn WKWebView** (inspect) and **edit/deploy userscripts**. Because the chat is in-app, the app stays foregrounded — so the inspect bridge is live and the whole foreground/background friction of the remote-inspect workflow disappears.

## Motivation

Remote inspect only works while the app is foregrounded (iOS suspends backgrounded apps; a backgrounded WKWebView's content process is frozen, so JS is flaky and screenshots come back blank). On a single phone the owner can't chat with the agent *and* keep Warboard foregrounded at once, forcing a constant app-switching dance. An in-app chat inverts this: chatting **is** being in the app, so the page is always inspectable.

## Non-goals

- Not multi-user, not a public product — **single owner only** (playerId `137558`).
- **No open root shell** on the server (scope 2: inspect + userscript deploy only).
- Not a replacement for desktop Claude Code or the Mac CDP path for heavy work.
- v1 requires network + server; no offline mode.

## Constraints & dependencies

- **Claude access = headless Claude Code** (`claude -p`) on the warboard server, authed via the existing **Claude Max 5× subscription** (OAuth; no API key). Verified present (`/root/.local/bin/claude` v2.1.196), headless returns in ~3s for a trivial turn.
- **ToS posture:** personal, single-user use of Claude Code via a phone frontend. Defensible as personal use; **not** the sanctioned "API-key app backend." Accepted knowingly. Would cross the line if it ever became multi-user/public.
- **Shared quota:** draws on the Max 5× limits, **amplified by ultracode-always-on** — can rate-limit the owner's normal Claude Code work.

## Architecture — three components

### A. iOS `AgentChatView`
- Owner-gated screen, `NavigationLink` from the existing owner section in `SettingsView` (`SettingsView.swift:79–90`, gated on `admin.auth?.isOwner` = playerId `137558`). Presented over the always-mounted `BrowserView`, so `InspectBridge.shared.run/.snapshot` stay live (no tab teardown — the app has no TabView; every screen is layered over the persistent browser).
- Streaming chat UI: user/assistant message list, streamed assistant text, a compact **tool-activity line** (e.g. "inspecting page…", "deploying torn-dual-flyout…"), input field, send button. Style on `PM2LogsViewer` (monospaced output) + standard `Form`/`TextField` conventions.
- On appear: **arm inspect** (ensure `InspectClient` is running) + `UIApplication.shared.isIdleTimerDisabled = true` (keep-awake so long turns aren't cut by the screen dimming). On disappear/background: restore both.
- Talks to `POST /api/agent/message` over SSE; holds a `sessionId` for continuity.

### B. Server `/api/agent/*`
- New `agent-service.js` + routes, **owner-JWT gated** (reuse the inspect routes' `requireAuth` + `playerId === "137558"`).
- `POST /api/agent/message` `{ sessionId?, text }` → spawn:
  `claude -p <text> --output-format stream-json [--resume <sessionId>] --mcp-config <scoped-tools.json> --disallowedTools "Bash,Write,Edit,WebFetch,WebSearch,Task" --permission-mode <non-interactive>` in a dedicated **trusted** agent working dir.
- Transform the `stream-json` events → a simpler SSE stream for the app: `assistant_delta`, `tool_use`, `tool_result`, `usage`, `done`, `error`. Capture and return the resolved session id.
- **Concurrency guard:** one active agent process per owner; new message while busy either queues or is rejected with a clear state.
- Process hygiene: per-turn timeout, kill/cleanup on client disconnect.

### C. Scoped toolset (MCP server) — the security boundary
A small stdio **MCP server** (Node) loaded via `--mcp-config`. It exposes *only*:
- `inspect_run_js(js)` → enqueue to `/api/inspect/cmd`, poll `/api/inspect/result`, return `{value|error}`. (Works because the app is foregrounded + inspect armed during chat.)
- `inspect_screenshot()` → request a screenshot via the relay; return a reference the app/agent can use.
- `userscript_list()` / `userscript_read(name)` / `userscript_write(name, content)` — **path-jailed** to `/opt/warboard/server/public/scripts/` only.
- `userscript_deploy(name)` → `node --check` + `git add/commit/push` + served-URL check.

Claude Code is launched with **Bash/Write/Edit/WebFetch/WebSearch/Task disallowed**; the agent can touch the server *only* through these tools. So "scope 2" is enforced by **what tools exist**, not by trust or by the OS user. Even if the process runs as root, it has no arbitrary-command path.

## Data flow

```
owner types → POST /api/agent/message (SSE opens)
  → server spawns `claude -p … --mcp-config scoped`
    → agent reasons, calls inspect_run_js  (MCP)
      → MCP enqueues /api/inspect/cmd
        → device InspectClient (foreground) runs JS on the live WKWebView, posts /api/inspect/result
      → MCP returns value to agent
    → agent may call userscript_write/deploy (MCP, path-jailed + git)
    → agent streams assistant text
  → server transforms stream-json → SSE deltas → AgentChatView renders live
```

## Session continuity
`claude -p --resume <sessionId>` (or `--session-id`). Server stores the chat↔session mapping; "New chat" starts a fresh session.

## Auth & security
- Owner JWT (`playerId 137558`) on all `/api/agent/*`.
- **Tool-gating (no Bash) is the core boundary**; file tools are path-jailed to the scripts dir.
- Resolve the "workspace not trusted" warning by trusting a dedicated agent workdir (`projects["<workdir>"].hasTrustDialogAccepted = true`) and relying on `--disallowedTools` regardless.
- Inspect only functions while the app is foreground + armed; the chat arms it. The red "REMOTE INSPECT ON" banner already surfaces armed state.
- Non-owner JWT and path-traversal attempts must be rejected (explicit tests).

## Keep-awake
While `AgentChatView` is visible: `UIApplication.shared.isIdleTimerDisabled = true` + inspect armed; restore on disappear/background (wire in the view lifecycle and/or the existing `WarboardIOSApp` scenePhase `.onChange` at `:48–65`).

## Ultracode (Phase 3 — flagged risk)
"Always on" means the headless agent should orchestrate via the **Workflow** tool — but Workflow is **provided by this harness, not part of a stock `claude -p` session**. Validate with a spike:
- (a) Is Workflow loadable as a plugin/MCP into headless Claude Code?
- (b) If not, emulate fan-out with a custom `workflow` MCP tool that spawns sub-`claude -p` processes.
**Fallback:** single-agent, which is fully functional (just no fan-out). Ultracode is deliberately last so it can't block core value.

## Phasing
- **Phase 1 (MVP):** A (chat + stream + keep-awake) + B (spawn/stream `claude -p`) + C **inspect-only** tools. End-to-end proof: chat, watch it read the live page.
- **Phase 2:** add `userscript_read/write/deploy` (full scope 2): iterate + ship a userscript from the phone.
- **Phase 3:** ultracode wiring (spike → implement or fallback).

## Testing / verification
- **Server:** unit-test MCP tools (path-jail, deploy pipeline, inspect relay round-trip), the stream-json→SSE transform, the owner gate. Integration: spawn `claude -p` with a canned prompt and assert the event stream.
- **iOS:** on-device E2E (the real value) — chat, watch it inspect the page, deploy a trivial userscript change, confirm served.
- **Security:** path-traversal in `userscript_write` rejected; Bash unavailable; non-owner JWT rejected.

## Open questions / risks
1. Ultracode-in-headless feasibility (spike first).
2. Exact `claude -p` streaming/resume flags + behavior (validate early).
3. Quota burn with ultracode-always — add a visible usage readout + a hard per-turn/agent cap + a kill switch.
4. Tool-loop latency (inspect goes server→device→server per call).
5. Trust-dialog handling for the agent workdir.
6. Process lifecycle: timeouts, cleanup on disconnect, one-active-per-owner.

## Cost / quota note
Runs on the shared Max 5× subscription; ultracode-always amplifies consumption. Mitigations: a visible per-session usage/turn readout in the chat, a hard cap per turn, and an obvious kill switch. Heavy multi-agent work should still prefer desktop Claude Code.

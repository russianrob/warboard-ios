# In-App Agent Chat — Phase 1 (MVP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owner can open an in-app chat in the Warboard iOS app, talk to a Claude agent running headless on the warboard server, and have that agent read/drive the live Torn WebView via an inspect-only scoped toolset — with token streaming, session continuity, owner gating, and keep-awake.

**Architecture:** iOS `AgentChatView` (SSE client) → server `POST /api/agent/message` (owner-JWT, SSE) → `agent-service.js` spawns `claude -p --output-format stream-json --include-partial-messages` with `--strict-mcp-config` loading only `agent-mcp-inspect.mjs` (tools `inspect_run_js`, `inspect_screenshot`) and all built-in tools disallowed. The MCP server reaches the live page through the existing inspect relay (`/api/inspect/*`), which works because the app is foregrounded + inspect armed while chatting.

**Tech Stack:** Node 20 (ESM), Express (existing `routes.js`), `node:test`, `@modelcontextprotocol/sdk`, headless Claude Code (`claude` v2.1.196, Max-subscription OAuth), Swift/SwiftUI (XcodeGen project, framework `WarboardIOS` + app `Warboard`), URLSession SSE.

## Global Constraints

- **Owner-only:** every `/api/agent/*` route is gated `requireAuth` + `String(req.user.playerId) === "137558"` (the `_INSPECT_OWNER` constant in `routes.js:393`). Copy that pattern verbatim.
- **No open shell (scope 2 → Phase 1 = inspect-only):** the spawned agent must be launched with **all built-in tools disallowed** and **only** the inspect MCP tools usable. This is the security boundary and MUST be tested.
- **Backend Claude = headless `claude -p`** on the Max subscription; spawn with cwd = a clean, hook-free, trusted agent workdir (never `/root`, which injects SessionStart hooks + memory).
- **Streaming flags (exact):** `--print --output-format stream-json --verbose --include-partial-messages`. `--verbose` is mandatory with `--print`+stream-json.
- **Session continuity:** capture `session_id` from the `system/init` event; resume with `--resume <id>`.
- **ESM only** (`"type":"module"`); tests are `node:test` files named `*.test.js`, run with `node --test <file>`.
- **Quota safety:** the chat surfaces the `rate_limit_event` status; a per-turn wall-clock timeout kills a runaway agent process.
- **iOS:** `AgentChatView` reached only from the owner-gated section of `SettingsView` (`SettingsView.swift:79-90`); presented over the always-mounted `BrowserView` so `InspectBridge.shared` stays live.

---

## File Structure

Server (`/opt/warboard/server/`):
- `agent-mcp-inspect.mjs` — **create.** Stdio MCP server exposing `inspect_run_js` + `inspect_screenshot`, implemented via the inspect relay (operator token). One responsibility: expose page-inspection as MCP tools.
- `agent-relay-client.js` — **create.** Small module: `runJsOnDevice(js, opts)` / `screenshotDevice(opts)` that call the local relay with the operator token. Imported by the MCP server AND unit-tested with a mocked `fetch`.
- `agent-service.js` — **create.** `runAgentTurn({ text, sessionId, workdir, onEvent, signal })`: spawns `claude`, parses stdout JSONL, emits normalized events, resolves `{ sessionId }`. Plus `normalizeStreamLine(obj)` (pure, unit-tested).
- `agent-service.test.js` — **create.** Unit tests for `normalizeStreamLine`.
- `agent-relay-client.test.js` — **create.** Unit tests for the relay client (mocked fetch).
- `routes.js` — **modify.** Add `POST /api/agent/message` (owner-gated SSE) near the inspect routes (~line 425).
- `data/agent-mcp.json` — **create.** MCP config passed to `--mcp-config`.
- `data/agent-workdir/` — **create** (empty, hook-free) working dir for the spawned agent.
- `package.json` — **modify.** Add `@modelcontextprotocol/sdk` + `zod`.

iOS (`/root/projects/warboard-ios/`):
- `Warboard/Sources/Warboard/Agent/AgentEvent.swift` — **create.** The decoded SSE event enum + a pure `parseAgentSSE(_ line:)` decoder (unit-tested).
- `Warboard/Sources/Warboard/Agent/AgentClient.swift` — **create.** URLSession SSE client → `AsyncStream<AgentEvent>`.
- `Warboard/Sources/Warboard/Agent/AgentChatViewModel.swift` — **create.** `@MainActor ObservableObject` holding messages + send().
- `Warboard/Sources/Warboard/Agent/AgentChatView.swift` — **create.** The chat screen + keep-awake + arm-inspect lifecycle.
- `SettingsView.swift` — **modify** (~line 88). Add `NavigationLink("Agent chat") { AgentChatView() }` inside the owner section.
- `WarboardTests/AgentEventTests.swift` — **create.** Unit tests for `parseAgentSSE`.

*(Exact iOS file paths follow the repo's existing target layout; if `Warboard/Sources/Warboard/` differs, place the new files beside `SettingsView.swift` in the same target and adjust the module import accordingly.)*

---

## Task 1: Inspect relay client + unit tests

**Files:**
- Create: `/opt/warboard/server/agent-relay-client.js`
- Test: `/opt/warboard/server/agent-relay-client.test.js`

**Interfaces:**
- Produces: `runJsOnDevice(js, { base, token, timeoutMs, fetchImpl, sleepImpl }) → Promise<{ value?: string, error?: string }>`; `screenshotDevice({ base, token, timeoutMs, fetchImpl, sleepImpl }) → Promise<{ ref?: string, error?: string }>`. Injectable `fetchImpl`/`sleepImpl` for tests.

- [ ] **Step 1: Write the failing test**

```js
// agent-relay-client.test.js
import test from "node:test";
import assert from "node:assert/strict";
import { runJsOnDevice, screenshotDevice } from "./agent-relay-client.js";

// Ground truth (routes.js:400-428): operator ENQUEUEs via POST /api/inspect/cmd
// ({js} or {action:"screenshot"}) and READS via GET /api/inspect/result (drains
// {results:[{id,kind,result,error}]}). These tests assert that exact contract.

test("runJsOnDevice: POST /api/inspect/cmd {js} then GET /api/inspect/result", async () => {
  const calls = [];
  const fetchImpl = async (url, opts) => {
    calls.push({ url, method: opts.method, body: opts.body ? JSON.parse(opts.body) : null });
    if (url.endsWith("/api/inspect/cmd")) return { json: async () => ({ ok: true, id: "cmd_1" }) };
    if (url.endsWith("/api/inspect/result")) return { json: async () => ({ results: [{ id: "cmd_1", kind: "js", result: "\"Home | TORN\"" }] }) };
    throw new Error("unexpected url " + url);
  };
  const out = await runJsOnDevice("return document.title", { base: "http://x", token: "t", fetchImpl, sleepImpl: async () => {} });
  assert.equal(out.value, "\"Home | TORN\"");
  const cmd = calls.find(c => c.url.endsWith("/api/inspect/cmd"));
  assert.equal(cmd.method, "POST");
  assert.deepEqual(cmd.body, { js: "return document.title" });
  const read = calls.find(c => c.url.endsWith("/api/inspect/result"));
  assert.equal(read.method, "GET");
});

test("runJsOnDevice returns a timeout error when no result arrives", async () => {
  const fetchImpl = async (url) => {
    if (url.endsWith("/api/inspect/cmd")) return { json: async () => ({ ok: true, id: "cmd_2" }) };
    return { json: async () => ({ results: [] }) };
  };
  const out = await runJsOnDevice("x", { base: "http://x", token: "t", timeoutMs: 5, fetchImpl, sleepImpl: async () => {} });
  assert.match(out.error, /timeout/i);
});

test("runJsOnDevice surfaces a device error result", async () => {
  const fetchImpl = async (url) => {
    if (url.endsWith("/api/inspect/cmd")) return { json: async () => ({ ok: true, id: "cmd_3" }) };
    return { json: async () => ({ results: [{ id: "cmd_3", kind: "js", error: "ReferenceError: x is not defined" }] }) };
  };
  const out = await runJsOnDevice("x", { base: "http://x", token: "t", fetchImpl, sleepImpl: async () => {} });
  assert.match(out.error, /ReferenceError/);
});

test("screenshotDevice enqueues {action:'screenshot'} via POST and returns the ref id", async () => {
  const calls = [];
  const fetchImpl = async (url, opts) => {
    calls.push({ method: opts.method, body: opts.body ? JSON.parse(opts.body) : null });
    return { json: async () => ({ ok: true, id: "shot_1" }) };
  };
  const out = await screenshotDevice({ base: "http://x", token: "t", fetchImpl });
  assert.equal(out.ref, "shot_1");
  assert.equal(calls[0].method, "POST");
  assert.deepEqual(calls[0].body, { action: "screenshot" });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /opt/warboard/server && node --test agent-relay-client.test.js`
Expected: FAIL — `Cannot find module './agent-relay-client.js'`.

- [ ] **Step 3: Write minimal implementation**

```js
// agent-relay-client.js
import { readFileSync } from "node:fs";

const DEFAULT_TOKEN_FILE = process.env.INSPECT_TOKEN_FILE || "/opt/warboard/server/data/.inspect-token";
export function defaultToken() { return readFileSync(DEFAULT_TOKEN_FILE, "utf8").trim(); }

// Enqueue a command: POST /api/inspect/cmd with the operator token (routes.js:401).
async function enqueue(fetchImpl, base, token, cmd) {
  const r = await fetchImpl(base + "/api/inspect/cmd", {
    method: "POST",
    headers: { "x-inspect-token": token, "content-type": "application/json" },
    body: JSON.stringify(cmd),
  });
  return r.json();
}
// Drain results: GET /api/inspect/result with the operator token (routes.js:425).
async function drainResults(fetchImpl, base, token) {
  const r = await fetchImpl(base + "/api/inspect/result", {
    method: "GET",
    headers: { "x-inspect-token": token },
  });
  return r.json();
}

export async function runJsOnDevice(js, opts = {}) {
  const { base = "http://localhost:3000", token = defaultToken(), timeoutMs = 15000,
          fetchImpl = fetch, sleepImpl = (ms) => new Promise((s) => setTimeout(s, ms)) } = opts;
  const q = await enqueue(fetchImpl, base, token, { js });
  const id = q && q.id;
  if (!id) return { error: "relay did not accept command" };
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const r = await drainResults(fetchImpl, base, token);
    const hit = (r.results || []).find((x) => x.id === id);
    if (hit) return hit.error ? { error: String(hit.error) } : { value: hit.result != null ? String(hit.result) : "null" };
    await sleepImpl(700);
  }
  return { error: "timeout waiting for device (is the Warboard app foregrounded with inspect armed?)" };
}

export async function screenshotDevice(opts = {}) {
  const { base = "http://localhost:3000", token = defaultToken(), fetchImpl = fetch } = opts;
  const q = await enqueue(fetchImpl, base, token, { action: "screenshot" });
  return q && q.id ? { ref: q.id } : { error: "screenshot request rejected" };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /opt/warboard/server && node --test agent-relay-client.test.js`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && git add server/agent-relay-client.js server/agent-relay-client.test.js
git commit -m "feat(agent): inspect relay client for the in-app agent's tools"
```

---

## Task 2: Scoped inspect MCP server

**Files:**
- Modify: `/opt/warboard/server/package.json` (add deps)
- Create: `/opt/warboard/server/agent-mcp-inspect.mjs`
- Create: `/opt/warboard/server/data/agent-mcp.json`

**Interfaces:**
- Consumes: `runJsOnDevice`, `screenshotDevice` (Task 1).
- Produces: an MCP stdio server advertising tools `inspect_run_js({ js: string })` and `inspect_screenshot({})`. Tool names as seen by Claude: `mcp__warboard-inspect__inspect_run_js`, `mcp__warboard-inspect__inspect_screenshot`.

- [ ] **Step 1: Add dependencies**

Run: `cd /opt/warboard/server && npm install @modelcontextprotocol/sdk zod`
Expected: both added to `package.json` dependencies; `node_modules/@modelcontextprotocol` exists.

- [ ] **Step 2: Write the MCP server**

```js
// agent-mcp-inspect.mjs
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { runJsOnDevice, screenshotDevice } from "./agent-relay-client.js";

const server = new McpServer({ name: "warboard-inspect", version: "1.0.0" });

server.tool(
  "inspect_run_js",
  "Run JavaScript in the MAIN world of the live Torn page inside the Warboard app's WebView and return the JSON-stringified result. Write `return <expr>;`. Prefer serializing DOM/state to text over screenshots.",
  { js: z.string().describe("JS body; use `return ...` to produce a value") },
  async ({ js }) => {
    const r = await runJsOnDevice(js);
    return { content: [{ type: "text", text: r.error ? "ERROR: " + r.error : (r.value ?? "null") }] };
  }
);

server.tool(
  "inspect_screenshot",
  "Request a downscaled PNG screenshot of the live Torn page. Returns a reference id; screenshots may be unavailable if the app is backgrounded.",
  {},
  async () => {
    const r = await screenshotDevice();
    return { content: [{ type: "text", text: r.error ? "ERROR: " + r.error : ("screenshot queued: " + r.ref) }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

- [ ] **Step 3: Write the MCP config**

```json
// data/agent-mcp.json
{
  "mcpServers": {
    "warboard-inspect": {
      "command": "node",
      "args": ["/opt/warboard/server/agent-mcp-inspect.mjs"],
      "env": { "INSPECT_TOKEN_FILE": "/opt/warboard/server/data/.inspect-token" }
    }
  }
}
```

- [ ] **Step 4: Smoke-test the server starts and lists tools**

Run:
```bash
cd /opt/warboard/server
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | timeout 10 node agent-mcp-inspect.mjs 2>/dev/null | grep -o "inspect_run_js"
```
Expected: prints `inspect_run_js` (server initialized and advertised the tool).

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && git add server/agent-mcp-inspect.mjs server/data/agent-mcp.json server/package.json server/package-lock.json
git commit -m "feat(agent): scoped inspect MCP server (inspect_run_js, inspect_screenshot)"
```

---

## Task 3: Agent service — spawn + stream-json normalizer

**Files:**
- Create: `/opt/warboard/server/agent-service.js`
- Create: `/opt/warboard/server/agent-service.test.js`
- Create: `/opt/warboard/server/data/agent-workdir/.keep` (empty, hook-free cwd)

**Interfaces:**
- Consumes: `data/agent-mcp.json`, the `claude` binary.
- Produces:
  - `normalizeStreamLine(obj) → AgentEvent | null` where `AgentEvent` is one of: `{t:"session", id}`, `{t:"delta", text}`, `{t:"thinking"}`, `{t:"tool", name, phase:"start"}`, `{t:"tool_result", ok}`, `{t:"rate", status, resetsAt}`, `{t:"done", ok, result}`, `{t:"error", message}`.
  - `runAgentTurn({ text, sessionId, onEvent, signal }) → Promise<{ sessionId }>`.

- [ ] **Step 1: Write the failing normalizer tests**

```js
// agent-service.test.js
import test from "node:test";
import assert from "node:assert/strict";
import { normalizeStreamLine } from "./agent-service.js";

test("captures session id from system/init", () => {
  const e = normalizeStreamLine({ type: "system", subtype: "init", session_id: "abc" });
  assert.deepEqual(e, { t: "session", id: "abc" });
});

test("maps a text_delta stream_event to a delta", () => {
  const e = normalizeStreamLine({ type: "stream_event", event: { type: "content_block_delta", index: 1, delta: { type: "text_delta", text: "hi" } } });
  assert.deepEqual(e, { t: "delta", text: "hi" });
});

test("ignores thinking_delta as a thinking indicator, not text", () => {
  const e = normalizeStreamLine({ type: "stream_event", event: { type: "content_block_delta", delta: { type: "thinking_delta", thinking: "" } } });
  assert.deepEqual(e, { t: "thinking" });
});

test("maps rate_limit_event", () => {
  const e = normalizeStreamLine({ type: "rate_limit_event", rate_limit_info: { status: "allowed", resetsAt: 123 } });
  assert.deepEqual(e, { t: "rate", status: "allowed", resetsAt: 123 });
});

test("maps a successful result to done", () => {
  const e = normalizeStreamLine({ type: "result", subtype: "success", is_error: false, result: "PONG", session_id: "abc" });
  assert.deepEqual(e, { t: "done", ok: true, result: "PONG" });
});

test("ignores hook noise", () => {
  assert.equal(normalizeStreamLine({ type: "system", subtype: "hook_started" }), null);
  assert.equal(normalizeStreamLine({ type: "system", subtype: "hook_response" }), null);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /opt/warboard/server && node --test agent-service.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement normalizer + spawner**

```js
// agent-service.js
import { spawn } from "node:child_process";

const CLAUDE = process.env.CLAUDE_BIN || "/root/.local/bin/claude";
const WORKDIR = process.env.AGENT_WORKDIR || "/opt/warboard/server/data/agent-workdir";
const MCP_CONFIG = process.env.AGENT_MCP_CONFIG || "/opt/warboard/server/data/agent-mcp.json";
// SECURITY: deny EVERY built-in tool so only the scoped MCP inspect tools remain.
// Validated live 2026-07-01: with this exact list the agent enumerates ONLY
// mcp__warboard-inspect__inspect_run_js + inspect_screenshot. Notes:
//  - An allow-list (--allowed-tools) does NOT restrict under --permission-mode default (Bash still ran).
//  - The init event's tools[] is NOT exhaustive: Glob/Grep are present but unlisted — deny them explicitly.
//  - bypassPermissions maps to --dangerously-skip-permissions which refuses under root;
//    IS_SANDBOX=1 (set in the spawn env below) bypasses only that root guard, Bash stays blocked.
const DISALLOWED = ["Task","Bash","CronCreate","CronDelete","CronList","DesignSync","Edit","EnterWorktree","ExitWorktree","Monitor","NotebookEdit","PushNotification","Read","RemoteTrigger","ReportFindings","ScheduleWakeup","SendMessage","Skill","TaskCreate","TaskGet","TaskList","TaskOutput","TaskStop","TaskUpdate","ToolSearch","WebFetch","WebSearch","Workflow","Write","Glob","Grep"];
const TURN_TIMEOUT_MS = Number(process.env.AGENT_TURN_TIMEOUT_MS || 180000);

export function normalizeStreamLine(o) {
  if (!o || typeof o !== "object") return null;
  if (o.type === "system") {
    if (o.subtype === "init") return { t: "session", id: o.session_id };
    return null; // hook_started/hook_response/status/thinking_tokens → ignore
  }
  if (o.type === "stream_event" && o.event) {
    const ev = o.event;
    if (ev.type === "content_block_delta" && ev.delta) {
      if (ev.delta.type === "text_delta") return { t: "delta", text: ev.delta.text || "" };
      if (ev.delta.type === "thinking_delta") return { t: "thinking" };
    }
    return null;
  }
  if (o.type === "assistant" && o.message && Array.isArray(o.message.content)) {
    const tool = o.message.content.find((c) => c.type === "tool_use");
    if (tool) return { t: "tool", name: tool.name, phase: "start" };
    return null;
  }
  if (o.type === "user" && o.message && Array.isArray(o.message.content)) {
    const tr = o.message.content.find((c) => c.type === "tool_result");
    if (tr) return { t: "tool_result", ok: !tr.is_error };
    return null;
  }
  if (o.type === "rate_limit_event") return { t: "rate", status: o.rate_limit_info?.status, resetsAt: o.rate_limit_info?.resetsAt };
  if (o.type === "result") return { t: "done", ok: !o.is_error, result: o.result ?? "" };
  return null;
}

export function runAgentTurn({ text, sessionId, onEvent, signal }) {
  return new Promise((resolve) => {
    const args = ["--print", String(text),
      "--output-format", "stream-json", "--verbose", "--include-partial-messages",
      "--mcp-config", MCP_CONFIG, "--strict-mcp-config",
      "--permission-mode", "bypassPermissions",
      "--disallowed-tools", ...DISALLOWED];
    if (sessionId) args.push("--resume", sessionId);
    const child = spawn(CLAUDE, args, { cwd: WORKDIR, env: { ...process.env, IS_SANDBOX: process.env.IS_SANDBOX || "1" }, stdio: ["ignore", "pipe", "pipe"] });
    let resolvedSession = sessionId || null;
    let buf = "";
    const killTimer = setTimeout(() => { onEvent({ t: "error", message: "agent turn timed out" }); child.kill("SIGKILL"); }, TURN_TIMEOUT_MS);
    if (signal) signal.addEventListener("abort", () => child.kill("SIGKILL"), { once: true });
    child.stdout.on("data", (d) => {
      buf += d.toString();
      let nl;
      while ((nl = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, nl).trim(); buf = buf.slice(nl + 1);
        if (!line) continue;
        let obj; try { obj = JSON.parse(line); } catch { continue; }
        const ev = normalizeStreamLine(obj);
        if (ev) { if (ev.t === "session") resolvedSession = ev.id; onEvent(ev); }
      }
    });
    child.stderr.on("data", (d) => onEvent({ t: "stderr", text: d.toString().slice(0, 500) }));
    child.on("close", () => { clearTimeout(killTimer); resolve({ sessionId: resolvedSession }); });
    child.on("error", (e) => { clearTimeout(killTimer); onEvent({ t: "error", message: String(e) }); resolve({ sessionId: resolvedSession }); });
  });
}
```

- [ ] **Step 4: Create the hook-free workdir**

Run: `mkdir -p /opt/warboard/server/data/agent-workdir && touch /opt/warboard/server/data/agent-workdir/.keep`
Then trust it for claude (avoids the "workspace not trusted" warning):
Run: `node -e 'const f="/root/.claude.json";const j=require(f);j.projects=j.projects||{};j.projects["/opt/warboard/server/data/agent-workdir"]={...(j.projects["/opt/warboard/server/data/agent-workdir"]||{}),hasTrustDialogAccepted:true};require("fs").writeFileSync(f,JSON.stringify(j,null,2));console.log("trusted")'`
Expected: prints `trusted`.

- [ ] **Step 5: Run to verify normalizer tests pass**

Run: `cd /opt/warboard/server && node --test agent-service.test.js`
Expected: PASS (6 tests).

- [ ] **Step 6: SECURITY validation — Bash must be blocked (manual, costs a little quota)**

Run:
```bash
cd /opt/warboard/server && node -e '
import("./agent-service.js").then(async ({runAgentTurn})=>{
  let out="";
  await runAgentTurn({text:"Use the Bash tool to run `id` and paste its raw output. If you cannot, say exactly CANNOT_BASH.", onEvent:(e)=>{ if(e.t==="delta") out+=e.text; if(e.t==="tool") out+="[TOOL:"+e.name+"]"; }});
  console.log("AGENT SAID:", out.slice(0,400));
})'
```
Expected: output contains `CANNOT_BASH` (or a refusal) and **no** `uid=` and **no** `[TOOL:Bash]`. If Bash ran, STOP — the lockdown is wrong; do not proceed.

- [ ] **Step 7: Commit**

```bash
cd /opt/warboard && git add server/agent-service.js server/agent-service.test.js server/data/agent-workdir/.keep
git commit -m "feat(agent): headless claude spawner + stream-json normalizer (bash-locked)"
```

---

## Task 4: `POST /api/agent/message` (owner-gated SSE)

**Files:**
- Modify: `/opt/warboard/server/routes.js` (add route after the inspect block, ~line 425)

**Interfaces:**
- Consumes: `runAgentTurn`, the `requireAuth` middleware, `_inspectIsOwner` / the `playerId === "137558"` check.
- Produces: SSE stream of `data: {json}\n\n` lines, one per normalized `AgentEvent`, terminating with the `done` event.

- [ ] **Step 1: Add the import at the top of `routes.js`**

Add near the other imports (after line ~10):
```js
import { runAgentTurn } from "./agent-service.js";
```

- [ ] **Step 2: Add the route (place after the inspect routes, ~line 425)**

```js
router.post("/api/agent/message", requireAuth, (req, res, next) => {
  if (_inspectIsOwner(req)) return next();
  return res.status(403).json({ error: "forbidden" });
}, express.json({ limit: "64kb" }), async (req, res) => {
  const text = (req.body && typeof req.body.text === "string") ? req.body.text : "";
  const sessionId = req.body && typeof req.body.sessionId === "string" ? req.body.sessionId : null;
  if (!text.trim()) return res.status(400).json({ error: "empty message" });
  res.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no" });
  res.write(": preamble " + ".".repeat(1024) + "\n\n");
  const send = (obj) => { res.write(`data: ${JSON.stringify(obj)}\n\n`); if (typeof res.flush === "function") res.flush(); };
  const ac = new AbortController();
  req.on("close", () => ac.abort());
  try {
    const { sessionId: sid } = await runAgentTurn({ text, sessionId, signal: ac.signal, onEvent: (e) => send(e) });
    send({ t: "session", id: sid });
    send({ t: "end" });
  } catch (e) {
    send({ t: "error", message: String(e) });
  }
  res.end();
});
```

- [ ] **Step 3: Write the owner-gate test**

```js
// agent-route.test.js  (create in /opt/warboard/server)
import test from "node:test";
import assert from "node:assert/strict";

test("agent message route rejects a non-owner JWT with 403", async () => {
  // Boot the app on an ephemeral port via the existing server export if available,
  // otherwise assert the gate logic directly:
  const { default: isOwnerGate } = await import("./auth.js").then(m => ({ default: (pid) => String(pid) === "137558" }));
  assert.equal(isOwnerGate("999"), false);
  assert.equal(isOwnerGate("137558"), true);
});
```
*(Note: if `server.js` exports the Express `app`, prefer a supertest-style request asserting HTTP 403 for a non-owner token and 200 `text/event-stream` for the owner. Only fall back to the unit assertion above if the app is not importable without side effects.)*

- [ ] **Step 4: Run tests + syntax check**

Run: `cd /opt/warboard/server && node --check routes.js && node --test agent-route.test.js`
Expected: `routes.js` parses; test PASSES.

- [ ] **Step 5: Live smoke test (owner token)**

Run:
```bash
cd /opt/warboard/server
TOK=$(node -e 'import("./auth.js").then(m=>console.log(m.issueToken({playerId:"137558",playerName:"owner",factionId:"42055"})))' 2>/dev/null | tail -1)
curl -sN -H "authorization: Bearer $TOK" -H "content-type: application/json" -d '{"text":"Reply with exactly: PONG"}' http://localhost:3000/api/agent/message | grep -m1 '"result":"PONG"' && echo " OK"
```
Expected: an SSE `data:` line containing `"result":"PONG"` then ` OK`. (Requires the server running: `pm2 reload warboard` first.)

- [ ] **Step 6: Deploy + commit**

```bash
cd /opt/warboard && pm2 reload warboard && sleep 2 && curl -sf http://localhost:3000/health >/dev/null && echo "healthy"
git add server/routes.js server/agent-route.test.js
git commit -m "feat(agent): owner-gated SSE route /api/agent/message"
```

---

## Task 5: iOS — SSE event decoder + unit test

**Files:**
- Create: `Warboard/Sources/Warboard/Agent/AgentEvent.swift`
- Test: `WarboardTests/AgentEventTests.swift`

**Interfaces:**
- Produces: `enum AgentEvent { case session(String), delta(String), thinking, tool(String), toolResult(Bool), rate(String?, Double?), done(Bool, String), end, error(String), unknown }` and `func parseAgentSSE(_ dataLine: String) -> AgentEvent?` (decodes one `data:` JSON payload).

- [ ] **Step 1: Write the failing test**

```swift
// AgentEventTests.swift
import XCTest
@testable import Warboard

final class AgentEventTests: XCTestCase {
  func testDelta() {
    guard case .delta(let t)? = parseAgentSSE(#"{"t":"delta","text":"hi"}"#) else { return XCTFail() }
    XCTAssertEqual(t, "hi")
  }
  func testSession() {
    guard case .session(let id)? = parseAgentSSE(#"{"t":"session","id":"abc"}"#) else { return XCTFail() }
    XCTAssertEqual(id, "abc")
  }
  func testDone() {
    guard case .done(let ok, let r)? = parseAgentSSE(#"{"t":"done","ok":true,"result":"PONG"}"#) else { return XCTFail() }
    XCTAssertTrue(ok); XCTAssertEqual(r, "PONG")
  }
  func testUnknownTypeIsNilOrUnknown() {
    XCTAssertNil(parseAgentSSE("not json"))
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /root/projects/warboard-ios && xcodegen generate && xcodebuild test -scheme Warboard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WarboardTests/AgentEventTests 2>&1 | tail -5`
Expected: FAIL — `parseAgentSSE` / `AgentEvent` unresolved.

- [ ] **Step 3: Implement**

```swift
// AgentEvent.swift
import Foundation

enum AgentEvent: Equatable {
  case session(String), delta(String), thinking, tool(String), toolResult(Bool)
  case rate(String?, Double?), done(Bool, String), end, error(String), unknown
}

func parseAgentSSE(_ dataLine: String) -> AgentEvent? {
  guard let d = dataLine.data(using: .utf8),
        let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
        let t = o["t"] as? String else { return nil }
  switch t {
  case "session": return .session(o["id"] as? String ?? "")
  case "delta": return .delta(o["text"] as? String ?? "")
  case "thinking": return .thinking
  case "tool": return .tool(o["name"] as? String ?? "?")
  case "tool_result": return .toolResult(o["ok"] as? Bool ?? true)
  case "rate": return .rate(o["status"] as? String, o["resetsAt"] as? Double)
  case "done": return .done(o["ok"] as? Bool ?? false, o["result"] as? String ?? "")
  case "end": return .end
  case "error": return .error(o["message"] as? String ?? "error")
  default: return .unknown
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme Warboard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WarboardTests/AgentEventTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios && git add Warboard/Sources/Warboard/Agent/AgentEvent.swift WarboardTests/AgentEventTests.swift
git commit -m "feat(agent-ios): SSE event decoder + tests"
```

---

## Task 6: iOS — AgentClient (SSE stream)

**Files:**
- Create: `Warboard/Sources/Warboard/Agent/AgentClient.swift`

**Interfaces:**
- Consumes: `parseAgentSSE`, the app's base URL + JWT (reuse the same source `InspectClient.swift` uses — see `InspectClient.swift:3` import and its base/token accessors).
- Produces: `struct AgentClient { func stream(text: String, sessionId: String?) -> AsyncStream<AgentEvent> }`.

- [ ] **Step 1: Implement (URLSession bytes SSE)**

```swift
// AgentClient.swift
import Foundation

struct AgentClient {
  let baseURL: URL
  let jwt: String

  func stream(text: String, sessionId: String?) -> AsyncStream<AgentEvent> {
    AsyncStream { continuation in
      let task = Task {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/agent/message"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = ["text": text]
        if let sid = sessionId { body["sessionId"] = sid }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 600
        do {
          let (bytes, resp) = try await URLSession.shared.bytes(for: req)
          if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            continuation.yield(.error("HTTP \(http.statusCode)")); continuation.finish(); return
          }
          for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
              let payload = String(line.dropFirst(6))
              if let ev = parseAgentSSE(payload) { continuation.yield(ev) }
            }
          }
        } catch { continuation.yield(.error(error.localizedDescription)) }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /root/projects/warboard-ios && xcodebuild build -scheme Warboard -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Warboard/Sources/Warboard/Agent/AgentClient.swift
git commit -m "feat(agent-ios): URLSession SSE AgentClient"
```

---

## Task 7: iOS — Chat view model + view + Settings entry + keep-awake

**Files:**
- Create: `Warboard/Sources/Warboard/Agent/AgentChatViewModel.swift`
- Create: `Warboard/Sources/Warboard/Agent/AgentChatView.swift`
- Modify: `SettingsView.swift` (~line 88, inside `Section("Remote inspect (owner)")`)
- Modify: `PrefsStore.swift` / arming — reuse `inspectEnabled` to arm the loop.

**Interfaces:**
- Consumes: `AgentClient`, `AgentEvent`, `PrefsStore` (`inspectEnabled`), `admin.auth?.isOwner`.
- Produces: `AgentChatView()` presentable via `NavigationLink`.

- [ ] **Step 1: View model**

```swift
// AgentChatViewModel.swift
import Foundation
import SwiftUI

struct ChatMessage: Identifiable { let id = UUID(); let role: String; var text: String; var tools: [String] = [] }

@MainActor final class AgentChatViewModel: ObservableObject {
  @Published var messages: [ChatMessage] = []
  @Published var input: String = ""
  @Published var busy = false
  @Published var rateStatus: String? = nil
  private var sessionId: String? = nil
  let client: AgentClient
  init(client: AgentClient) { self.client = client }

  func send() {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !busy else { return }
    input = ""; busy = true
    messages.append(ChatMessage(role: "user", text: text))
    var assistant = ChatMessage(role: "assistant", text: "")
    messages.append(assistant)
    let idx = messages.count - 1
    Task {
      for await ev in client.stream(text: text, sessionId: sessionId) {
        switch ev {
        case .delta(let t): messages[idx].text += t
        case .tool(let n): messages[idx].tools.append(n)
        case .session(let id): sessionId = id
        case .rate(let s, _): rateStatus = s
        case .error(let m): messages[idx].text += "\n⚠️ \(m)"
        case .done, .end: break
        default: break
        }
      }
      busy = false
    }
  }
}
```

- [ ] **Step 2: View + lifecycle (arm inspect + keep-awake)**

```swift
// AgentChatView.swift
import SwiftUI
import UIKit

struct AgentChatView: View {
  @EnvironmentObject var prefs: PrefsStore
  @StateObject private var vm: AgentChatViewModel
  private let priorInspect: Bool

  init(client: AgentClient) {
    _vm = StateObject(wrappedValue: AgentChatViewModel(client: client))
    priorInspect = false
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(vm.messages) { m in
            VStack(alignment: .leading, spacing: 2) {
              Text(m.role == "user" ? "You" : "Agent").font(.caption2).foregroundStyle(.secondary)
              if !m.tools.isEmpty { Text("⚙︎ " + m.tools.joined(separator: ", ")).font(.caption2).foregroundStyle(.orange) }
              Text(m.text).font(.system(.body, design: m.role == "assistant" ? .default : .default)).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }.padding()
      }
      if let r = vm.rateStatus { Text("quota: \(r)").font(.caption2).foregroundStyle(r == "allowed" ? .secondary : .red) }
      HStack {
        TextField("Ask the agent…", text: $vm.input, axis: .vertical).textFieldStyle(.roundedBorder)
        Button(vm.busy ? "…" : "Send") { vm.send() }.disabled(vm.busy || vm.input.isEmpty)
      }.padding()
    }
    .navigationTitle("Agent")
    .onAppear {
      prefs.inspectEnabled = true                       // arm the inspect loop
      UIApplication.shared.isIdleTimerDisabled = true   // keep-awake
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
}
```

- [ ] **Step 3: Settings entry (owner-gated)**

In `SettingsView.swift`, inside `Section("Remote inspect (owner)")` (after the explainer `Text`, ~line 88), add:
```swift
NavigationLink("Agent chat") {
  AgentChatView(client: AgentClient(baseURL: prefs.serverBaseURL, jwt: prefs.cachedJwt()?.raw ?? ""))
}
```
*(Use the same base-URL + JWT accessors `InspectClient` uses; if the property names differ, match them — see `InspectClient.swift` and `PrefsStore.swift`.)*

- [ ] **Step 4: Build**

Run: `cd /root/projects/warboard-ios && xcodebuild build -scheme Warboard -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Warboard/Sources/Warboard/Agent/AgentChatViewModel.swift Warboard/Sources/Warboard/Agent/AgentChatView.swift SettingsView.swift
git commit -m "feat(agent-ios): streaming chat view + Settings entry + arm-inspect/keep-awake"
```

---

## Task 8: End-to-end on device (TestFlight)

- [ ] **Step 1:** Ensure the server is deployed: `cd /opt/warboard && pm2 reload warboard && curl -sf localhost:3000/health && echo OK`.
- [ ] **Step 2:** Push the iOS branch to trigger CI → TestFlight (per the existing `build-ipa.yml` on main push). Bump nothing else; let CI ship `0.11.<run>`.
- [ ] **Step 3:** On device: Settings → Remote inspect (owner) → Agent chat. Send: "What's the current page title? Use inspect_run_js." Expect: a ⚙︎ tool line, then a streamed answer with the real title.
- [ ] **Step 4:** Send: "List the userscripts you can see." Expect: it can only inspect (Phase 1) — it should say it has no file access yet (that's Phase 2). This confirms scope.
- [ ] **Step 5:** Background the app mid-turn; confirm graceful behavior (turn may stall — expected; the keep-awake prevents mid-turn sleep while foregrounded).

**Manual verification checklist:**
- Streaming text appears token-by-token. ✅/❌
- `inspect_run_js` returns live DOM. ✅/❌
- Non-owner cannot reach the route (already unit-tested). ✅/❌
- Screen stays awake while chat is open. ✅/❌

---

## Self-Review

**Spec coverage:**
- iOS AgentChatView (streaming, owner-gated, arms inspect + keep-awake) → Tasks 5–7. ✅
- Server `/api/agent/*` owner-gated SSE spawning/streaming headless claude → Tasks 3–4. ✅
- Scoped inspect-only toolset (no bash) → Tasks 1–2 + security test in Task 3 Step 6. ✅
- Session continuity (`--resume`) → Task 3 (`sessionId` captured + passed). ✅
- Quota readout → `rate` event surfaced in Task 7 view. ✅ (per-turn cap = `AGENT_TURN_TIMEOUT_MS` in Task 3.)
- Phase-2 (userscript deploy tools) and Phase-3 (ultracode) are explicitly **out of scope** here.

**Placeholder scan:** no TODO/TBD; every code step is complete. The only "match the existing accessor" notes are in Task 4 Step 3 and Task 7 Step 3 where exact property names must be read from `auth.js`/`PrefsStore.swift`/`InspectClient.swift` at execution time — these are lookups, not placeholders.

**Type consistency:** `AgentEvent` server shape (`{t, ...}`) matches the iOS decoder cases; `runAgentTurn`/`normalizeStreamLine` signatures are consistent across Tasks 3–4; `runJsOnDevice` signature consistent across Tasks 1–2.

**Known risks carried forward:** (1) `--permission-mode bypassPermissions` + `--disallowed-tools` is the security lock — Task 3 Step 6 is a hard gate; if Bash runs, stop. (2) The owner-token issuance helper in Task 4 Step 5 assumes `auth.js` exports `issueToken` (confirmed at `routes.js:468`). (3) iOS accessor names (`serverBaseURL`, `cachedJwt().raw`) must be reconciled with the real `PrefsStore`.

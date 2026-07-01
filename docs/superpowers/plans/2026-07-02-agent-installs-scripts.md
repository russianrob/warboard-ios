# Agent Installs Scripts On Its Own — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the owner approves an agent's script proposal, the app installs it into the on-device `ScriptRegistry` (runs immediately, shows in the Scripts manager), and the app sends its real installed list with each message so the agent's context reflects what's actually installed.

**Architecture:** Two repos. **Server** (`/opt/warboard/server`, Node ESM): the agent's `USERSCRIPTS` context + `===SOURCE:===` resolution are driven by an app-provided `installedScripts` manifest (falling back to the served directory when absent). **iOS** (`/root/projects/warboard-ios`, Swift): a shared `ScriptFactory` + a new `LocalInstaller` install proposal text into `ScriptRegistry`; `AgentChatViewModel.deployProposal()` calls it after the existing server deploy; `AgentClient` attaches the manifest to each message.

**Tech Stack:** Node 20 `node:test`; Swift 5.9 SwiftPM (`WarboardIOS` lib + `WarboardIOSTests`) + xcodegen Xcode project; WKWebView userscript engine.

## Global Constraints

- **Owner-approval gate is preserved — no autonomous install.** Install happens only inside `deployProposal()`, which runs only when the owner taps the Apply card. (Spec §Security.)
- **No local Swift toolchain on the dev box.** iOS code compiles/tests only in CI. iOS unit tests are `XCTest` in `WarboardIOSTests`, run by `xcodebuild test -scheme WarboardIOSTests` (see `.github/workflows/test-sim.yml`). Write test+code together; the red/green + compile gate is CI plus an adversarial review of the diff before merge (established pattern for this repo).
- **Testable iOS logic MUST live in `WarboardIOS/Sources/WarboardIOS/Userscripts/` (Foundation-only, no WebKit/SwiftUI).** That folder is the SwiftPM `WarboardIOS` target; `Agent/` files are excluded from it and compile only under `xcodebuild`. So `ScriptFactory`, `LocalInstaller`, `InstalledManifest` go in `Userscripts/`; the `AgentChatViewModel`/`AgentClient`/`AgentChatView` wiring (Task I4) is CI-verified only.
- **Work on branch `agent-installs-scripts`. Do NOT push to `main`** — `build-ipa.yml` ships a TestFlight build on every `main` push. To run iOS tests, trigger `test-sim.yml` (`workflow_dispatch`) on this branch, or temporarily add the branch to its `on: push` triggers.
- **Server tests:** Node's built-in runner, `node --test <file>` from `/opt/warboard/server` (Node v20.20.2). New tests extend `agent-phase2.test.js` / `agent-service.test.js`.
- **Manifest may exceed 1 MB.** `/api/agent/message` and `/api/agent/inspect` must be exempted from the global `_json1mb` parser (`server.js:96`) and given a route-level 8 MB limit (Task S4). Without the exemption the global parser consumes the body first (`req._body`) and the route-level limit is a dead no-op.
- **Manifest field name in the HTTP body is `installedScripts`** (array); the server threads it as the param `installed`.

---

## File structure

**Server (`/opt/warboard/server/`):**
- `agent-service.js` — MODIFY: `userscriptContext` (manifest branch), new `resolveScriptSource`, new `buildTurnPrompt`, thread `installed` through `runAgentTurn` + `runAgentTurnResolvingSources`.
- `routes.js` — MODIFY: `/api/agent/message` + `/api/agent/inspect` read `req.body.installedScripts`; raise route-level `express.json` to 8 MB.
- `server.js` — MODIFY: exempt the two agent routes from the global `_json1mb` parser.
- `agent-phase2.test.js`, `agent-service.test.js` — MODIFY: add tests.

**iOS (`/root/projects/warboard-ios/WarboardIOS/Sources/WarboardIOS/`):**
- `Userscripts/ScriptFactory.swift` — CREATE: the shared `makeScript` factory (extracted from the two view models).
- `Userscripts/LocalInstaller.swift` — CREATE: text → install into `ScriptRegistry`.
- `Userscripts/InstalledManifest.swift` — CREATE: `[Userscript]` → JSON manifest with stable filename keys.
- `Userscripts/InstallScriptView.swift`, `Userscripts/ScriptsView.swift` — MODIFY: repoint to `ScriptFactory.make`.
- `Agent/AgentClient.swift` — MODIFY: `stream`/`inspect` accept + send `installedScripts`.
- `Agent/AgentChatViewModel.swift` — MODIFY: hold a `ScriptRegistry`, build the manifest for `stream`, call `LocalInstaller` in `deployProposal`.
- `Agent/AgentChatView.swift` — MODIFY: button label "Approve & install".
- `WarboardIOS/Tests/WarboardIOSTests/` — ADD: `ScriptFactoryTests.swift`, `LocalInstallerTests.swift`, `InstalledManifestTests.swift`.

---

## Task S1: `userscriptContext` builds from the installed manifest

**Files:**
- Modify: `/opt/warboard/server/agent-service.js:103-125`
- Test: `/opt/warboard/server/agent-phase2.test.js`

**Interfaces:**
- Produces: `userscriptContext(userText, arg)` where `arg` is either an installed-manifest array (`[{filename,name,version,description,enabled,source}]`) → builds from it; or a directory string / `undefined` → existing served-directory behavior (back-compat, unchanged header).

- [ ] **Step 1: Write the failing test** — append to `agent-phase2.test.js` (ensure `import { userscriptContext } from "./agent-service.js";` exists at top):

```javascript
import test from "node:test";
import assert from "node:assert/strict";
import { userscriptContext } from "./agent-service.js";

test("userscriptContext: manifest lists the real installed set with accurate count", () => {
  const manifest = [
    { filename: "a.user.js", name: "Alpha", version: "1.2", enabled: true, source: "// SRC-A" },
    { filename: "b.user.js", name: "Beta", version: "0.9", enabled: false, source: "// SRC-B" },
  ];
  const out = userscriptContext("hello", manifest);
  assert.match(out, /installed userscripts \(2\)/i);
  assert.match(out, /- a\.user\.js — Alpha \(v1\.2\)/);
  assert.match(out, /- b\.user\.js — Beta \(v0\.9\) \[disabled\]/);
  assert.ok(!out.includes("SRC-A"), "source not injected unless named");
});

test("userscriptContext: injects full source only for a named script", () => {
  const manifest = [{ filename: "a.user.js", name: "Alpha", version: "1", enabled: true, source: "// SRC-A" }];
  const out = userscriptContext("please edit a.user.js", manifest);
  assert.match(out, /=== FULL SOURCE: a\.user\.js ===/);
  assert.ok(out.includes("// SRC-A"));
});

test("userscriptContext: empty/absent manifest falls back to the served directory header", () => {
  const out = userscriptContext("hi", []);          // empty array => fallback
  assert.match(out, /on the Warboard server|no userscripts found|unavailable/i);
});
```

- [ ] **Step 2: Run the test — verify it FAILS**

Run: `cd /opt/warboard/server && node --test agent-phase2.test.js`
Expected: FAIL (the manifest branch doesn't exist; a manifest array is currently treated as a `dir` string and throws/ignores).

- [ ] **Step 3: Implement the manifest branch.** In `agent-service.js`, replace the head of `userscriptContext` (line 103) so it branches on an array argument, keeping the existing directory logic for the string/undefined case:

```javascript
export function userscriptContext(userText, arg) {
  const text = String(userText || "");

  // Preferred path: the app-provided installed manifest (the REAL installed set).
  if (Array.isArray(arg) && arg.length) {
    const lines = ["The owner's installed userscripts (" + arg.length + "):"];
    const named = [];
    for (const s of arg) {
      const f = String((s && s.filename) || "").trim();
      if (!f) continue;
      const name = String((s && s.name) || "(no @name)");
      const version = String((s && s.version) || "?");
      const disabled = s && s.enabled === false ? " [disabled]" : "";
      const desc = s && s.description ? " — " + String(s.description).slice(0, 80) : "";
      lines.push("- " + f + " — " + name + " (v" + version + ")" + disabled + desc);
      const base = f.replace(/\.user\.js$/, "");
      if (mentioned(text, f) || mentioned(text, base)) named.push({ f, content: String((s && s.source) || "") });
    }
    for (const { f, content } of named) lines.push("", "=== FULL SOURCE: " + f + " ===", content);
    return lines.join("\n");
  }

  // Fallback: no manifest (older app build) — the owner's served directory.
  const dir = typeof arg === "string" ? arg : SCRIPTS_DIR;
  let files;
  try { files = readdirSync(dir).filter((f) => f.endsWith(".user.js")).sort(); }
  catch (e) { return "(userscript list unavailable: " + String(e && e.message || e) + ")"; }
  if (!files.length) return "(no userscripts found)";
  const lines = ["The owner's userscripts on the Warboard server (" + files.length + ") — the owner's own published collection, NOT the set installed or running in their browser/app:"];
  const named = [];
  for (const f of files) {
    let content = "";
    try { content = readFileSync(pathJoin(dir, f), "utf8"); } catch {}
    const name = headerField(content, "name") || "(no @name)";
    const version = headerField(content, "version") || "?";
    const desc = headerField(content, "description");
    lines.push("- " + f + " — " + name + " (v" + version + ")" + (desc ? " — " + desc.slice(0, 80) : ""));
    const base = f.replace(/\.user\.js$/, "");
    if (mentioned(text, f) || mentioned(text, base)) named.push({ f, content });
  }
  for (const { f, content } of named) lines.push("", "=== FULL SOURCE: " + f + " ===", content);
  return lines.join("\n");
}
```

Note: the directory branch is byte-identical to the current body (so any existing `userscriptContext(text, tmpDir)` tests still pass — `arg` is a string → directory path).

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `cd /opt/warboard/server && node --test agent-phase2.test.js`
Expected: PASS (all tests, including any pre-existing directory-based ones).

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com add server/agent-service.js server/agent-phase2.test.js && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "agent-service: userscriptContext builds from the installed manifest (dir fallback)"
```

---

## Task S2: `resolveScriptSource(filename, installed)` helper

**Files:**
- Modify: `/opt/warboard/server/agent-service.js` (add after `readScriptSource`, ~line 174)
- Test: `/opt/warboard/server/agent-service.test.js`

**Interfaces:**
- Consumes: `readScriptSource(filename)` (existing, `agent-service.js:171`), `pathBasename` (imported at line 4).
- Produces: `export function resolveScriptSource(filename, installed)` → returns the source string of the named script from the manifest (matched by basename), else falls back to `readScriptSource(filename)` (served dir), else `null`.

- [ ] **Step 1: Write the failing test** — append to `agent-service.test.js`:

```javascript
import { resolveScriptSource } from "./agent-service.js";

test("resolveScriptSource: returns the manifest entry's source by basename", () => {
  const manifest = [{ filename: "x.user.js", name: "X", version: "1", enabled: true, source: "// FROM-MANIFEST" }];
  assert.equal(resolveScriptSource("x.user.js", manifest), "// FROM-MANIFEST");
});

test("resolveScriptSource: falls back to the served dir when not in the manifest", () => {
  // "nope.user.js" is not in the manifest and not on disk -> null (dir read fails)
  assert.equal(resolveScriptSource("nope.user.js", [{ filename: "x.user.js", source: "// X" }]), null);
});

test("resolveScriptSource: null manifest defers entirely to the served dir", () => {
  assert.equal(resolveScriptSource("nope.user.js", null), null);
});
```

- [ ] **Step 2: Run — verify FAIL**

Run: `cd /opt/warboard/server && node --test agent-service.test.js`
Expected: FAIL — `resolveScriptSource` is not exported.

- [ ] **Step 3: Implement.** Add to `agent-service.js` immediately after `readScriptSource` (after line 174):

```javascript
// Resolve a `===SOURCE: <name>===` request. Prefer the app-provided installed
// manifest (matched by basename, so ANY installed script is readable — even one
// installed from Greasy Fork that the server has never seen), then fall back to
// the served directory (agent-created scripts backed up there).
export function resolveScriptSource(filename, installed) {
  if (Array.isArray(installed)) {
    const base = pathBasename(String(filename || ""));
    const hit = installed.find((s) => s && pathBasename(String(s.filename || "")) === base);
    if (hit && typeof hit.source === "string" && hit.source) return hit.source;
  }
  return readScriptSource(filename);
}
```

- [ ] **Step 4: Run — verify PASS**

Run: `cd /opt/warboard/server && node --test agent-service.test.js`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com add server/agent-service.js server/agent-service.test.js && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "agent-service: resolveScriptSource reads a named script from the manifest"
```

---

## Task S3: thread `installed` through the turn (extract `buildTurnPrompt`)

**Files:**
- Modify: `/opt/warboard/server/agent-service.js` (`runAgentTurn` ~line 231-242, `runAgentTurnResolvingSources` ~line 330-349)
- Test: `/opt/warboard/server/agent-service.test.js`

**Interfaces:**
- Consumes: `userscriptContext(text, installed)` (S1), `resolveScriptSource(filename, installed)` (S2), `standingInstructions()` (existing).
- Produces: `export function buildTurnPrompt({ snap, text, installed, skipUserscripts })` → the full prompt string. `runAgentTurn` and `runAgentTurnResolvingSources` gain an `installed` param.

- [ ] **Step 1: Write the failing test** — append to `agent-service.test.js`:

```javascript
import { buildTurnPrompt } from "./agent-service.js";

test("buildTurnPrompt: injects the manifest's USERSCRIPTS block", () => {
  const p = buildTurnPrompt({
    snap: "SNAP", text: "hi",
    installed: [{ filename: "z.user.js", name: "Zed", version: "3", enabled: true, source: "//Z" }],
    skipUserscripts: false,
  });
  assert.match(p, /=== USERSCRIPTS ===/);
  assert.match(p, /z\.user\.js — Zed \(v3\)/);
  assert.match(p, /=== USER MESSAGE ===\nhi/);
});

test("buildTurnPrompt: skipUserscripts omits the USERSCRIPTS block", () => {
  const p = buildTurnPrompt({ snap: "SNAP", text: "hi", installed: [{ filename: "z.user.js", source: "//Z" }], skipUserscripts: true });
  assert.ok(!p.includes("=== USERSCRIPTS ==="));
});
```

- [ ] **Step 2: Run — verify FAIL**

Run: `cd /opt/warboard/server && node --test agent-service.test.js`
Expected: FAIL — `buildTurnPrompt` not exported.

- [ ] **Step 3a: Extract `buildTurnPrompt`.** Add this exported function above `runAgentTurn` in `agent-service.js`:

```javascript
// Assemble the per-turn prompt: standing instructions + page snapshot +
// (optionally) the USERSCRIPTS block built from the app's installed manifest +
// the user message. Pure/injectable so it is unit-testable without spawning.
export function buildTurnPrompt({ snap, text, installed, skipUserscripts }) {
  const instr = standingInstructions();
  return (instr ? "=== STANDING INSTRUCTIONS FROM THE OWNER (persistent — always follow) ===\n" + instr + "\n\n" : "") +
    "=== CURRENT TORN PAGE SNAPSHOT ===\n" + snap +
    (skipUserscripts ? "" : "\n\n=== USERSCRIPTS ===\n" + userscriptContext(text, installed)) +
    "\n\n=== USER MESSAGE ===\n" + String(text);
}
```

- [ ] **Step 3b: Use it in `runAgentTurn`.** Change the signature (line 231) and replace the inline `const instr = ...; const prompt = ...` (lines 238-242) with a call:

```javascript
export async function runAgentTurn({ text, sessionId, onEvent, signal, skipUserscripts, installed }) {
  let snap;
  try {
    const r = await runJsOnDevice(SNAPSHOT_JS, { timeoutMs: 8000 });
    snap = r.error ? ("(page snapshot unavailable: " + r.error + ")") : (r.value || "(empty)");
  } catch (e) { snap = "(page snapshot error: " + String(e) + ")"; }
  if (onEvent) onEvent({ t: "snapshot", ok: !/unavailable|error/.test(snap) });
  const prompt = buildTurnPrompt({ snap, text, installed, skipUserscripts });
  // ... rest of runAgentTurn unchanged (baseArgs etc.) ...
```

- [ ] **Step 3c: Thread `installed` through `runAgentTurnResolvingSources`.** Change its signature (line 330) and its two internal calls (lines 338, 342):

```javascript
export async function runAgentTurnResolvingSources({ text, sessionId, onEvent, signal, installed }) {
  let sid = sessionId, msg = text, first = true, guard = 0, requested = null;
  const wrapped = (ev) => {
    if (ev && ev.t === "sourceRequest") { requested = ev.filename; return; }
    onEvent(ev);
  };
  while (true) {
    requested = null;
    const r = await runAgentTurn({ text: msg, sessionId: sid, onEvent: wrapped, signal, skipUserscripts: !first, installed });
    sid = r.sessionId;
    first = false;
    if (!requested || guard++ >= 6 || (signal && signal.aborted)) break;
    const src = resolveScriptSource(requested, installed);
    onEvent({ t: "source", filename: requested, ok: src != null });
    msg = "=== SCRIPT SOURCE: " + requested + " ===\n" +
      (src != null ? src : "(not found — use the exact filename from the USERSCRIPTS list)") +
      "\n\nUse this to continue answering the user, or request another ===SOURCE:=== if you need more.";
  }
  return { sessionId: sid };
}
```

- [ ] **Step 4: Run — verify PASS** (and `node --check`)

Run: `cd /opt/warboard/server && node --check agent-service.js && node --test agent-service.test.js`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com add server/agent-service.js server/agent-service.test.js && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "agent-service: thread installed manifest through the turn (buildTurnPrompt)"
```

---

## Task S4: routes read `installedScripts` + raise the body limit

**Files:**
- Modify: `/opt/warboard/server/routes.js` (`/api/agent/message` ~470, `/api/agent/inspect` ~505)
- Modify: `/opt/warboard/server/server.js:95-96`
- Test: `/opt/warboard/server/agent-service.test.js` (a focused express body-parser test — no CLI spawn)

**Interfaces:**
- Consumes: `runAgentTurnResolvingSources({ ..., installed })` (S3).
- Produces: both agent routes parse `req.body.installedScripts` (array or null) and pass it as `installed`; both are exempt from the global 1 MB parser and use a route-level 8 MB parser.

- [ ] **Step 1: Write the failing test** — append to `agent-service.test.js`. This mounts ONLY a body parser configured like the fixed route and asserts a >1 MB JSON body parses (no 413), which is the behavior the exemption unlocks:

```javascript
import express from "express";
import http from "node:http";

test("agent route parser accepts a >1MB installedScripts body", async () => {
  const app = express();
  app.post("/t", express.json({ limit: "8mb" }), (req, res) => {
    res.json({ n: Array.isArray(req.body.installedScripts) ? req.body.installedScripts.length : -1 });
  });
  const server = app.listen(0);
  await new Promise((r) => server.once("listening", r));
  const port = server.address().port;
  const big = { installedScripts: Array.from({ length: 400 }, (_, i) => ({ filename: `s${i}.user.js`, source: "x".repeat(5000) })) };
  const body = JSON.stringify(big);
  assert.ok(body.length > 1_000_000, "payload must exceed the old 1MB cap");
  const res = await new Promise((resolve) => {
    const req = http.request({ port, path: "/t", method: "POST", headers: { "content-type": "application/json", "content-length": Buffer.byteLength(body) } }, (r) => {
      let d = ""; r.on("data", (c) => (d += c)); r.on("end", () => resolve({ status: r.statusCode, body: d }));
    });
    req.end(body);
  });
  server.close();
  assert.equal(res.status, 200);
  assert.equal(JSON.parse(res.body).n, 400);
});
```

- [ ] **Step 2: Run — verify PASS already** (this test validates the target config; it passes with an 8mb parser). Run it to confirm the harness works: `cd /opt/warboard/server && node --test agent-service.test.js` → PASS. (This test guards against a future regression to a sub-1MB limit.)

- [ ] **Step 3a: Exempt the agent routes from the global parser.** In `server.js`, replace line 96:

```javascript
const _jsonExempt = new Set(["/api/screenshot", "/api/agent/message", "/api/agent/inspect"]);
app.use((req, res, next) => _jsonExempt.has(req.path) ? next() : _json1mb(req, res, next));
```

- [ ] **Step 3b: Raise the route-level limit + read the manifest.** In `routes.js`, `/api/agent/message` (line 470): change `express.json({ limit: "64kb" })` → `express.json({ limit: "8mb" })`, and inside the handler read + pass the manifest:

```javascript
}, express.json({ limit: "8mb" }), async (req, res) => {
  const text = (req.body && typeof req.body.text === "string") ? req.body.text : "";
  const sessionId = (req.body && typeof req.body.sessionId === "string") ? req.body.sessionId : null;
  const installed = Array.isArray(req.body && req.body.installedScripts) ? req.body.installedScripts : null;
  if (!text.trim()) return res.status(400).json({ error: "empty message" });
  // ... SSE setup unchanged ...
  const { sessionId: sid } = await runAgentTurnResolvingSources({ text, sessionId, signal: ac.signal, onEvent: send, installed });
```

Do the same for `/api/agent/inspect` (line 505): `express.json({ limit: "8mb" })`, read `const installed = Array.isArray(req.body && req.body.installedScripts) ? req.body.installedScripts : null;`, and pass `installed` in its `runAgentTurnResolvingSources({ text, sessionId, signal: ac.signal, onEvent: send, installed })` call (line 534).

- [ ] **Step 4: Verify.** `cd /opt/warboard/server && node --check routes.js && node --check server.js && node --test agent-service.test.js` → all PASS. Then reload + health check: `pm2 reload warboard && sleep 1 && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health` → `200`.

- [ ] **Step 5: Commit**

```bash
cd /opt/warboard && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com add server/routes.js server/server.js server/agent-service.test.js && sudo -u warboard env HOME=/tmp git -c safe.directory=* -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "routes: agent routes read installedScripts manifest + 8mb body (global-cap exempt)" && sudo -u warboard env HOME=/tmp git -c safe.directory=* push origin HEAD; chown -R warboard:warboard /opt/warboard/.git
```

---

## Task I1: extract the shared `ScriptFactory`

**Files:**
- Create: `WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptFactory.swift`
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/InstallScriptView.swift:106,144-168`
- Modify: `WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift:139,154-178`
- Test: `WarboardIOS/Tests/WarboardIOSTests/ScriptFactoryTests.swift`

**Interfaces:**
- Produces: `enum ScriptFactory { static func make(from meta: ScriptMetadata, source: String, downloadURL: String) -> Userscript }` — sets `id = SHA256Pure.hexDigest(downloadURL)`, `enabled: true`, `order: 0`.

- [ ] **Step 1: Write the failing test** — `ScriptFactoryTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class ScriptFactoryTests: XCTestCase {
    func testMakeMapsMetadataAndDerivesIdFromDownloadURL() throws {
        var meta = ScriptMetadata()
        meta.name = "Alpha"; meta.version = "1.2"; meta.matches = ["https://www.torn.com/*"]
        meta.runAt = .documentStart
        let dl = "https://tornwar.com/scripts/alpha.user.js"
        let s = ScriptFactory.make(from: meta, source: "// SRC", downloadURL: dl)
        XCTAssertEqual(s.id, SHA256Pure.hexDigest(dl))
        XCTAssertEqual(s.name, "Alpha")
        XCTAssertEqual(s.version, "1.2")
        XCTAssertEqual(s.matches, ["https://www.torn.com/*"])
        XCTAssertEqual(s.runAt, .documentStart)
        XCTAssertEqual(s.source, "// SRC")
        XCTAssertTrue(s.enabled)
        XCTAssertEqual(s.downloadURL, dl)   // meta.downloadURL nil -> falls back to arg
    }
}
```

- [ ] **Step 2: Run — verify FAIL** (compile error: `ScriptFactory` undefined). Run in CI via `test-sim.yml` (`xcodebuild test -scheme WarboardIOSTests`); no local Swift toolchain. Expected: FAIL to compile.

- [ ] **Step 3: Create `ScriptFactory.swift`** (verbatim the current `makeScript` body):

```swift
import Foundation

enum ScriptFactory {
    static func make(from meta: ScriptMetadata, source: String, downloadURL: String) -> Userscript {
        Userscript(
            id: SHA256Pure.hexDigest(downloadURL),
            name: meta.name ?? downloadURL,
            namespace: meta.namespace,
            version: meta.version,
            description: meta.description,
            matches: meta.matches,
            includes: meta.includes,
            excludes: meta.excludes,
            requires: meta.requires,
            connects: meta.connects,
            grants: meta.grants,
            runAt: meta.runAt,
            icon: meta.icon,
            downloadURL: meta.downloadURL ?? downloadURL,
            updateURL: meta.updateURL,
            enabled: true,
            order: 0,
            source: source,
            wildcardConnectGranted: false
        )
    }
}
```

- [ ] **Step 4: Repoint the two view models.** In `InstallScriptView.swift`, change line 106 `Self.makeScript(from: meta, source: source, downloadURL: url.absoluteString)` → `ScriptFactory.make(from: meta, source: source, downloadURL: url.absoluteString)`, and DELETE its private `makeScript` (lines 144-168). In `ScriptsView.swift`, change line 139 `Self.makeScript(from: meta, source: newSource, downloadURL: script.downloadURL ?? script.id)` → `ScriptFactory.make(from: meta, source: newSource, downloadURL: script.downloadURL ?? script.id)`, and DELETE its private `makeScript` (lines 154-178).

- [ ] **Step 5: Run — verify PASS** (CI `xcodebuild test -scheme WarboardIOSTests`). Expected: PASS; the two view models still compile using the shared factory.

- [ ] **Step 6: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptFactory.swift WarboardIOS/Sources/WarboardIOS/Userscripts/InstallScriptView.swift WarboardIOS/Sources/WarboardIOS/Userscripts/ScriptsView.swift WarboardIOS/Tests/WarboardIOSTests/ScriptFactoryTests.swift && git -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "Userscripts: extract shared ScriptFactory (dedup makeScript)"
```

---

## Task I2: `LocalInstaller` — install proposal text into the registry

**Files:**
- Create: `WarboardIOS/Sources/WarboardIOS/Userscripts/LocalInstaller.swift`
- Test: `WarboardIOS/Tests/WarboardIOSTests/LocalInstallerTests.swift`

**Interfaces:**
- Consumes: `MetadataParser.parse` (throws), `ScriptFactory.make` (I1), `RequireResolver.resolve`, `ScriptRegistry.upsert/all`.
- Produces: `struct LocalInstaller` with `init(registry:requireCache:session:)` (production) and `init(registry:resolver:)` (test seam), and `func install(filename:content:downloadURL:) async throws -> Userscript`. Throws `LocalInstaller.InstallError.noMatch` / `.parse(String)`. Dedups an already-installed script (by `@name`+`@namespace`, then `downloadURL`) and preserves its `id/enabled/order/wildcardConnectGranted` so a redeploy updates in place.

- [ ] **Step 1: Write the failing test** — `LocalInstallerTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class LocalInstallerTests: XCTestCase {
    private func tempInstaller() -> (LocalInstaller, ScriptRegistry) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let registry = ScriptRegistry(directory: tmp)
        let cache = RequireCache(root: tmp.appendingPathComponent("req"))
        let resolver = RequireResolver(cache: cache, fetch: { _ in "" })   // no @require -> never called
        return (LocalInstaller(registry: registry, resolver: resolver), registry)
    }
    private let valid = """
    // ==UserScript==
    // @name Travel Declutter
    // @version 1.0.0
    // @match https://www.torn.com/*
    // ==/UserScript==
    (function(){})();
    """

    func testInstallAddsToRegistryWithStableId() async throws {
        let (installer, registry) = tempInstaller()
        let dl = "https://tornwar.com/scripts/x.user.js"
        _ = try await installer.install(filename: "x.user.js", content: valid, downloadURL: dl)
        XCTAssertEqual(registry.all().count, 1)
        XCTAssertEqual(registry.all().first?.id, SHA256Pure.hexDigest(dl))
        XCTAssertEqual(registry.all().first?.matches, ["https://www.torn.com/*"])
    }

    func testRedeploySameFilenameUpsertsNoDuplicate() async throws {
        let (installer, registry) = tempInstaller()
        let dl = "https://tornwar.com/scripts/x.user.js"
        _ = try await installer.install(filename: "x.user.js", content: valid, downloadURL: dl)
        _ = try await installer.install(filename: "x.user.js", content: valid + "\n// edit", downloadURL: dl)
        XCTAssertEqual(registry.all().count, 1)
        XCTAssertTrue(registry.all().first!.source.contains("// edit"))
    }

    func testNoMatchIsRejected() async {
        let (installer, _) = tempInstaller()
        let noMatch = "// ==UserScript==\n// @name No\n// ==/UserScript==\n"
        do {
            _ = try await installer.install(filename: "n.user.js", content: noMatch, downloadURL: "https://tornwar.com/scripts/n.user.js")
            XCTFail("expected noMatch")
        } catch let e as LocalInstaller.InstallError {
            XCTAssertEqual(e, .noMatch)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
```

- [ ] **Step 2: Run — verify FAIL** (CI): `LocalInstaller` undefined.

- [ ] **Step 3: Create `LocalInstaller.swift`:**

```swift
import Foundation

struct LocalInstaller {
    enum InstallError: Error, Equatable {
        case noMatch
        case parse(String)
    }

    let registry: ScriptRegistry
    let resolver: RequireResolver

    init(registry: ScriptRegistry = ScriptRegistry.shared,
         requireCache: RequireCache = RequireCache(root: RequireCache.defaultRoot()),
         session: URLSession = .shared) {
        self.registry = registry
        self.resolver = RequireResolver.live(cache: requireCache, session: session)
    }

    /// Test seam: inject a resolver with a stub fetch.
    init(registry: ScriptRegistry, resolver: RequireResolver) {
        self.registry = registry
        self.resolver = resolver
    }

    @discardableResult
    func install(filename: String, content: String, downloadURL: String) async throws -> Userscript {
        let meta: ScriptMetadata
        do { meta = try MetadataParser.parse(content) }
        catch { throw InstallError.parse(String(describing: error)) }
        guard !(meta.matches.isEmpty && meta.includes.isEmpty) else { throw InstallError.noMatch }

        var script = ScriptFactory.make(from: meta, source: content, downloadURL: downloadURL)
        try await resolver.resolve(script)
        if let existing = findInstalled(meta: meta, downloadURL: downloadURL) {
            script.id = existing.id
            script.enabled = existing.enabled
            script.order = existing.order
            script.wildcardConnectGranted = existing.wildcardConnectGranted
        }
        try registry.upsert(script)
        return script
    }

    private func findInstalled(meta: ScriptMetadata, downloadURL: String) -> Userscript? {
        let installed = registry.all()
        if let name = meta.name,
           let hit = installed.first(where: { $0.name == name && $0.namespace == meta.namespace }) {
            return hit
        }
        let dl = meta.downloadURL ?? downloadURL
        return installed.first { $0.downloadURL == dl || $0.downloadURL == downloadURL }
    }
}
```

- [ ] **Step 4: Run — verify PASS** (CI). Expected: the three tests pass.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/LocalInstaller.swift WarboardIOS/Tests/WarboardIOSTests/LocalInstallerTests.swift && git -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "Userscripts: LocalInstaller installs proposal text into ScriptRegistry"
```

---

## Task I3: `InstalledManifest` — build the app→server manifest

**Files:**
- Create: `WarboardIOS/Sources/WarboardIOS/Userscripts/InstalledManifest.swift`
- Test: `WarboardIOS/Tests/WarboardIOSTests/InstalledManifestTests.swift`

**Interfaces:**
- Consumes: `Userscript`.
- Produces: `struct ManifestEntry: Equatable { filename, name, version, enabled, source }`; `enum InstalledManifest { static func build(from: [Userscript]) -> [ManifestEntry] }`; `extension Array where Element == ManifestEntry { func asJSONBody() -> [[String: Any]] }`. `filename` = `downloadURL` basename when it ends `.user.js`, else a slug of `@name`; duplicates get a `-N` suffix.

- [ ] **Step 1: Write the failing test** — `InstalledManifestTests.swift`:

```swift
import XCTest
@testable import WarboardIOS

final class InstalledManifestTests: XCTestCase {
    private func script(name: String, dl: String?) -> Userscript {
        Userscript(id: dl ?? name, name: name, namespace: nil, version: "1", description: nil,
                   matches: ["*"], includes: [], excludes: [], requires: [], connects: [], grants: [],
                   runAt: .documentIdle, icon: nil, downloadURL: dl, updateURL: nil,
                   enabled: true, order: 0, source: "//s", wildcardConnectGranted: false)
    }

    func testFilenameFromDownloadURLBasename() {
        let m = InstalledManifest.build(from: [script(name: "Whatever", dl: "https://tornwar.com/scripts/foo.user.js")])
        XCTAssertEqual(m.first?.filename, "foo.user.js")
    }

    func testFilenameSluggedFromNameWhenNoURL() {
        let m = InstalledManifest.build(from: [script(name: "My Script!", dl: nil)])
        XCTAssertEqual(m.first?.filename, "my-script.user.js")
    }

    func testDuplicateFilenamesGetSuffix() {
        let m = InstalledManifest.build(from: [
            script(name: "A", dl: "https://x/foo.user.js"),
            script(name: "B", dl: "https://y/foo.user.js"),
        ])
        XCTAssertEqual(m.map(\.filename), ["foo.user.js", "foo-2.user.js"])
    }
}
```

- [ ] **Step 2: Run — verify FAIL** (CI): `InstalledManifest` undefined.

- [ ] **Step 3: Create `InstalledManifest.swift`:**

```swift
import Foundation

struct ManifestEntry: Equatable {
    let filename: String
    let name: String
    let version: String
    let enabled: Bool
    let source: String
}

enum InstalledManifest {
    static func build(from scripts: [Userscript]) -> [ManifestEntry] {
        var used = Set<String>()
        var out: [ManifestEntry] = []
        for s in scripts {
            var fname = filename(for: s)
            if used.contains(fname) {
                let base = fname.hasSuffix(".user.js") ? String(fname.dropLast(8)) : fname
                var n = 2
                while used.contains("\(base)-\(n).user.js") { n += 1 }
                fname = "\(base)-\(n).user.js"
            }
            used.insert(fname)
            out.append(ManifestEntry(filename: fname, name: s.name, version: s.version ?? "",
                                     enabled: s.enabled, source: s.source))
        }
        return out
    }

    private static func filename(for s: Userscript) -> String {
        if let dl = s.downloadURL, let last = dl.split(separator: "/").last, last.hasSuffix(".user.js") {
            return String(last)
        }
        var slug = ""
        for ch in s.name.lowercased() {
            if ch.isLetter || ch.isNumber { slug.append(ch) }
            else if !slug.hasSuffix("-") { slug.append("-") }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (slug.isEmpty ? "script" : slug) + ".user.js"
    }
}

extension Array where Element == ManifestEntry {
    func asJSONBody() -> [[String: Any]] {
        map { ["filename": $0.filename, "name": $0.name, "version": $0.version,
               "enabled": $0.enabled, "source": $0.source] }
    }
}
```

- [ ] **Step 4: Run — verify PASS** (CI).

- [ ] **Step 5: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Userscripts/InstalledManifest.swift WarboardIOS/Tests/WarboardIOSTests/InstalledManifestTests.swift && git -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "Userscripts: InstalledManifest builds the app->server installed manifest"
```

---

## Task I4: wire Approve → install + send the manifest (Agent module)

**Files:**
- Modify: `WarboardIOS/Sources/WarboardIOS/Agent/AgentClient.swift:16-20` (+ its `inspect(...)`)
- Modify: `WarboardIOS/Sources/WarboardIOS/Agent/AgentChatViewModel.swift:25-57,150-166` (+ the `client.stream`/`client.inspect` call sites)
- Modify: `WarboardIOS/Sources/WarboardIOS/Agent/AgentChatView.swift:171`

**Interfaces:**
- Consumes: `LocalInstaller` (I2), `InstalledManifest` (I3), `ScriptRegistry.shared`, `AgentClient.baseUrl`.
- Note: this task touches the `Agent/` folder, which is NOT in the SwiftPM test target — there are no `swift test` unit tests here. Verified by the full-app `xcodebuild build` in CI, an adversarial review of the diff, and manual E2E.

- [ ] **Step 1: `AgentClient.stream` sends the manifest.** Replace `stream` (lines 16-20):

```swift
func stream(text: String, sessionId: String?, installedScripts: [[String: Any]]) -> AsyncStream<AgentEvent> {
    var body: [String: Any] = ["text": text]
    if let sessionId = sessionId { body["sessionId"] = sessionId }
    if !installedScripts.isEmpty { body["installedScripts"] = installedScripts }
    return openStream(path: "/api/agent/message", body: body)
}
```

Apply the same addition to `AgentClient.inspect(...)`: add an `installedScripts: [[String: Any]]` parameter and set `body["installedScripts"] = installedScripts` when non-empty (its body currently carries `["js": js, "sessionId": sessionId]`).

- [ ] **Step 2: `AgentChatViewModel` holds a registry + passes the manifest.** Add a stored property and init parameter (line 25-57 region):

```swift
    /// The on-device userscript store — read to send the installed manifest and
    /// written when the owner approves a proposal.
    let registry: ScriptRegistry

    init(registry: ScriptRegistry = .shared) {
        self.registry = registry
        if let saved = AgentChatStore.load() {
            messages = saved.messages
            sessionId = saved.sessionId
        }
    }
```

At each `client.stream(...)` / `client.inspect(...)` call site in this file, build and pass the manifest:

```swift
let manifest = InstalledManifest.build(from: registry.all()).asJSONBody()
// ... client.stream(text: ..., sessionId: sessionId, installedScripts: manifest)
// ... client.inspect(js: ..., sessionId: sid, installedScripts: manifest)
```

- [ ] **Step 3: `deployProposal` installs locally.** Replace `deployProposal()` (lines 150-166):

```swift
func deployProposal() {
    guard let draft = pendingProposal, !deploying, let client = client else { return }
    deploying = true
    deployStatus = "Installing \(draft.filename)…"

    Task { [weak self] in
        guard let self else { return }
        let result = await client.deploy(filename: draft.filename, content: draft.content)
        let downloadURL = client.baseUrl + "/scripts/" + draft.filename
        do {
            try await LocalInstaller(registry: self.registry)
                .install(filename: draft.filename, content: draft.content, downloadURL: downloadURL)
            self.deployStatus = "Installed \(draft.filename) — reload the Torn page to see it."
                + (result.ok ? "" : " (server backup failed: \(result.message))")
            self.pendingProposal = nil
        } catch {
            self.deployStatus = "Couldn't install \(draft.filename): \(error.localizedDescription)"
                + (result.ok ? " (saved to your server collection)" : "")
        }
        self.deploying = false
    }
}
```

- [ ] **Step 4: Button label.** In `AgentChatView.swift` line 171, change `Text(vm.deploying ? "Deploying…" : "Apply & deploy")` → `Text(vm.deploying ? "Installing…" : "Approve & install")`.

- [ ] **Step 5: Verify (CI + E2E).** Push the branch and trigger `test-sim.yml` (`workflow_dispatch`) — the `xcodebuild build -scheme Warboard` step must compile the Agent module. Then manual E2E on TestFlight: agent proposes a script → **Approve & install** → the script appears in the Scripts tab and runs after a Torn reload → ask the agent to list installed scripts → the count/names match the Scripts tab → redeploy an edit → updates in place (no duplicate row).

- [ ] **Step 6: Commit**

```bash
cd /root/projects/warboard-ios && git add WarboardIOS/Sources/WarboardIOS/Agent/ && git -c user.name=RussianRob -c user.email=russianrob@users.noreply.github.com commit -m "Agent: Approve installs locally + sends the installed manifest with each message"
```

---

## Self-Review

**1. Spec coverage.**
- Part 1 (local install, runs immediately, shows in manager, upsert-no-dup, server backup kept) → I1 (factory), I2 (installer w/ dedup), I4 (wiring + kept `client.deploy`). ✓
- Part 2 (app sends real installed set; context from manifest; read/edit any installed script) → I3 (manifest), I4 (send), S1 (context from manifest), S2/S3 (`===SOURCE:===` from manifest). ✓
- Part 3 (stable filename identity → upsert; parse/require failures surfaced; server backup stays) → I2 (identity + guard + findInstalled), I4 (error surfacing + `client.deploy` retained). ✓
- Body-limit exemption → S4. ✓ Backward-compat fallback to the served dir → S1 (string/undefined branch) + S2/S3 (fallbacks). ✓ Security (approval-only) → I4 (`deployProposal` runs only from the Apply card) + Global Constraints. ✓

**2. Placeholder scan.** No "TBD"/"add error handling"/"similar to". The only non-verbatim step is I4 Step 2's "each `client.stream`/`client.inspect` call site" — unavoidable because those call sites live in a `send` path not extracted here; the instruction is concrete (build `manifest`, pass `installedScripts:`). The implementer will find the two call sites when the changed `stream`/`inspect` signatures fail to compile.

**3. Type consistency.** `ScriptFactory.make(from:source:downloadURL:)` used identically in I1/I2. `LocalInstaller.install(filename:content:downloadURL:)` produced in I2, consumed in I4. `InstalledManifest.build(from:) -> [ManifestEntry]` + `.asJSONBody() -> [[String:Any]]` produced in I3, consumed in I4 as `installedScripts:`. Server `installed` param name consistent across `userscriptContext`/`buildTurnPrompt`/`runAgentTurn`/`runAgentTurnResolvingSources`/`resolveScriptSource`; HTTP field `installedScripts` consistent (iOS body key ↔ `req.body.installedScripts`). `RequireResolver.resolve(_:forceRefetch:)` and `init(cache:fetch:)` match the extracted signatures. ✓

## Execution notes

- Tasks are ordered server-first (S1→S4, pure Node, locally runnable + committable) then iOS (I1→I4, CI-verified). S-tasks and I-tasks are independent; the feature only works end-to-end once both sides land.
- Do the final whole-branch adversarial review on the iOS diff (Agent-module wiring has no unit tests) before merging to `main`.

<!-- markdownlint-disable MD013 -->
# Cockpit Embed Mode Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Let the RPI Cockpit load cleanly inside a host-managed pane (Claude Code Preview, VS Code webview) by resolving the host-assigned port and opting into a loopback-trust mode that skips the per-session token while keeping the Origin defense.

Architecture: A pure `resolvePort(env)` helper reads `PORT` (the host-assigned variable) ahead of `RPI_COCKPIT_PORT` and the `4399` default, and is wired into both the MCP entry and the preview launcher. The existing `startServer` gains an opt-in `trustLoopback` flag that, when set, bypasses the token gate on the HTTP handler and the WS `verifyClient` while preserving the Origin check; the secure default keeps the token required so all current tests stay green. A committed `preview.mjs` plus a `.claude/launch.json` config and an `npm run preview` script give the host a zero-step harness that drives a representative RPI demo session.

Tech Stack: Node.js >= 20, TypeScript 5.6 (strict, ESM with NodeNext), the `ws` WebSocket library, `zod` schemas, and Vitest 2 (node environment) for tests. Markdown is linted with `markdownlint-cli2`.

## Global Constraints

* TypeScript strict mode is on (`tsconfig.json` has `"strict": true`); no `any` leaks and no non-null assertions added beyond what already exists.
* ESM with NodeNext: every relative import inside `src/` uses a `.js` extension (for example `import { startServer } from "./server.js"`), matching the existing files.
* Do not commit `dist/` or `.codex`; only source, tests, the preview launcher, the launch config, and `package.json` script changes ship.
* Secure default is unchanged: with `trustLoopback` off (the default), the per-session token is still required for HTTP and WS, and every existing test in `tests/server.test.ts` must stay green.
* Loopback trust is opt-in only: the flag defaults from `process.env.RPI_COCKPIT_TRUST_LOOPBACK` being truthy, and the Origin check is never skipped in either mode.
* Repo markdown rules: no em dashes and no bolded-prefix list items. Use plain lists, tables, or headings.

## File Structure

| File | Create or Modify | Responsibility |
|---|---|---|
| `rpi-cockpit/src/port.ts` | Create | Pure `resolvePort(env)` helper that picks the port from `PORT`, then `RPI_COCKPIT_PORT`, then `4399`, validating each candidate is a finite, in-range port. |
| `rpi-cockpit/tests/port.test.ts` | Create | Unit tests for `resolvePort` precedence and NaN/empty fall-through. |
| `rpi-cockpit/src/server.ts` | Modify | Add `trustLoopback` to the `startServer` options, default it from `RPI_COCKPIT_TRUST_LOOPBACK`, and skip the token check (but not the Origin check) in the HTTP gate and WS `verifyClient` when it is on. |
| `rpi-cockpit/tests/server.test.ts` | Modify | Add an `embed mode` describe block covering the HTTP gate and WS behavior with `trustLoopback: true`, while the existing secure-default tests stay untouched and green. |
| `rpi-cockpit/src/index.ts` | Modify | Resolve the port through `resolvePort(process.env)` instead of reading `RPI_COCKPIT_PORT` directly. |
| `rpi-cockpit/preview.mjs` | Create | Committed preview launcher: reads `resolvePort`, starts the server with `trustLoopback: true`, drives a short RPI demo session, and keeps the process alive. |
| `rpi-cockpit/preview-server.mjs` | Delete | Remove the throwaway preview launcher that `preview.mjs` replaces. |
| `.claude/launch.json` | Modify | Point the `rpi-cockpit` configuration at `rpi-cockpit/preview.mjs`. |
| `rpi-cockpit/package.json` | Modify | Add a `preview` script that runs the committed launcher. |

### Task 1: Pure `resolvePort` helper plus unit tests

Files:

* Create: `rpi-cockpit/src/port.ts`
* Test: `rpi-cockpit/tests/port.test.ts`

Interfaces:

```ts
// produced
export function resolvePort(env: Record<string, string | undefined>): number;
```

Steps:

* [ ] Step: Create `rpi-cockpit/src/port.ts` with the exact contents below. The helper coerces each candidate with `Number(...)`, treats `0`, `NaN`, and out-of-range values as absent (so it falls through), and returns `4399` when nothing valid is set. `PORT` is the host-assigned variable used by the Claude Code Preview pane and VS Code, so it wins.

```ts
// rpi-cockpit/src/port.ts

// Resolve the port the cockpit should bind. Precedence, highest first:
//   1. PORT               — assigned by the host pane (Claude Preview, VS Code).
//   2. RPI_COCKPIT_PORT   — our own override for standalone runs.
//   3. 4399               — the stable default.
// A candidate counts only if it is a finite integer in the valid TCP range
// 1..65535. Anything else (empty, NaN, 0, negative, > 65535, fractional) is
// treated as absent and we fall through to the next source.
function validPort(raw: string | undefined): number | null {
  if (raw === undefined || raw === "") return null;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 65535) return null;
  return n;
}

export function resolvePort(env: Record<string, string | undefined>): number {
  return validPort(env.PORT) ?? validPort(env.RPI_COCKPIT_PORT) ?? 4399;
}
```

* [ ] Step: Create `rpi-cockpit/tests/port.test.ts` with the exact contents below. The tests assert that `PORT` wins over `RPI_COCKPIT_PORT` wins over the default, and that NaN/empty values fall through.

```ts
// rpi-cockpit/tests/port.test.ts
import { describe, it, expect } from "vitest";
import { resolvePort } from "../src/port.js";

describe("resolvePort", () => {
  it("uses PORT when it is a valid port", () => {
    expect(resolvePort({ PORT: "5123" })).toBe(5123);
  });

  it("prefers PORT over RPI_COCKPIT_PORT", () => {
    expect(resolvePort({ PORT: "5123", RPI_COCKPIT_PORT: "6001" })).toBe(5123);
  });

  it("falls back to RPI_COCKPIT_PORT when PORT is absent", () => {
    expect(resolvePort({ RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("falls back to 4399 when neither is set", () => {
    expect(resolvePort({})).toBe(4399);
  });

  it("treats an empty PORT as absent and falls through", () => {
    expect(resolvePort({ PORT: "", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("treats a non-numeric PORT as absent and falls through", () => {
    expect(resolvePort({ PORT: "not-a-port", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("treats PORT=0 as absent and falls through", () => {
    expect(resolvePort({ PORT: "0", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("rejects an out-of-range PORT and falls through to the default", () => {
    expect(resolvePort({ PORT: "70000" })).toBe(4399);
  });

  it("rejects a fractional PORT and falls through to the default", () => {
    expect(resolvePort({ PORT: "8080.5" })).toBe(4399);
  });
});
```

* [ ] Step: Run the tests. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/port.test.ts`. Expected output: one test file passes with 9 passed tests and a non-error exit code (the summary line reads `Test Files  1 passed (1)` and `Tests  9 passed (9)`).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/port.ts rpi-cockpit/tests/port.test.ts && git commit -m "feat(cockpit): add resolvePort helper (PORT > RPI_COCKPIT_PORT > 4399)"`.

### Task 2: Loopback-trust embed mode in `startServer`

Files:

* Modify: `rpi-cockpit/src/server.ts`
* Test: `rpi-cockpit/tests/server.test.ts`

Interfaces:

```ts
// changed signature (consumed by index.ts and preview.mjs)
export async function startServer(
  bridge: Bridge,
  port?: number,
  opts?: { stateDir?: string; trustLoopback?: boolean },
): Promise<{ port: number; token: string; url: string; stateDir: string; close: () => Promise<void> }>;
```

Steps:

* [ ] Step: In `rpi-cockpit/src/server.ts`, widen the `opts` parameter of `startServer` to add `trustLoopback`, and derive the effective flag from the option or the environment. Replace the existing function signature line:

```ts
export async function startServer(bridge: Bridge, port = 4399, opts?: { stateDir?: string }) {
```

with:

```ts
export async function startServer(
  bridge: Bridge,
  port = 4399,
  opts?: { stateDir?: string; trustLoopback?: boolean },
) {
  // Embed mode: when a trusted host (the Claude Preview pane or a VS Code
  // webview) launches and owns this server, it loads the bare root URL, which
  // the token gate would 403. Opting into trustLoopback skips the token check on
  // both the HTTP gate and the WS upgrade so the pane loads with no key. The
  // Origin check below is KEPT in both modes, so a browser still cannot drive a
  // cross-origin connection. Trade-off: embed mode trusts ANY loopback client,
  // which is the host-managed-pane trust boundary — anyone who can already reach
  // 127.0.0.1 on this port is treated as the user. Secure default is unchanged:
  // with the flag off, the per-session token is still required.
  const trustLoopback = opts?.trustLoopback ?? Boolean(process.env.RPI_COCKPIT_TRUST_LOOPBACK);
```

The original function body (the `token` minting line onward) continues unchanged immediately after this added line.

* [ ] Step: In `rpi-cockpit/src/server.ts`, update the HTTP gate so it short-circuits to authorized when `trustLoopback` is on. Replace this block:

```ts
  const httpServer = http.createServer(async (req, res) => {
    // HTTP gate: before any file serving, require a valid token (query or cookie).
    if (!isAuthorized(req.url, req.headers.cookie)) {
```

with:

```ts
  const httpServer = http.createServer(async (req, res) => {
    // HTTP gate: before any file serving, require a valid token (query or cookie),
    // UNLESS embed mode trusts the loopback pane, in which case the bare root and
    // assets are served without a key.
    if (!trustLoopback && !isAuthorized(req.url, req.headers.cookie)) {
```

The rest of the handler is unchanged: a `?key=<token>` still mirrors the token into the hardened cookie, and the path-traversal guard and file serving stay as-is.

* [ ] Step: In `rpi-cockpit/src/server.ts`, update the WS `verifyClient` so the token requirement is waived under `trustLoopback` while the Origin check still applies. Replace this block:

```ts
    verifyClient: (info, cb) => {
      const tokenOk = isAuthorized(info.req.url, info.req.headers.cookie);
      const origin = info.req.headers.origin;
      const originOk = !origin || origin === "http://" + info.req.headers.host;
      if (tokenOk && originOk) cb(true);
      else cb(false, 401);
    },
```

with:

```ts
    verifyClient: (info, cb) => {
      // In embed mode the token is waived, but the Origin check is NOT: a browser
      // still must present an Origin matching this server's own host (or none, as
      // non-browser clients do), which defeats cross-origin / DNS-rebinding.
      const tokenOk = trustLoopback || isAuthorized(info.req.url, info.req.headers.cookie);
      const origin = info.req.headers.origin;
      const originOk = !origin || origin === "http://" + info.req.headers.host;
      if (tokenOk && originOk) cb(true);
      else cb(false, 401);
    },
```

* [ ] Step: In `rpi-cockpit/tests/server.test.ts`, add a new `embed mode` describe block at the end of the outer `describe("server", ...)` block, immediately after the closing brace that ends the existing `describe("auth", ...)` block, and before the final closing brace that ends `describe("server", ...)`. Paste exactly:

```ts
  describe("embed mode (trustLoopback)", () => {
    it("HTTP GET / with no key and no cookie -> 200 index.html", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const res = await get(srv.port, "/");
      expect(res.status).toBe(200);
      expect(res.body.toLowerCase()).toContain("<!doctype html");
    });

    it("the keyed path still serves 200 with trustLoopback on", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const res = await get(srv.port, `/?key=${srv.token}`);
      expect(res.status).toBe(200);
      expect(res.body.toLowerCase()).toContain("<!doctype html");
    });

    it("the secure default (no flag) still 403s GET / with no key", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, "/");
      expect(res.status).toBe(403);
    });

    it("WS connect with NO key -> opens and receives initial state", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
      const first = await new Promise<any>((res, rej) => {
        ws.on("message", (d) => res(JSON.parse(String(d))));
        ws.on("error", rej);
      });
      expect(first.type).toBe("state");
      ws.close();
    });

    it("WS connect with a WRONG Origin is still rejected in embed mode", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`, {
        headers: { origin: "http://evil.example" },
      });
      const opened = await new Promise<boolean>((resolve) => {
        ws.on("open", () => resolve(true));
        ws.on("error", () => resolve(false));
        ws.on("close", () => resolve(false));
      });
      expect(opened).toBe(false);
      try { ws.close(); } catch { /* already closed */ }
    });
  });
```

* [ ] Step: Run the full server suite (existing secure-default tests plus the new embed block) and the port test together. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run`. Expected output: all test files pass, including `tests/server.test.ts` (the original auth tests stay green) and `tests/port.test.ts`, with a non-error exit code and the final line reading `Tests  N passed (N)` where `N` is the full count.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/server.ts rpi-cockpit/tests/server.test.ts && git commit -m "feat(cockpit): opt-in loopback-trust embed mode (skip token, keep Origin)"`.

### Task 3: Wire `resolvePort` into the MCP entry

Files:

* Modify: `rpi-cockpit/src/index.ts`

Interfaces:

```ts
// consumed
import { resolvePort } from "./port.js";
```

Steps:

* [ ] Step: In `rpi-cockpit/src/index.ts`, add the import near the other local imports (after the `runInit` import line). Insert:

```ts
import { resolvePort } from "./port.js";
```

* [ ] Step: In `rpi-cockpit/src/index.ts`, replace the direct port read:

```ts
const port = Number(process.env.RPI_COCKPIT_PORT ?? 4399);
```

with the resolver so the host-assigned `PORT` is honored in a pane:

```ts
const port = resolvePort(process.env);
```

The surrounding behavior is unchanged: the server is still best-effort, the keyed URL and state dir are still printed on stderr, and the MCP stdio transport still connects regardless of the server outcome.

* [ ] Step: Type-check and run the suite to confirm nothing regressed. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected output: `tsc` prints nothing and exits 0, then all test files pass with a non-error exit code.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/index.ts && git commit -m "feat(cockpit): resolve port via resolvePort in the MCP entry"`.

### Task 4: Committed preview launcher and launch config

Files:

* Create: `rpi-cockpit/preview.mjs`
* Delete: `rpi-cockpit/preview-server.mjs`
* Modify: `.claude/launch.json`
* Modify: `rpi-cockpit/package.json`

Interfaces:

```js
// consumed at runtime from the built dist/ output
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";
```

Steps:

* [ ] Step: Create `rpi-cockpit/preview.mjs` with the exact contents below. It resolves the port with `resolvePort`, starts the server in embed mode (`trustLoopback: true`) so the pane loads with no key, drives a representative RPI session through the real `Bridge` API (`emitBeat`, `presentOptions`), and keeps the process alive with a long-lived timer so the pane stays connected. The beats use only valid beat types and the `validate` checks `lint`, `types`, `tests` match `demo.mjs`.

```js
// rpi-cockpit/preview.mjs
// Committed preview / dev harness. The host pane (Claude Preview, VS Code) sets
// PORT and loads the bare root, so we start the server in embed mode
// (trustLoopback: true) and drive a short, representative RPI session so the
// cockpit paints immediately. This is the dev/preview harness only; the live
// agent-driven feed is a later plan. Requires a prior `npm run build`.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
const port = resolvePort(process.env);
const srv = await startServer(b, port, { trustLoopback: true });
// Embed mode serves the bare root, so the host can load srv.url without the key.
process.stderr.write(`rpi-cockpit preview at ${srv.url}\n`);

async function run() {
  await sleep(800); // brief lead-in so a freshly loaded pane catches the start

  b.emitBeat({ type: "session.begin", task: "Refactor auth module", host: "claude-code" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning auth + session store" });
  await sleep(800);
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "done" });

  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying auth/middleware.ts" });
  b.emitBeat({ type: "validate", check: "lint", status: "ok" });
  b.emitBeat({ type: "validate", check: "types", status: "ok" });
  b.emitBeat({ type: "validate", check: "tests", status: "running" });

  const choice = await b.presentOptions("Which approach?", [
    { id: "a", title: "Minimal patch", detail: "Guard the handler in place." },
    { id: "b", title: "Token middleware", detail: "Reusable middleware layer.", recommended: true },
    { id: "c", title: "Full rewrite", detail: "Policy engine, higher risk." },
  ]);
  process.stderr.write(`rpi-cockpit preview: chose ${choice}\n`);

  b.emitBeat({ type: "validate", check: "tests", status: "ok" });
  b.emitBeat({ type: "subagent.stop", name: "Phase Implementor", result: `implemented option ${choice}` });
}

run().catch((e) => process.stderr.write(`rpi-cockpit preview error: ${e?.message ?? e}\n`));

// Keep the process (and the server) alive so the pane stays connected.
setInterval(() => {}, 1 << 30);
```

* [ ] Step: Delete the throwaway launcher. Command: `git rm rpi-cockpit/preview-server.mjs`.
* [ ] Step: In `.claude/launch.json`, retarget the `rpi-cockpit` configuration from the deleted file to the committed one. Replace:

```json
      "runtimeArgs": ["rpi-cockpit/preview-server.mjs"],
```

with:

```json
      "runtimeArgs": ["rpi-cockpit/preview.mjs"],
```

The rest of the file is unchanged, so the final `.claude/launch.json` reads exactly:

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "rpi-cockpit",
      "runtimeExecutable": "node",
      "runtimeArgs": ["rpi-cockpit/preview.mjs"],
      "autoPort": true
    }
  ]
}
```

* [ ] Step: In `rpi-cockpit/package.json`, add a `preview` script to the `scripts` block. Replace:

```json
    "dev": "tsx src/index.ts",
```

with:

```json
    "dev": "tsx src/index.ts",
    "preview": "node preview.mjs",
```

* [ ] Step: Build, then smoke-test the launcher binds and prints its URL, then stop it. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npm run build && PORT=4501 node preview.mjs & sleep 2; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4501/; kill %1`. Expected output: the build completes, `preview.mjs` prints `rpi-cockpit preview at http://127.0.0.1:4501/?key=...` on stderr, and `curl` against the bare root prints `200` (embed mode serves index.html with no key). Note: do not commit `dist/`; the build is only for the smoke test.
* [ ] Step: Commit only the source-controlled files (not `dist/`). Command: `git add rpi-cockpit/preview.mjs .claude/launch.json rpi-cockpit/package.json && git rm --cached --ignore-unmatch rpi-cockpit/preview-server.mjs && git commit -m "feat(cockpit): committed preview launcher + embed launch config"`.

## Self-Review

Spec coverage:

* Port resolution: Task 1 creates `resolvePort` with the exact `PORT > RPI_COCKPIT_PORT > 4399` precedence and NaN/empty/0/out-of-range fall-through, unit-tested in `tests/port.test.ts`; Task 3 wires it into `index.ts`; Task 4 wires it into `preview.mjs`.
* Loopback-trust embed mode: Task 2 adds the opt-in `trustLoopback` flag defaulting from `RPI_COCKPIT_TRUST_LOOPBACK`, skips the token in the HTTP gate and WS `verifyClient`, keeps the Origin check in both modes, leaves the secure default intact, and documents the trust-boundary trade-off in a code comment.
* Preview launcher: Task 4 creates `preview.mjs` (reads `resolvePort`, starts with `trustLoopback: true`, drives session.begin -> phase.enter research/plan/implement -> subagent.start -> validate lint/types/tests -> presentOptions, then keeps the process alive), removes the throwaway `preview-server.mjs`, retargets `.claude/launch.json`, and adds the `npm run preview` script.
* TDD tests: `resolvePort` precedence and fall-through (Task 1); HTTP gate 200-with-flag and 403-without plus the keyed path in both modes (Task 2); WS no-key accept with the flag and the Origin rejection still applying (Task 2). The existing no-key-rejected and wrong-Origin secure-default tests are untouched.

Placeholder scan: every code step contains complete, runnable TypeScript or JavaScript copied or adapted from the read sources (`server.ts`, `index.ts`, `bridge.ts`, `events.ts`, `demo.mjs`, `preview-server.mjs`). There are no `TBD`, `similar to`, or `add error handling` placeholders.

Type consistency: the widened `startServer` options object is `{ stateDir?: string; trustLoopback?: boolean }`, matching how `opts?.stateDir` is already read and how Task 2 reads `opts?.trustLoopback`. `resolvePort` takes `Record<string, string | undefined>`, which `process.env` satisfies. The preview launcher imports the built `./dist/port.js`, which exists after `npm run build` compiles the new `src/port.ts`. Beat objects in `preview.mjs` use only valid discriminated-union members from `events.ts`, and `presentOptions` returns a `Promise<string>` that the launcher awaits.

## Subsequent plans

The following follow-ons are deferred out of this design-complete v1 embed-mode plan:

1. The live data plane: how the agent's MCP-driven cockpit feeds the embedded pane. The host's `preview_start` launches a separate process from the agent's MCP server, so a later plan must bridge the agent's live beats into the pane's server (for example a shared state dir, a relay socket, or a single shared server) rather than the canned `preview.mjs` session.
2. The `app_frame` primitive: a trusted localhost iframe pane, the sibling of the sandboxed `screen` pane, so the cockpit can embed the app under development beside the RPI loop and steer panel.
3. The protocol generalization: list, question, and context primitives plus a generic timeline, generalizing the RPI-specific phase enum toward the archetype-agnostic primitives in `docs/representation-map.md`, with RPI as the first composition.
</invoke>

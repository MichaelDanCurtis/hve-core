<!-- markdownlint-disable MD013 -->
# Elicitation decision primitive Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Make `present_options` surface a decision on both surfaces at once, the in-pane web card and a native host choice card (MCP elicitation), where the first answer wins and the other is dismissed, with a clean fallback to the pane card on hosts that do not support elicitation.

Architecture: A new pure module `src/elicit.ts` maps options to an elicitation form schema and maps an `ElicitResult` back to an option id, and an orchestrator races `bridge.presentOptions` (the pane card) against `server.elicitInput` (the native card). The orchestrator depends only on a small `ElicitCapableServer` interface so it is testable with a fake; `src/mcp.ts` adapts the real `McpServer`'s underlying `Server` to that interface. The agent's role is unchanged: `present_options` is still a blocking tool it calls.

Tech Stack: Node.js >= 20, TypeScript 5.6 (strict, ESM NodeNext), `@modelcontextprotocol/sdk` (server `elicitInput` + `getClientCapabilities`, client `setRequestHandler(ElicitRequestSchema, ...)`), Vitest 2.

## Global Constraints

* TypeScript strict; no `any`, no new non-null assertions. ESM NodeNext `.js` relative imports.
* Captures intent, agent-driven: `present_options` stays a blocking tool the agent calls. The cockpit never starts an agent.
* Secure defaults unchanged: the in-pane decision card UX, the token gate, and the iframe `sandbox=""` are untouched.
* A declined or cancelled elicitation must NOT resolve the decision. The pane card and the existing timeout fallback to the recommended option remain in play.
* The SDK's `ElicitResult.content` value type is `string | number | boolean | string[]`; narrow with `typeof` before treating a choice as a string. No `any`.
* Do not commit `dist/`. Repo markdown rules for any docs: asterisk bullets, no em dashes, no bolded-prefix list items.

## File Structure

| File | Create or Modify | Responsibility |
|---|---|---|
| `src/elicit.ts` | Create | `decisionTimeoutMs`, `optionsToElicitSchema`, `elicitResultToChoice`, the `ElicitCapableServer` interface, and the `presentOptionsWithElicitation` orchestrator. |
| `tests/elicit.test.ts` | Create | Unit tests for the two pure mappers and for the orchestrator against a fake server and a real `Bridge`. |
| `src/mcp.ts` | Modify | `present_options` calls `presentOptionsWithElicitation`, adapting `server.server` to `ElicitCapableServer`. |
| `src/handlers.ts` | Modify | Remove `present_options` and the now-moved `decisionTimeoutMs` (superseded by `src/elicit.ts`). |
| `tests/handlers.test.ts` | Modify | Remove the `present_options` handler test (the behavior now lives in `tests/elicit.test.ts`). |
| `tests/mcp.test.ts` | Modify | Add an integration test: a real elicitation-capable mock client answers the `elicitation/create` request and resolves the `present_options` tool. |

---

### Task 1: Pure elicitation mappers

Files:

* Create: `src/elicit.ts` (the two pure helpers and `decisionTimeoutMs`; the orchestrator is added in Task 2)
* Test: `tests/elicit.test.ts`

Interfaces:

```ts
// produced
export function decisionTimeoutMs(): number;
export interface ElicitFormParams {
  message: string;
  requestedSchema: { type: "object"; properties: Record<string, unknown>; required?: string[] };
}
export function optionsToElicitSchema(prompt: string, options: OptionItem[]): ElicitFormParams;
export function elicitResultToChoice(result: ElicitResult, options: OptionItem[]): string | null;
```

Steps:

* [ ] Step: Write the failing test. Create `tests/elicit.test.ts` with exactly:

```ts
import { describe, it, expect } from "vitest";
import { optionsToElicitSchema, elicitResultToChoice } from "../src/elicit.js";
import type { OptionItem } from "../src/events.js";

const OPTS: OptionItem[] = [
  { id: "a", title: "Minimal patch" },
  { id: "b", title: "Token middleware", recommended: true },
  { id: "c", title: "Full rewrite" },
];

describe("optionsToElicitSchema", () => {
  it("builds a form with the prompt as the message and a single required choice", () => {
    const f = optionsToElicitSchema("Which approach?", OPTS);
    expect(f.message).toBe("Which approach?");
    expect(f.requestedSchema.type).toBe("object");
    expect(f.requestedSchema.required).toEqual(["choice"]);
  });

  it("maps options to oneOf const/title pairs and defaults to the recommended option", () => {
    const choice = optionsToElicitSchema("p", OPTS).requestedSchema.properties.choice as {
      oneOf: { const: string; title: string }[];
      default: string;
    };
    expect(choice.oneOf).toEqual([
      { const: "a", title: "Minimal patch" },
      { const: "b", title: "Token middleware" },
      { const: "c", title: "Full rewrite" },
    ]);
    expect(choice.default).toBe("b");
  });

  it("defaults to the first option when none is recommended", () => {
    const choice = optionsToElicitSchema("p", [{ id: "x", title: "X" }, { id: "y", title: "Y" }])
      .requestedSchema.properties.choice as { default: string };
    expect(choice.default).toBe("x");
  });
});

describe("elicitResultToChoice", () => {
  it("returns the chosen id on accept with a valid choice", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "b" } }, OPTS)).toBe("b");
  });
  it("returns null on decline", () => {
    expect(elicitResultToChoice({ action: "decline" }, OPTS)).toBeNull();
  });
  it("returns null on cancel", () => {
    expect(elicitResultToChoice({ action: "cancel" }, OPTS)).toBeNull();
  });
  it("returns null when the choice is not a known option id", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "zzz" } }, OPTS)).toBeNull();
  });
  it("returns null when content is missing", () => {
    expect(elicitResultToChoice({ action: "accept" }, OPTS)).toBeNull();
  });
});
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts`. Expected: FAIL (cannot resolve `../src/elicit.js`).
* [ ] Step: Create `src/elicit.ts` with exactly this content (the orchestrator is added in Task 2):

```ts
// src/elicit.ts
// The decision/question primitive's elicitation path. Pure mappers turn the
// cockpit's OptionItem list into an MCP elicitation form and turn the client's
// ElicitResult back into an option id. The orchestrator (Task 2) races the
// in-pane card against the native elicitation card.
import type { OptionItem } from "./events.js";
import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";

// A decision must not block the agent forever: fall back to the recommended
// option after a finite timeout. Configurable via env (default 30 min).
const DEFAULT_DECISION_TIMEOUT_MS = 1_800_000;
export function decisionTimeoutMs(): number {
  const raw = Number(process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_DECISION_TIMEOUT_MS;
}

export interface ElicitFormParams {
  message: string;
  requestedSchema: { type: "object"; properties: Record<string, unknown>; required?: string[] };
}

// Form mode with a single required string property whose oneOf carries the
// options as const/title pairs (the canonical SDK shape for a labelled choice),
// defaulting to the recommended option.
export function optionsToElicitSchema(prompt: string, options: OptionItem[]): ElicitFormParams {
  const fallback = options.find((o) => o.recommended) ?? options[0];
  return {
    message: prompt,
    requestedSchema: {
      type: "object",
      properties: {
        choice: {
          type: "string",
          title: "Choose an option",
          oneOf: options.map((o) => ({ const: o.id, title: o.title })),
          default: fallback.id,
        },
      },
      required: ["choice"],
    },
  };
}

// Only an accepted result with a known option id counts as a choice. Decline,
// cancel, missing content, and unknown ids all return null (no decision).
export function elicitResultToChoice(result: ElicitResult, options: OptionItem[]): string | null {
  if (result.action !== "accept" || !result.content) return null;
  const choice = result.content.choice;
  if (typeof choice !== "string") return null;
  return options.some((o) => o.id === choice) ? choice : null;
}
```

* [ ] Step: Run the test to verify it passes. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts`. Expected: PASS (8 tests).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/elicit.ts rpi-cockpit/tests/elicit.test.ts && git commit -m "feat(cockpit): elicitation form + result mappers for the decision primitive"`.

---

### Task 2: The race orchestrator

Files:

* Modify: `src/elicit.ts` (add the interface and the orchestrator)
* Test: `tests/elicit.test.ts` (add an orchestrator describe block)

Interfaces:

```ts
// produced
export interface ElicitCapableServer {
  getClientCapabilities(): { elicitation?: unknown } | undefined;
  elicitInput(params: ElicitFormParams, options?: { signal?: AbortSignal }): Promise<ElicitResult>;
}
export function presentOptionsWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  options: OptionItem[],
  timeoutMs: number,
): Promise<string>;
```

Steps:

* [ ] Step: Write the failing orchestrator tests. Add to `tests/elicit.test.ts` (append inside the file), and add `import { presentOptionsWithElicitation } from "../src/elicit.js";` and `import { Bridge } from "../src/bridge.js";` and `import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";` to the imports:

```ts
function fakeServer(opts: {
  elicitation: boolean;
  respond?: (params: any, signal?: AbortSignal) => Promise<ElicitResult>;
}) {
  let elicitCalls = 0;
  return {
    elicitCalls: () => elicitCalls,
    getClientCapabilities: () => (opts.elicitation ? { elicitation: {} } : {}),
    elicitInput: (params: any, o?: { signal?: AbortSignal }) => {
      elicitCalls += 1;
      return (opts.respond ?? (() => new Promise<ElicitResult>(() => {})))(params, o?.signal);
    },
  };
}

describe("presentOptionsWithElicitation", () => {
  const OPTS = [
    { id: "a", title: "Minimal" },
    { id: "b", title: "Middleware", recommended: true },
    { id: "c", title: "Rewrite" },
  ];

  it("with no elicitation capability, resolves only via the pane card", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: false });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    // The pane card is shown; resolve it like the web decide frame would.
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "a");
    expect(await p).toBe("a");
    expect(srv.elicitCalls()).toBe(0);
  });

  it("when the elicitation accepts first, resolves with the elicited choice and clears the pane card", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "accept", content: { choice: "c" } }) });
    const choice = await presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    expect(choice).toBe("c");
    expect(bridge.state.pendingDecision).toBeNull();
  });

  it("when the pane card answers first, resolves with the web choice and aborts the elicitation", async () => {
    const bridge = new Bridge();
    let aborted = false;
    const srv = fakeServer({
      elicitation: true,
      respond: (_p, signal) =>
        new Promise<ElicitResult>((_res, rej) => {
          signal?.addEventListener("abort", () => { aborted = true; rej(new Error("aborted")); });
        }),
    });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "b");
    expect(await p).toBe("b");
    expect(aborted).toBe(true);
  });

  it("a declined elicitation does not resolve the decision; the pane card still can", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "decline" }) });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    await new Promise((r) => setTimeout(r, 10)); // let the declined elicitation settle
    expect(bridge.state.pendingDecision).not.toBeNull();
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "a");
    expect(await p).toBe("a");
  });
});
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts`. Expected: FAIL (`presentOptionsWithElicitation` not exported).
* [ ] Step: In `src/elicit.ts`, add the `Bridge` import to the top (`import type { Bridge } from "./bridge.js";`) and append the interface and orchestrator:

```ts
// Minimal server surface the orchestrator needs; the real McpServer's underlying
// Server satisfies it (adapted in mcp.ts).
export interface ElicitCapableServer {
  getClientCapabilities(): { elicitation?: unknown } | undefined;
  elicitInput(params: ElicitFormParams, options?: { signal?: AbortSignal }): Promise<ElicitResult>;
}

// Show the in-pane card always (rung 2). If the host supports elicitation, also
// send a native card (rung 1) and race them: the first real answer wins and the
// loser is dismissed. A declined or cancelled elicitation is ignored so the pane
// card and the timeout fallback stay in control.
export async function presentOptionsWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  options: OptionItem[],
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.presentOptions(prompt, options, timeoutMs);
  const canElicit = server.getClientCapabilities()?.elicitation !== undefined;
  if (!canElicit) return webPromise;

  const decisionId = bridge.state.pendingDecision?.id ?? null;
  const ac = new AbortController();
  return await new Promise<string>((resolve) => {
    let settled = false;
    void webPromise.then((choice) => {
      if (settled) return;
      settled = true;
      ac.abort(); // dismiss the native card
      resolve(choice);
    });
    void server
      .elicitInput(optionsToElicitSchema(prompt, options), { signal: ac.signal })
      .then((result) => {
        if (settled) return;
        const choice = elicitResultToChoice(result, options);
        if (choice === null) return; // decline / cancel / invalid: let the pane card win
        settled = true;
        if (decisionId) bridge.resolveDecision(decisionId, choice); // clears the pane card and resolves webPromise
        resolve(choice);
      })
      .catch(() => { /* aborted or transport error: the pane card and timeout remain */ });
  });
}
```

* [ ] Step: Run the orchestrator tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts`. Expected: PASS (the 8 mapper tests plus the 4 orchestrator tests).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/elicit.ts rpi-cockpit/tests/elicit.test.ts && git commit -m "feat(cockpit): race the pane card and native elicitation, first answer wins"`.

---

### Task 3: Wire into the MCP server and integration-test the real path

Files:

* Modify: `src/mcp.ts`
* Modify: `src/handlers.ts`
* Modify: `tests/handlers.test.ts`
* Modify: `tests/mcp.test.ts`

Interfaces:

```ts
// consumed
import { presentOptionsWithElicitation, decisionTimeoutMs } from "./elicit.js";
```

Steps:

* [ ] Step: In `src/mcp.ts`, add the import near the other local imports:

```ts
import { presentOptionsWithElicitation, decisionTimeoutMs, type ElicitFormParams } from "./elicit.js";
```

* [ ] Step: In `src/mcp.ts`, replace the `present_options` registration handler so it drives both surfaces. Replace this:

```ts
  server.registerTool(
    "present_options",
    { description: "Ask the user to choose; blocks until they pick.", inputSchema: { prompt: z.string(), options: z.array(OptionItem).min(1) } },
    async (a) => text(await handlers.present_options(bridge, a)),
  );
```

with:

```ts
  server.registerTool(
    "present_options",
    { description: "Ask the user to choose; blocks until they pick. Shows the in-pane card and, where the host supports it, a native choice card; the first answer wins.", inputSchema: { prompt: z.string(), options: z.array(OptionItem).min(1) } },
    async (a) =>
      text(
        await presentOptionsWithElicitation(
          {
            getClientCapabilities: () => server.server.getClientCapabilities(),
            elicitInput: (params: ElicitFormParams, opts) =>
              server.server.elicitInput(params as unknown as Parameters<typeof server.server.elicitInput>[0], opts),
          },
          bridge,
          a.prompt,
          a.options,
          decisionTimeoutMs(),
        ),
      ),
  );
```

The single cast on `params` is the adapter boundary between the cockpit's `ElicitFormParams` and the SDK's `ElicitRequestFormParams`; the orchestrator itself stays SDK-type-free and unit-tested.

* [ ] Step: In `src/handlers.ts`, remove the now-superseded `present_options` handler and the `decisionTimeoutMs` helper plus its `DEFAULT_DECISION_TIMEOUT_MS` constant (they moved to `src/elicit.ts`). Delete the `present_options:` property from the `handlers` object and delete the timeout helper lines at the top of the file. Leave every other handler unchanged.
* [ ] Step: In `tests/handlers.test.ts`, remove the test(s) that exercise `handlers.present_options` (its behavior is covered by `tests/elicit.test.ts`). Leave the other handler tests unchanged.
* [ ] Step: In `tests/mcp.test.ts`, add an integration test that exercises the real elicitation path with a mock client. Read the top of the file to match how it constructs the server, client, and the in-memory transport pair, then add this test in the existing top-level describe (adapt the connection setup to the file's existing helper if one exists):

```ts
import { ElicitRequestSchema } from "@modelcontextprotocol/sdk/types.js";

it("present_options resolves from a native elicitation when the host supports it", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const client = new Client(
    { name: "test-client", version: "0.0.1" },
    { capabilities: { elicitation: {} } },
  );
  client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { choice: "b" } }));
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

  const res = await client.callTool({
    name: "present_options",
    arguments: { prompt: "Which approach?", options: [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }] },
  });
  const out = (res.content as { type: string; text: string }[])[0].text;
  expect(out).toContain("b");

  await client.close();
  await server.close();
});
```

If `tests/mcp.test.ts` does not already import `Client`, `InMemoryTransport`, `buildMcpServer`, and `Bridge`, add them: `import { Client } from "@modelcontextprotocol/sdk/client/index.js";`, `import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";`, `import { buildMcpServer } from "../src/mcp.js";`, `import { Bridge } from "../src/bridge.js";`. If the file already has a helper that wires a client to the server, prefer that helper and only add the elicitation capability and the `ElicitRequestSchema` handler to the client it builds.

* [ ] Step: Type-check and run the full suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: `tsc` clean, all files green. If `tsc` flags the `params` cast, keep the single boundary cast in `mcp.ts` as written; do not push SDK types into `elicit.ts`. If the integration test cannot resolve `InMemoryTransport`, confirm the import path against the installed package (`node_modules/@modelcontextprotocol/sdk/dist/esm/inMemory.js`).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/mcp.ts rpi-cockpit/src/handlers.ts rpi-cockpit/tests/handlers.test.ts rpi-cockpit/tests/mcp.test.ts && git commit -m "feat(cockpit): present_options drives the native elicitation card alongside the pane"`.

## Self-Review

Spec coverage:

* Both surfaces, first answer wins: Task 2 orchestrator races `bridge.presentOptions` and `server.elicitInput`, resolves on the first, and dismisses the loser (abort on web win, `resolveDecision` on elicit win). Task 3 wires it into `present_options`.
* Capability fallback: the orchestrator returns the pane-only promise when `getClientCapabilities()?.elicitation` is absent (Task 2 test "no elicitation capability"); the integration test (Task 3) covers the capability-present path.
* Decline or cancel does not resolve: `elicitResultToChoice` returns null for non-accept results (Task 1), and the orchestrator ignores null (Task 2 test "a declined elicitation does not resolve").
* Timeout fallback preserved: the orchestrator passes `timeoutMs` straight into `bridge.presentOptions`, whose existing recommended-option timeout is unchanged; an elicitation in flight is aborted when the timeout resolves the web promise.
* Secure defaults: no change to the pane card, the token gate, or the iframe sandbox.

Placeholder scan: every code step contains complete code grounded in the extracted SDK contract (oneOf const/title schema, `ElicitResult.action`/`content.choice`, `getClientCapabilities()?.elicitation`, the `signal` abort, and the `setRequestHandler(ElicitRequestSchema, ...)` mock client). The one place left to the implementer (matching `tests/mcp.test.ts`'s existing client/transport helper) is explicitly a "match the existing pattern" instruction, not a code placeholder.

Type consistency: `ElicitFormParams` is produced by `optionsToElicitSchema` and consumed by `ElicitCapableServer.elicitInput` and the `mcp.ts` adapter (which casts once to the SDK's `ElicitRequestFormParams`). `elicitResultToChoice` takes the SDK's `ElicitResult` and returns `string | null`. `decisionTimeoutMs` moves from `handlers.ts` to `elicit.ts` and is imported by `mcp.ts`. The chosen value returned by the orchestrator is always a valid option id (the web path returns an id; the elicit path only resolves through `elicitResultToChoice`, which validates membership).

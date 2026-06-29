<!-- markdownlint-disable -->
# Flow Canvas (gh-aw pipeline) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `flow` loop view: an n8n-style node canvas for the gh-aw agent (#58) that renders the agentic-workflow pipeline (workflows as nodes, label/event handoffs as Bezier edges), drills into a single workflow's anatomy, and animates a live run, driven by four new MCP tools.

**Architecture:** A new `flow` domain peer to the other loop views. Four beats (`flow.open`, `flownode.add`, `flowedge.add`, `flow.focus`) and five state fields (`flowTitle`, `flowNodes`, `flowEdges`, `flowFocus`) feed a pure `flow` view-model projection; four MCP tools emit the beats; a `#flow-view` renders a pannable/zoomable node canvas with cards + ports + SVG Bezier edges + a minimap + an inspector, using a pure `computeFlowLayout` (layered longest-path, back-edge tolerant). Live-run = re-upserting nodes/edges with a new `status`. The agent narrates topology and status; the client computes layout and renders.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/flow-canvas-design.md`.

## Global Constraints

* `FlowNode = { id: string; scope: string; kind: FlowNodeKind; label: string; sub?: string; status: FlowStatus }`; `FlowNodeKind = "workflow" | "trigger" | "guard" | "agent" | "output" | "mcp"`; `FlowStatus = "idle" | "running" | "passed" | "failed" | "skipped" | "stale"`.
* `FlowEdge = { id: string; from: string; to: string; scope: string; label?: string; kind: FlowEdgeKind; status: FlowEdgeStatus }`; `FlowEdgeKind = "label" | "event" | "output" | "step"`; `FlowEdgeStatus = "idle" | "active"`.
* State fields: `flowTitle: string | null`, `flowNodes: FlowNode[]`, `flowEdges: FlowEdge[]`, `flowFocus: string | null`.
* The MCP tool count goes from 41 to 45. Update the assertion in `tests/mcp.test.ts`.
* `flownode.add` / `flowedge.add` upsert by `id` IN PLACE (preserve order on update; append a new id). Node `scope` defaults `"orchestration"`, `status` defaults `"idle"`. Edge `scope` defaults `"orchestration"`, `kind` defaults `"label"`, `status` defaults `"idle"`. `flow.open` clears both arrays and resets `flowFocus` to null. `flow.focus` sets `flowFocus` to the given workflow id or null.
* The view-model is a pure pass-through (null-coalesce `sub`/`label`); LAYOUT is computed in the client (`computeFlowLayout`), never in `toViewModel`.
* `computeFlowLayout(nodes, edges)` is a PURE function returning `{ [id]: { x, y } }`; it must be back-edge tolerant (a feedback edge must not change forward layering and must not loop forever).
* TypeScript strict; no new `any`; ESM `.js` import specifiers; keep the `summarize(beat)` switch exhaustive.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper. Status/kind reach the DOM only as enum-locked class suffixes.
* Keep the global `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beats, state, and view-model

**Files:**
* Modify: `src/events.ts` (add the four beats)
* Modify: `src/state.ts` (domain union; the six types; the four fields; `initialState`; the four reducer arms; the four `summarize` arms)
* Modify: `src/render.ts` (domain union; `ViewModel.flow`; the projection)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces: beats `{ type: "flow.open"; title?: string }`, `{ type: "flownode.add"; id; kind; label; scope?; sub?; status? }`, `{ type: "flowedge.add"; id; from; to; scope?; label?; kind?; status? }`, `{ type: "flow.focus"; workflow?: string | null }`; the state fields + types; `ViewModel.flow: { title: string | null; focus: string | null; nodes: { id; scope; kind; label; sub: string | null; status }[]; edges: { id; from; to; scope; label: string | null; kind; status }[] }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("flow", () => {
  it("flow.open sets title, clears nodes/edges, resets focus", () => {
    let s = applyBeat(initialState(), { type: "flownode.add", id: "x", kind: "workflow", label: "old" }, 1);
    s = applyBeat(s, { type: "flow.focus", workflow: "x" }, 2);
    s = applyBeat(s, { type: "flow.open", title: "hve-core pipeline" }, 3);
    expect(s.domain).toBe("flow");
    expect(s.view).toBe("loop");
    expect(s.flowTitle).toBe("hve-core pipeline");
    expect(s.flowNodes).toEqual([]);
    expect(s.flowEdges).toEqual([]);
    expect(s.flowFocus).toBeNull();
  });
  it("flownode.add appends, defaults scope/status, and a same-id add updates in place", () => {
    let s = applyBeat(initialState(), { type: "flow.open" }, 1);
    s = applyBeat(s, { type: "flownode.add", id: "triage", kind: "workflow", label: "Issue Triage" }, 2);
    s = applyBeat(s, { type: "flownode.add", id: "impl", kind: "workflow", label: "Implement", status: "running" }, 3);
    s = applyBeat(s, { type: "flownode.add", id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot", status: "passed" }, 4);
    expect(s.flowNodes.map((n) => n.id)).toEqual(["triage", "impl"]);
    expect(s.flowNodes[0]).toEqual({ id: "triage", scope: "orchestration", kind: "workflow", label: "Issue Triage", sub: "copilot", status: "passed" });
    expect(s.flowNodes[1].status).toBe("running");
  });
  it("flowedge.add appends, defaults scope/kind/status, upserts by id", () => {
    let s = applyBeat(initialState(), { type: "flow.open" }, 1);
    s = applyBeat(s, { type: "flowedge.add", id: "e1", from: "triage", to: "impl", label: "agent-ready" }, 2);
    s = applyBeat(s, { type: "flowedge.add", id: "e1", from: "triage", to: "impl", label: "agent-ready", status: "active" }, 3);
    expect(s.flowEdges).toEqual([{ id: "e1", from: "triage", to: "impl", scope: "orchestration", label: "agent-ready", kind: "label", status: "active" }]);
  });
  it("flow.focus sets and clears the focus", () => {
    let s = applyBeat(initialState(), { type: "flow.open" }, 1);
    s = applyBeat(s, { type: "flow.focus", workflow: "triage" }, 2);
    expect(s.flowFocus).toBe("triage");
    s = applyBeat(s, { type: "flow.focus" }, 3);
    expect(s.flowFocus).toBeNull();
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects the flow graph as pure data", () => {
  let s = applyBeat(initialState(), { type: "flow.open", title: "p" }, 1);
  s = applyBeat(s, { type: "flownode.add", id: "a", kind: "workflow", label: "Triage" }, 2);
  s = applyBeat(s, { type: "flownode.add", id: "t", kind: "trigger", label: "issue", scope: "a" }, 3);
  s = applyBeat(s, { type: "flowedge.add", id: "e", from: "a", to: "a", label: "self", kind: "event", status: "active" }, 4);
  s = applyBeat(s, { type: "flow.focus", workflow: "a" }, 5);
  const vm = toViewModel(s);
  expect(vm.domain).toBe("flow");
  expect(vm.flow.title).toBe("p");
  expect(vm.flow.focus).toBe("a");
  expect(vm.flow.nodes[0]).toEqual({ id: "a", scope: "orchestration", kind: "workflow", label: "Triage", sub: null, status: "idle" });
  expect(vm.flow.nodes[1]).toMatchObject({ id: "t", scope: "a", kind: "trigger" });
  expect(vm.flow.edges[0]).toEqual({ id: "e", from: "a", to: "a", scope: "orchestration", label: "self", kind: "event", status: "active" });
  expect(toViewModel(initialState()).flow.title).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement `src/events.ts`**

Add to the `Beat` union (after the `handoff.add` member from the memory feature):

```ts
  z.object({ type: z.literal("flow.open"), title: z.string().optional() }),
  z.object({ type: z.literal("flownode.add"), id: z.string(), kind: z.enum(["workflow", "trigger", "guard", "agent", "output", "mcp"]), label: z.string(), scope: z.string().optional(), sub: z.string().optional(), status: z.enum(["idle", "running", "passed", "failed", "skipped", "stale"]).optional() }),
  z.object({ type: z.literal("flowedge.add"), id: z.string(), from: z.string(), to: z.string(), scope: z.string().optional(), label: z.string().optional(), kind: z.enum(["label", "event", "output", "step"]).optional(), status: z.enum(["idle", "active"]).optional() }),
  z.object({ type: z.literal("flow.focus"), workflow: z.string().nullable().optional() }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the types near the other interfaces (e.g. after `MemoryHandoff`):

```ts
export type FlowNodeKind = "workflow" | "trigger" | "guard" | "agent" | "output" | "mcp";
export type FlowStatus = "idle" | "running" | "passed" | "failed" | "skipped" | "stale";
export interface FlowNode { id: string; scope: string; kind: FlowNodeKind; label: string; sub?: string; status: FlowStatus; }
export type FlowEdgeKind = "label" | "event" | "output" | "step";
export type FlowEdgeStatus = "idle" | "active";
export interface FlowEdge { id: string; from: string; to: string; scope: string; label?: string; kind: FlowEdgeKind; status: FlowEdgeStatus; }
```

In the `domain` union add `"flow"`:

```ts
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | "gallery" | "promptlab" | "memory" | "flow" | null;
```

Add four fields to `SessionState` (near `memoryHandoffs`):

```ts
  flowTitle: string | null;
  flowNodes: FlowNode[];
  flowEdges: FlowEdge[];
  flowFocus: string | null;
```

In `initialState()`, add `flowTitle: null, flowNodes: [], flowEdges: [], flowFocus: null`.

Add the reducer arms (after the `handoff.add` arm):

```ts
    case "flow.open":
      return { ...s, view: "loop", domain: "flow", flowTitle: beat.title ?? null, flowNodes: [], flowEdges: [], flowFocus: null, log };
    case "flownode.add": {
      const n = { id: beat.id, scope: beat.scope ?? "orchestration", kind: beat.kind, label: beat.label, sub: beat.sub, status: beat.status ?? "idle" };
      const exists = s.flowNodes.some((x) => x.id === beat.id);
      return { ...s, flowNodes: exists ? s.flowNodes.map((x) => (x.id === beat.id ? n : x)) : [...s.flowNodes, n], log };
    }
    case "flowedge.add": {
      const e = { id: beat.id, from: beat.from, to: beat.to, scope: beat.scope ?? "orchestration", label: beat.label, kind: beat.kind ?? "label", status: beat.status ?? "idle" };
      const exists = s.flowEdges.some((x) => x.id === beat.id);
      return { ...s, flowEdges: exists ? s.flowEdges.map((x) => (x.id === beat.id ? e : x)) : [...s.flowEdges, e], log };
    }
    case "flow.focus":
      return { ...s, flowFocus: beat.workflow ?? null, log };
```

In the `summarize(beat)` switch, add four arms:

```ts
    case "flow.open": return beat.title ?? "flow";
    case "flownode.add": return beat.label;
    case "flowedge.add": return beat.id;
    case "flow.focus": return beat.workflow ?? "(orchestration)";
```

* [ ] **Step 5: Implement `src/render.ts`**

In the `ViewModel` `domain` union add `"flow"`. Add the `flow` field to the `ViewModel` interface (near `memory`):

```ts
  flow: { title: string | null; focus: string | null; nodes: { id: string; scope: string; kind: string; label: string; sub: string | null; status: string }[]; edges: { id: string; from: string; to: string; scope: string; label: string | null; kind: string; status: string }[] };
```

In `toViewModel`, add to the returned object (near `memory`):

```ts
    flow: {
      title: s.flowTitle,
      focus: s.flowFocus,
      nodes: s.flowNodes.map((n) => ({ id: n.id, scope: n.scope, kind: n.kind, label: n.label, sub: n.sub ?? null, status: n.status })),
      edges: s.flowEdges.map((e) => ({ id: e.id, from: e.from, to: e.to, scope: e.scope, label: e.label ?? null, kind: e.kind, status: e.status })),
    },
```

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: new tests PASS; tsc clean; suite green.

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): flow domain state, beats, and view-model"
```

---

### Task 2: MCP tools and handlers

**Files:**
* Modify: `src/handlers.ts` (four handlers)
* Modify: `src/mcp.ts` (register four tools)
* Test: `tests/mcp.test.ts`

**Interfaces:**
* Consumes: the Task 1 beats.
* Produces: tools `flow_open({ title? })`, `add_flow_node({ id, kind, label, scope?, sub?, status? })`, `add_flow_edge({ id, from, to, scope?, label?, kind?, status? })`, `flow_focus({ workflow? })`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` (build the client inline, matching the existing style):

```ts
it("flow tools drive the canvas and reject bad enums", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);

  await client.callTool({ name: "flow_open", arguments: { title: "hve-core pipeline" } });
  await client.callTool({ name: "add_flow_node", arguments: { id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot" } });
  await client.callTool({ name: "add_flow_node", arguments: { id: "impl", kind: "workflow", label: "Implement" } });
  await client.callTool({ name: "add_flow_edge", arguments: { id: "e1", from: "triage", to: "impl", label: "agent-ready" } });
  await client.callTool({ name: "flow_focus", arguments: { workflow: "triage" } });
  expect(bridge.state.domain).toBe("flow");
  expect(bridge.state.flowTitle).toBe("hve-core pipeline");
  expect(bridge.state.flowNodes.map((n) => n.id)).toEqual(["triage", "impl"]);
  expect(bridge.state.flowEdges[0]).toMatchObject({ from: "triage", to: "impl", label: "agent-ready", kind: "label" });
  expect(bridge.state.flowFocus).toBe("triage");

  const badKind = await client.callTool({ name: "add_flow_node", arguments: { id: "x", kind: "bogus", label: "x" } });
  expect(badKind.isError).toBe(true);
  const badStatus = await client.callTool({ name: "add_flow_node", arguments: { id: "y", kind: "workflow", label: "y", status: "bogus" } });
  expect(badStatus.isError).toBe(true);
  const badEdgeKind = await client.callTool({ name: "add_flow_edge", arguments: { id: "z", from: "triage", to: "impl", kind: "bogus" } });
  expect(badEdgeKind.isError).toBe(true);
});
```

In the tool-count test, change `expect(tools).toHaveLength(41)` to `45` and add `expect(names).toContain(...)` for `flow_open`, `add_flow_node`, `add_flow_edge`, `flow_focus`.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (count 41; tools missing).

* [ ] **Step 3: Implement `src/handlers.ts`**

Add the type imports (these live in `state.ts`):

```ts
import type { FlowNodeKind, FlowStatus, FlowEdgeKind, FlowEdgeStatus } from "./state.js";
```

Add (next to the memory handlers):

```ts
  flow_open: (b: Bridge, a: { title?: string }) => {
    b.emitBeat({ type: "flow.open", title: a.title });
    return `flow canvas opened${a.title ? `: ${a.title}` : ""}`;
  },
  add_flow_node: (b: Bridge, a: { id: string; kind: FlowNodeKind; label: string; scope?: string; sub?: string; status?: FlowStatus }) => {
    b.emitBeat({ type: "flownode.add", id: a.id, kind: a.kind, label: a.label, scope: a.scope, sub: a.sub, status: a.status });
    return `flow node ${a.id} (${a.kind})`;
  },
  add_flow_edge: (b: Bridge, a: { id: string; from: string; to: string; scope?: string; label?: string; kind?: FlowEdgeKind; status?: FlowEdgeStatus }) => {
    b.emitBeat({ type: "flowedge.add", id: a.id, from: a.from, to: a.to, scope: a.scope, label: a.label, kind: a.kind, status: a.status });
    return `flow edge ${a.from} -> ${a.to}`;
  },
  flow_focus: (b: Bridge, a: { workflow?: string | null }) => {
    b.emitBeat({ type: "flow.focus", workflow: a.workflow ?? null });
    return `flow focus: ${a.workflow ?? "(orchestration)"}`;
  },
```

* [ ] **Step 4: Implement `src/mcp.ts`**

Register the four tools (after the memory tools):

```ts
  server.registerTool(
    "flow_open",
    { description: "Open the flow canvas (the gh-aw agentic-workflow pipeline as a node graph) and switch the cockpit to it. Optionally name the pipeline. Clears nodes/edges and the drill focus.", inputSchema: { title: z.string().optional() } },
    async (a) => text(handlers.flow_open(bridge, a)),
  );
  server.registerTool(
    "add_flow_node",
    { description: "Add or update one FLOW NODE (a node in the pipeline graph, not a kanban item). kind is workflow (an orchestration-level workflow) or trigger/guard/agent/output/mcp (an anatomy element inside one workflow). For an anatomy node set scope to the workflow node's id; orchestration nodes leave scope default. status (idle/running/passed/failed/skipped/stale) drives the live-run look; sub is a short subtitle.", inputSchema: { id: z.string(), kind: z.enum(["workflow", "trigger", "guard", "agent", "output", "mcp"]), label: z.string(), scope: z.string().optional(), sub: z.string().optional(), status: z.enum(["idle", "running", "passed", "failed", "skipped", "stale"]).optional() } },
    async (a) => text(handlers.add_flow_node(bridge, a)),
  );
  server.registerTool(
    "add_flow_edge",
    { description: "Add or update one FLOW EDGE between two node ids. kind: label or event or output (orchestration handoffs) or step (anatomy). label is the handoff (e.g. a label name like agent-ready). status active animates the edge during a live run. Set scope to a workflow id for an anatomy edge; orchestration edges leave scope default.", inputSchema: { id: z.string(), from: z.string(), to: z.string(), scope: z.string().optional(), label: z.string().optional(), kind: z.enum(["label", "event", "output", "step"]).optional(), status: z.enum(["idle", "active"]).optional() } },
    async (a) => text(handlers.add_flow_edge(bridge, a)),
  );
  server.registerTool(
    "flow_focus",
    { description: "Drill the flow canvas to a workflow's anatomy by its node id, or omit / pass null to return to the orchestration pipeline. Use during a debug narration to pull the pane to a failing workflow.", inputSchema: { workflow: z.string().nullable().optional() } },
    async (a) => text(handlers.flow_focus(bridge, a)),
  );
```

* [ ] **Step 5: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; suite green (tool count now 45).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): flow_open, add_flow_node, add_flow_edge, flow_focus MCP tools"
```

---

### Task 3: The pure layout function (computeFlowLayout)

**Files:**
* Modify: `public/client.js` (add `computeFlowLayout` near the other render helpers; nothing else this task)
* Test: `tests/flow-layout.test.ts` (new)

**Interfaces:**
* Produces: `computeFlowLayout(nodes, edges)` returning `{ [id]: { x, y } }` for the given node set (positions in world px). Layered longest-path, back-edge tolerant, first-seen within-layer order.

* [ ] **Step 1: Write the failing test**

Create `tests/flow-layout.test.ts` (boot harness, then call the function via `win`):

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");
function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}
const layout = (win: any, nodes: any[], edges: any[]) => win.computeFlowLayout(nodes, edges);
const N = (id: string) => ({ id, scope: "orchestration", kind: "workflow", label: id, status: "idle" });
const E = (id: string, from: string, to: string) => ({ id, from, to, scope: "orchestration", kind: "label", status: "idle" });

describe("computeFlowLayout", () => {
  let win: any;
  beforeEach(() => { win = boot(); });

  it("lays a linear chain into increasing columns", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "b", "c")]);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.x).toBeLessThan(pos.c.x);
  });

  it("places fan-out targets in the same later column, different rows", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "a", "c")]);
    expect(pos.b.x).toBe(pos.c.x);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.y).not.toBe(pos.c.y);
  });

  it("tolerates a back edge: forward layering is unchanged and it terminates", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "b", "c"), E("e3", "c", "a")]);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.x).toBeLessThan(pos.c.x);
  });
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/flow-layout.test.ts`
Expected: FAIL (`computeFlowLayout` not defined).

* [ ] **Step 3: Implement `computeFlowLayout` in `public/client.js`**

Add near the other helpers (above `renderFlow`, which arrives in Task 4):

```js
// Pure layered layout for the flow canvas: longest-path layering on the DAG formed by
// dropping back edges (so a feedback handoff such as needs-revision -> implement does not
// change forward layering or loop), first-seen order within a layer. Returns world px.
function computeFlowLayout(nodes, edges) {
  const COL_W = 240, ROW_H = 120;
  const ids = nodes.map((n) => n.id);
  const idx = new Map(ids.map((id, i) => [id, i]));
  const idSet = new Set(ids);
  const adj = new Map(ids.map((id) => [id, []]));
  for (const e of edges) if (idSet.has(e.from) && idSet.has(e.to) && e.from !== e.to) adj.get(e.from).push(e.to);
  // 1. classify back edges via DFS gray-coloring
  const color = new Map(); // 1 = on stack, 2 = done
  const back = new Set();
  const stack = [];
  for (const root of ids) {
    if (color.get(root)) continue;
    stack.push([root, 0]);
    while (stack.length) {
      const frame = stack[stack.length - 1];
      const [u, i] = frame;
      if (i === 0) color.set(u, 1);
      const kids = adj.get(u);
      if (i < kids.length) {
        frame[1]++;
        const v = kids[i];
        const c = color.get(v);
        if (c === 1) back.add(u + ">" + v);
        else if (!c) stack.push([v, 0]);
      } else {
        color.set(u, 2);
        stack.pop();
      }
    }
  }
  // 2. DAG (non-back edges) + indegree
  const dag = new Map(ids.map((id) => [id, []]));
  const indeg = new Map(ids.map((id) => [id, 0]));
  for (const u of ids) for (const v of adj.get(u)) {
    if (back.has(u + ">" + v)) continue;
    dag.get(u).push(v); indeg.set(v, indeg.get(v) + 1);
  }
  // 3. Kahn topo + longest-path layer
  const layer = new Map(ids.map((id) => [id, 0]));
  const din = new Map(indeg);
  let q = ids.filter((id) => din.get(id) === 0).sort((a, b) => idx.get(a) - idx.get(b));
  while (q.length) {
    const u = q.shift();
    for (const v of dag.get(u)) {
      if (layer.get(u) + 1 > layer.get(v)) layer.set(v, layer.get(u) + 1);
      din.set(v, din.get(v) - 1);
      if (din.get(v) === 0) q.push(v);
    }
  }
  // 4. position: column = layer, row = first-seen order within layer
  const byLayer = new Map();
  for (const id of ids) {
    const L = layer.get(id);
    if (!byLayer.has(L)) byLayer.set(L, []);
    byLayer.get(L).push(id);
  }
  const pos = {};
  for (const [L, members] of byLayer) {
    members.sort((a, b) => idx.get(a) - idx.get(b));
    members.forEach((id, i) => { pos[id] = { x: L * COL_W, y: i * ROW_H }; });
  }
  return pos;
}
```

* [ ] **Step 4: Run the test, then node check + whole suite**

Run: `npx vitest run tests/flow-layout.test.ts && node --check public/client.js && npx vitest run`
Expected: 3/3 PASS; node check clean; suite green.

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/public/client.js rpi-cockpit/tests/flow-layout.test.ts
git commit -m "feat(cockpit): computeFlowLayout (layered, back-edge tolerant) for the flow canvas"
```

---

### Task 4: Canvas shell, camera, node cards, routing

**Files:**
* Modify: `public/index.html` (the `#flow-view` markup + CSS for canvas/world/node/port/legend; the camera background)
* Modify: `public/client.js` (`renderFlow` node rendering; the camera module state + pan/zoom/fit; the routing branch; hide `#flow-view` in every other domain branch + the review/default tail)
* Test: `tests/flow-client.test.ts` (new; node-rendering + routing portion)

**Interfaces:**
* Consumes: `ViewModel.flow` (Task 1) and `computeFlowLayout` (Task 3).
* Produces: a `#flow-view` shown when `v.domain === "flow"`; `#gw-world` holding `.gw-node.gw-k-{kind}.gw-s-{status}` cards positioned from the layout; a camera (`gwCam`) applied as a CSS transform; pan (drag background) and wheel-zoom.

* [ ] **Step 1: Write the failing test**

Create `tests/flow-client.test.ts` (mirror `tests/memory-client.test.ts` boot):

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");
function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}
function flowVm() {
  let s = applyBeat(initialState(), { type: "flow.open", title: "hve-core pipeline" }, 1);
  s = applyBeat(s, { type: "flownode.add", id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot", status: "passed" }, 2);
  s = applyBeat(s, { type: "flownode.add", id: "impl", kind: "workflow", label: "Implement", sub: "copilot", status: "running" }, 3);
  s = applyBeat(s, { type: "flowedge.add", id: "e1", from: "triage", to: "impl", label: "agent-ready", status: "active" }, 4);
  // anatomy of triage
  s = applyBeat(s, { type: "flownode.add", id: "triage.t", kind: "trigger", label: "issues", scope: "triage" }, 5);
  s = applyBeat(s, { type: "flownode.add", id: "triage.a", kind: "agent", label: "triage agent", scope: "triage" }, 6);
  s = applyBeat(s, { type: "flowedge.add", id: "triage.e", from: "triage.t", to: "triage.a", scope: "triage", kind: "step" }, 7);
  return toViewModel(s);
}

describe("flow client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the flow view and hides the others on the flow domain", () => {
    (win as any).render(flowVm());
    expect((win.document.getElementById("flow-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("memory-view") as any).hidden).toBe(true);
  });

  it("renders orchestration workflow nodes with kind + status classes", () => {
    (win as any).render(flowVm());
    const nodes = win.document.querySelectorAll("#gw-world .gw-node");
    expect(nodes.length).toBe(2); // only orchestration scope at the top level
    expect(win.document.querySelector("#gw-world .gw-k-workflow.gw-s-passed")).not.toBeNull();
    expect(win.document.querySelector("#gw-world .gw-k-workflow.gw-s-running")).not.toBeNull();
    expect((win.document.getElementById("gw-title") as any).textContent).toContain("hve-core pipeline");
  });
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/flow-client.test.ts`
Expected: FAIL (no `#flow-view`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

Add the view as a sibling of `#memory-view` (after it, inside `#loop`):

```html
    <section id="flow-view" hidden>
      <div class="rev-head">
        <button type="button" id="gw-back" class="gw-back" hidden>&larr; Pipeline</button>
        <span class="board-target" id="gw-title">Flow</span>
      </div>
      <div class="gw-stage">
        <div class="gw-legend" id="gw-legend"></div>
        <div class="gw-canvas" id="gw-canvas">
          <div class="gw-world" id="gw-world"></div>
          <div class="gw-minimap" id="gw-minimap" hidden></div>
        </div>
        <aside class="gw-inspector" id="gw-inspector" hidden></aside>
      </div>
    </section>
```

Add the CSS (next to the other view rules). Node kind colors + status looks + ports + camera:

```css
  #flow-view { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
  .gw-back { font: inherit; font-size: 11px; background: var(--layer, #252526); color: var(--text-2, #9D9D9D); border: 1px solid var(--stroke, #3C3C3C); border-radius: 6px; padding: 2px 9px; cursor: pointer; margin-right: 10px; }
  .gw-stage { flex: 1; min-height: 0; display: flex; }
  .gw-legend { flex: 0 0 120px; padding: 12px; border-right: 1px solid var(--stroke, #3C3C3C); display: flex; flex-direction: column; gap: 7px; font-size: 11px; }
  .gw-legend .gw-leg { display: flex; align-items: center; gap: 7px; color: var(--text-2, #9D9D9D); }
  .gw-legend .gw-dot { width: 9px; height: 9px; border-radius: 3px; }
  .gw-canvas { flex: 1 1 0; min-width: 0; position: relative; overflow: hidden; background:
    radial-gradient(circle, var(--stroke, #3C3C3C) 1px, transparent 1px) 0 0 / 22px 22px; cursor: grab; }
  .gw-canvas.grabbing { cursor: grabbing; }
  .gw-world { position: absolute; top: 0; left: 0; transform-origin: 0 0; will-change: transform; }
  .gw-node { position: absolute; width: 180px; border: 1px solid var(--stroke-2, #4A4A4A); border-radius: 9px; background: var(--layer, #252526); box-shadow: var(--shadow-4); overflow: hidden; cursor: pointer; }
  .gw-node.gw-sel { outline: 2px solid var(--brand, #0E639C); }
  .gw-node .gw-head { display: flex; align-items: center; gap: 8px; padding: 7px 10px; font-weight: 600; font-size: 12.5px; border-left: 3px solid var(--stroke-2, #4A4A4A); }
  .gw-node .gw-body { padding: 6px 10px 9px; font-size: 11px; color: var(--text-3, #6E6E6E); }
  .gw-glyph { width: 16px; text-align: center; }
  .gw-port { position: absolute; top: 50%; width: 9px; height: 9px; border-radius: 50%; background: var(--stroke-2, #4A4A4A); transform: translateY(-50%); }
  .gw-port.gw-in { left: -5px; } .gw-port.gw-out { right: -5px; }
  /* kind accents */
  .gw-k-workflow .gw-head { border-left-color: var(--accent-blue, #4FC1FF); }
  .gw-k-trigger .gw-head { border-left-color: #C9A9F0; }
  .gw-k-guard .gw-head { border-left-color: #E0954B; }
  .gw-k-agent .gw-head { border-left-color: var(--accent-cyan, #9CDCFE); }
  .gw-k-output .gw-head { border-left-color: var(--ok, #73C991); }
  .gw-k-mcp .gw-head { border-left-color: var(--text-3, #6E6E6E); }
  /* status */
  .gw-s-running { border-color: var(--accent-blue, #4FC1FF); animation: gwpulse 1.4s ease-in-out infinite; }
  .gw-s-passed { border-color: var(--ok, #73C991); }
  .gw-s-failed { border-color: var(--fail, #f2b8b5); }
  .gw-s-skipped { opacity: .55; }
  .gw-s-stale { border-color: #E0954B; }
  @keyframes gwpulse { 0%,100% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--accent-blue,#4FC1FF) 50%, transparent); } 50% { box-shadow: 0 0 0 5px transparent; } }
```

* [ ] **Step 4: Implement `public/client.js`**

Add module state near the other view vars:

```js
// Flow canvas camera + interaction state. The agent narrates topology (v.flow); the client
// lays it out (computeFlowLayout), renders cards into #gw-world, and applies a 2D camera.
let gwCam = { x: 40, y: 40, z: 1 };
let gwFocusOverride = undefined; // undefined = follow server; string|null = local drill
let gwServerFocus = null;        // last server focus seen, to detect new narration
let gwSel = null;                // selected node id
const GW_GLYPH = { workflow: "▦", trigger: "⊙", guard: "⚿", agent: "✦", output: "▣", mcp: "⚙" };
```

In `render(v)`, after the memory view lookup add `const flowView = document.getElementById("flow-view");`. Add `if (flowView) flowView.hidden = true;` to EVERY other domain branch (codemap, team, backlog, dataprofile, gallery, promptlab, memory, interview) and the review/default tail. Add the `flow` branch (next to `memory`):

```js
    if (v.domain === "flow") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = false;
      renderFlow(v);
      return;
    }
```

Add `renderFlow` and helpers (after `renderMemory`). This task renders nodes + legend + title + applies the camera; edges/minimap/inspector/drill arrive in Tasks 5 and 6 (leave `gw-edges` rendering and the minimap to the later tasks, but compute the active set here):

```js
function gwActiveFocus(v) {
  // server narration wins when it changes; otherwise the local drill override holds.
  if (v.flow.focus !== gwServerFocus) { gwServerFocus = v.flow.focus; gwFocusOverride = undefined; }
  return gwFocusOverride !== undefined ? gwFocusOverride : v.flow.focus;
}

function gwApplyCam() {
  const world = document.getElementById("gw-world");
  if (world) world.style.transform = `translate(${gwCam.x}px, ${gwCam.y}px) scale(${gwCam.z})`;
}

function renderFlow(v) {
  const f = v.flow || { title: null, focus: null, nodes: [], edges: [] };
  const focus = gwActiveFocus(v);
  setText("gw-title", focus ? `${f.title || "Flow"}  ·  ${focus}` : (f.title || "Flow"));
  const back = document.getElementById("gw-back");
  if (back) back.hidden = !focus;
  const scope = focus || "orchestration";
  const nodes = f.nodes.filter((n) => n.scope === scope);
  const edges = f.edges.filter((e) => e.scope === scope);
  // legend
  setHtml("gw-legend", ["workflow", "trigger", "guard", "agent", "output", "mcp"].map((k) =>
    `<div class="gw-leg"><span class="gw-dot gw-k-${k}" style="background:currentColor"></span>${k}</div>`).join(""));
  // layout + node cards
  const pos = computeFlowLayout(nodes, edges);
  const world = document.getElementById("gw-world");
  if (!world) return;
  world.innerHTML = nodes.map((n) => {
    const p = pos[n.id] || { x: 0, y: 0 };
    return `<figure class="gw-node gw-k-${esc(n.kind)} gw-s-${esc(n.status)}${n.id === gwSel ? " gw-sel" : ""}" data-gw="${esc(n.id)}" data-kind="${esc(n.kind)}" style="left:${p.x}px;top:${p.y}px">
      <span class="gw-port gw-in"></span>
      <figcaption class="gw-head"><span class="gw-glyph">${GW_GLYPH[n.kind] || "•"}</span>${esc(n.label)}</figcaption>
      ${n.sub ? `<div class="gw-body">${esc(n.sub)}</div>` : ""}
      <span class="gw-port gw-out"></span>
    </figure>`;
  }).join("");
  gwApplyCam();
  // (edges + minimap + inspector are rendered in Tasks 5-6)
}
```

Add the camera pan/zoom wiring once (a delegated set, near the other top-level listeners). Pan on the canvas background; wheel to zoom:

```js
(function gwCameraWiring() {
  let dragging = false, lx = 0, ly = 0;
  document.addEventListener("pointerdown", (e) => {
    const canvas = e.target.closest && e.target.closest("#gw-canvas");
    if (!canvas || e.target.closest(".gw-node") || e.target.closest("#gw-minimap")) return;
    dragging = true; lx = e.clientX; ly = e.clientY; canvas.classList.add("grabbing");
  });
  document.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    gwCam.x += e.clientX - lx; gwCam.y += e.clientY - ly; lx = e.clientX; ly = e.clientY; gwApplyCam();
  });
  document.addEventListener("pointerup", () => { dragging = false; const c = document.getElementById("gw-canvas"); if (c) c.classList.remove("grabbing"); });
  document.addEventListener("wheel", (e) => {
    const canvas = e.target.closest && e.target.closest("#gw-canvas");
    if (!canvas) return;
    e.preventDefault();
    const r = canvas.getBoundingClientRect();
    const mx = e.clientX - r.left, my = e.clientY - r.top;
    const nz = Math.min(2, Math.max(0.3, gwCam.z * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
    // zoom around cursor: keep the world point under the cursor fixed
    gwCam.x = mx - (mx - gwCam.x) * (nz / gwCam.z);
    gwCam.y = my - (my - gwCam.y) * (nz / gwCam.z);
    gwCam.z = nz; gwApplyCam();
  }, { passive: false });
})();
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/flow-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: the two flow-client tests PASS; the rest green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/flow-client.test.ts
git commit -m "feat(cockpit): flow canvas shell, camera, node cards, and routing"
```

---

### Task 5: SVG Bezier edges + live-run animation

**Files:**
* Modify: `public/index.html` (edge SVG CSS: stroke, arrowhead, active animation, edge label)
* Modify: `public/client.js` (`renderFlow` gains an SVG edge layer drawing Bezier paths port-to-port; active edges animate)
* Test: `tests/flow-client.test.ts` (add an edges spec)

**Interfaces:**
* Consumes: the active edges from Task 4 and the layout positions.
* Produces: an `<svg id="gw-edges">` inside `#gw-world` with one `<path class="gw-edge gw-e-{kind}">` per active edge (cubic Bezier from the source out-port to the target in-port), an arrowhead marker, the edge label, and a `gw-active` class for firing edges.

* [ ] **Step 1: Write the failing test**

Add to `tests/flow-client.test.ts`:

```ts
it("renders an SVG bezier path per edge, with the active class on a firing edge", () => {
  (win as any).render(flowVm());
  const paths = win.document.querySelectorAll("#gw-edges path.gw-edge");
  expect(paths.length).toBe(1); // one orchestration edge (triage -> impl)
  expect(win.document.querySelector("#gw-edges path.gw-edge.gw-active")).not.toBeNull();
  // edge label rendered
  expect((win.document.getElementById("gw-edges") as any).textContent).toContain("agent-ready");
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/flow-client.test.ts`
Expected: the new spec FAILS (no `#gw-edges`).

* [ ] **Step 3: CSS in `public/index.html`**

Add (next to the `.gw-*` rules):

```css
  #gw-edges { position: absolute; top: 0; left: 0; overflow: visible; pointer-events: none; }
  .gw-edge { fill: none; stroke: var(--stroke-2, #4A4A4A); stroke-width: 1.5; }
  .gw-edge.gw-e-label { stroke: var(--accent-blue, #4FC1FF); }
  .gw-edge.gw-e-output { stroke: var(--ok, #73C991); }
  .gw-edge.gw-active { stroke: var(--accent-blue, #4FC1FF); stroke-width: 2.5; stroke-dasharray: 6 5; animation: gwdash 0.6s linear infinite; }
  @keyframes gwdash { to { stroke-dashoffset: -22; } }
  .gw-elabel { font-size: 10.5px; fill: var(--text-2, #9D9D9D); }
```

* [ ] **Step 4: Implement the edge layer in `renderFlow` (`public/client.js`)**

Replace the `world.innerHTML = nodes.map(...)` assignment so the SVG edge layer is built first (under the nodes), using the same `pos`. The node dimensions are width 180, header+body height about 64; use a fixed `NODE_W = 180`, `NODE_H = 64` for port anchors. Insert before the node cards:

```js
  const NODE_W = 180, NODE_H = 64;
  const anchor = (id, side) => {
    const p = pos[id] || { x: 0, y: 0 };
    return { x: p.x + (side === "out" ? NODE_W : 0), y: p.y + NODE_H / 2 };
  };
  // bounding box for the svg canvas size
  let maxX = 0, maxY = 0;
  for (const id in pos) { maxX = Math.max(maxX, pos[id].x + NODE_W); maxY = Math.max(maxY, pos[id].y + NODE_H); }
  const edgesSvg = edges.map((e) => {
    const a = anchor(e.from, "out"), b = anchor(e.to, "in");
    const k = Math.max(40, Math.abs(b.x - a.x) * 0.4);
    const d = `M ${a.x} ${a.y} C ${a.x + k} ${a.y}, ${b.x - k} ${b.y}, ${b.x} ${b.y}`;
    const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - 6 };
    return `<path class="gw-edge gw-e-${esc(e.kind)}${e.status === "active" ? " gw-active" : ""}" d="${d}" marker-end="url(#gw-arrow)"></path>`
      + (e.label ? `<text class="gw-elabel" x="${mid.x}" y="${mid.y}" text-anchor="middle">${esc(e.label)}</text>` : "");
  }).join("");
  const svg = `<svg id="gw-edges" width="${maxX + 40}" height="${maxY + 40}">
    <defs><marker id="gw-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--stroke-2, #4A4A4A)"></path></marker></defs>${edgesSvg}</svg>`;
  const nodesHtml = nodes.map((n) => { /* unchanged node card markup from Task 4 */ }).join("");
  world.innerHTML = svg + nodesHtml;
```

Keep the node-card markup exactly as in Task 4; only the assignment order changes (SVG first so edges sit under the cards). `gwApplyCam()` still runs after.

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/flow-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green (3 flow-client specs now).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/flow-client.test.ts
git commit -m "feat(cockpit): flow canvas SVG bezier edges + live-run animation"
```

---

### Task 6: Drill-in, inspector, minimap

**Files:**
* Modify: `public/index.html` (inspector + minimap CSS)
* Modify: `public/client.js` (click handling: drill-in on a workflow node, back control, node select -> inspector; render the inspector; render + wire the minimap)
* Test: `tests/flow-client.test.ts` (add drill-in + inspector specs)

**Interfaces:**
* Consumes: the rendered canvas (Tasks 4-5).
* Produces: clicking a `workflow`-kind node sets `gwFocusOverride` to its id and re-renders the anatomy; `#gw-back` clears it; clicking any node sets `gwSel` and fills `#gw-inspector`; a `#gw-minimap` shows scaled node dots + a viewport rect and recenters the camera on click.

* [ ] **Step 1: Write the failing test**

Add to `tests/flow-client.test.ts`:

```ts
it("drills into a workflow's anatomy on click and back returns to orchestration", () => {
  (win as any).render(flowVm());
  (win.document.querySelector('#gw-world .gw-node[data-kind="workflow"][data-gw="triage"]') as any)
    .dispatchEvent(new win.Event("click", { bubbles: true }));
  // now showing triage anatomy: trigger + agent nodes, no workflow nodes
  expect(win.document.querySelector('#gw-world .gw-k-workflow')).toBeNull();
  expect(win.document.querySelectorAll('#gw-world .gw-node').length).toBe(2);
  expect((win.document.getElementById("gw-back") as any).hidden).toBe(false);
  (win.document.getElementById("gw-back") as any).dispatchEvent(new win.Event("click", { bubbles: true }));
  expect(win.document.querySelectorAll('#gw-world .gw-k-workflow').length).toBe(2);
});

it("selects a node and shows it in the inspector", () => {
  (win as any).render(flowVm());
  (win.document.querySelector('#gw-world .gw-node[data-gw="impl"]') as any)
    .dispatchEvent(new win.Event("click", { bubbles: true }));
  const insp = win.document.getElementById("gw-inspector") as any;
  expect(insp.hidden).toBe(false);
  expect(insp.textContent).toContain("Implement");
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/flow-client.test.ts`
Expected: the two new specs FAIL.

* [ ] **Step 3: CSS in `public/index.html`**

```css
  .gw-inspector { flex: 0 0 240px; min-width: 0; overflow: auto; border-left: 1px solid var(--stroke, #3C3C3C); padding: 12px; font-size: 12px; }
  .gw-inspector .gw-i-label { font-weight: 600; font-size: 13px; }
  .gw-inspector .gw-i-row { margin-top: 8px; color: var(--text-2, #9D9D9D); }
  .gw-inspector .gw-i-k { color: var(--text-3, #6E6E6E); text-transform: uppercase; font-size: 10px; letter-spacing: .04em; }
  .gw-minimap { position: absolute; right: 10px; bottom: 10px; width: 160px; height: 110px; background: color-mix(in srgb, var(--layer, #252526) 88%, transparent); border: 1px solid var(--stroke, #3C3C3C); border-radius: 6px; overflow: hidden; cursor: pointer; }
  .gw-minimap .gw-mm-node { position: absolute; width: 6px; height: 4px; border-radius: 1px; background: var(--text-3, #6E6E6E); }
  .gw-minimap .gw-mm-view { position: absolute; border: 1px solid var(--accent-blue, #4FC1FF); background: color-mix(in srgb, var(--accent-blue, #4FC1FF) 12%, transparent); }
```

* [ ] **Step 4: Implement in `public/client.js`**

In `renderFlow`, after building the world, render the inspector and minimap. Add a `gwRenderInspector(nodes)` and `gwRenderMinimap(pos)` and call them; store the active `pos`/`nodes` on module vars so the click handler and minimap can use them:

```js
let gwPos = {}, gwNodes = [];
```

At the end of `renderFlow` (after `gwApplyCam()`):

```js
  gwPos = pos; gwNodes = nodes;
  gwRenderInspector();
  gwRenderMinimap();
```

Add:

```js
function gwRenderInspector() {
  const insp = document.getElementById("gw-inspector");
  if (!insp) return;
  const n = gwNodes.find((x) => x.id === gwSel);
  if (!n) { insp.hidden = true; insp.innerHTML = ""; return; }
  insp.hidden = false;
  insp.innerHTML = `<div class="gw-i-label">${esc(n.label)}</div>
    <div class="gw-i-row"><span class="gw-i-k">kind</span><br>${esc(n.kind)}</div>
    <div class="gw-i-row"><span class="gw-i-k">status</span><br>${esc(n.status)}</div>
    ${n.sub ? `<div class="gw-i-row"><span class="gw-i-k">detail</span><br>${esc(n.sub)}</div>` : ""}`;
}

function gwRenderMinimap() {
  const mm = document.getElementById("gw-minimap");
  const canvas = document.getElementById("gw-canvas");
  if (!mm || !canvas) return;
  const ids = Object.keys(gwPos);
  if (ids.length === 0) { mm.hidden = true; return; }
  mm.hidden = false;
  const NODE_W = 180, NODE_H = 64;
  let maxX = 0, maxY = 0;
  for (const id of ids) { maxX = Math.max(maxX, gwPos[id].x + NODE_W); maxY = Math.max(maxY, gwPos[id].y + NODE_H); }
  const pad = 8, mw = 160 - pad * 2, mh = 110 - pad * 2;
  const s = Math.min(mw / (maxX || 1), mh / (maxY || 1));
  const dots = ids.map((id) => `<span class="gw-mm-node" style="left:${pad + gwPos[id].x * s}px;top:${pad + gwPos[id].y * s}px"></span>`).join("");
  // viewport rect: the canvas-visible world region under the current camera
  const r = canvas.getBoundingClientRect();
  const vx = -gwCam.x / gwCam.z, vy = -gwCam.y / gwCam.z;
  const vw = r.width / gwCam.z, vh = r.height / gwCam.z;
  const view = `<span class="gw-mm-view" style="left:${pad + vx * s}px;top:${pad + vy * s}px;width:${vw * s}px;height:${vh * s}px"></span>`;
  mm.innerHTML = dots + view;
  mm.dataset.scale = String(s); mm.dataset.pad = String(pad);
}
```

In the delegated click handler, add (near the other view handlers):

```js
  const gwBack = e.target.closest("#gw-back");
  if (gwBack) { gwFocusOverride = null; const w = lastView; if (w) renderFlow(w); return; }
  const gwNode = e.target.closest(".gw-node[data-gw]");
  if (gwNode) {
    const id = gwNode.getAttribute("data-gw");
    gwSel = id;
    if (gwNode.getAttribute("data-kind") === "workflow") gwFocusOverride = id; // drill in
    if (lastView) renderFlow(lastView);
    return;
  }
  const gwMini = e.target.closest("#gw-minimap");
  if (gwMini) {
    const r = gwMini.getBoundingClientRect();
    const s = parseFloat(gwMini.dataset.scale || "1"), pad = parseFloat(gwMini.dataset.pad || "8");
    const wx = (e.clientX - r.left - pad) / s, wy = (e.clientY - r.top - pad) / s;
    const c = document.getElementById("gw-canvas").getBoundingClientRect();
    gwCam.x = c.width / 2 - wx * gwCam.z; gwCam.y = c.height / 2 - wy * gwCam.z; gwApplyCam(); gwRenderMinimap();
    return;
  }
  const gwBg = e.target.closest("#gw-canvas");
  if (gwBg && !e.target.closest(".gw-node")) { if (gwSel !== null) { gwSel = null; if (lastView) renderFlow(lastView); } /* fallthrough to allow pan */ }
```

This needs `lastView`: the client must retain the last view-model so re-renders (drill, select) can rebuild. If the client does not already keep one, add `let lastView = null;` and set `lastView = v;` at the top of `render(v)`. (Reuse an existing last-view-model variable if one already exists.)

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/flow-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green (5 flow-client specs).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js
git commit -m "feat(cockpit): flow canvas drill-in, inspector, and minimap"
```

---

### Task 7: Agent contract for the flow canvas

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:**
* Consumes: nothing in code; the narration contract.

* [ ] **Step 1: Edit the contract**

Add a new section (after the memory section or near the meta-utility mappings):

```markdown
## Agentic workflows (the flow canvas)

* `flow_open(title?)` opens the flow canvas (the gh-aw pipeline as a node graph) and switches the cockpit to it. The GitHub Agentic Workflows agent calls this when it begins working a pipeline.
* `add_flow_node(id, kind, label, scope?, sub?, status?)` adds or updates one node. Use `kind: workflow` (scope orchestration, the default) for each workflow in the pipeline, and `kind` trigger/guard/agent/output/mcp with `scope` set to a workflow's node id for that workflow's anatomy. `status` (idle/running/passed/failed/skipped/stale) drives the live-run look.
* `add_flow_edge(id, from, to, scope?, label?, kind?, status?)` wires two nodes. Orchestration handoffs use `kind` label/event/output with the handoff `label` (for example a label name like `agent-ready`); anatomy steps use `kind: step`. Set `status: active` on the edge currently firing.
* Narrate a live run by re-calling `add_flow_node` / `add_flow_edge` with a new `status` as the pipeline fires, and `flow_focus(workflow)` to drill the pane into a workflow (or `flow_focus()` to return to the pipeline), for example to show where a run failed.
* This surface narrates and the user steers (via `check_directives`); it does not author or run workflows. The agent edits the `.md` and runs `gh aw compile` / `logs` / `audit` itself.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`.

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): agentic-workflows narration contract (flow canvas)"
```

---

## Final verification (after Task 7)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live in a RESTARTED consumer pane: drive a producer that narrates the 5-workflow hve-core pipeline (triage -> implement -> pr-review, plus dependency-pr-review and doc-update-check) with label edges, then animates a run (set a node running, its outgoing edge active, then passed; step to the next), then `flow_focus` into one workflow to show its anatomy. Confirm: nodes lay out in columns, Bezier edges with arrowheads + labels connect them, the running node pulses and the active edge animates, pan/zoom works, the minimap reflects the camera, clicking a workflow drills into its anatomy and back returns, and clicking a node fills the inspector.
* [ ] Push to `fork` and open a PR.

## Self-Review

**Spec coverage:** the `flow` domain + state (Task 1); the four beats + tools with kind/status validation (Tasks 1, 2); the pure `computeFlowLayout` (Task 3); the `#flow-view` canvas + camera + node cards + routing (Task 4); SVG Bezier edges + live-run animation (Task 5); drill-in + inspector + minimap (Task 6); the agent contract (Task 7). Deferred items (authoring/round-trip, compile-from-pane, crossing-minimization, manual reposition, lock-file preview) correctly absent.

**Placeholder scan:** every code step shows complete code. Task 5 references "the Task 4 node-card markup unchanged" rather than repeating it (the only back-reference; the markup is fully given in Task 4). Task 6 notes reusing an existing last-view-model variable if present, else adding `lastView`. No TBD/TODO.

**Type consistency:** `FlowNode`/`FlowEdge` and the four enums are identical across the beat zod enums (events.ts), the state interfaces (state.ts), the tool inputSchemas (mcp.ts), and the handler arg types (handlers.ts). The view-model widens kind/status to `string` and null-coalesces `sub`/`label`, consumed consistently by the client and asserted in the render test (Task 1) and client tests (Tasks 4-6). `computeFlowLayout` returns `{ [id]: {x,y} }`, consumed by `renderFlow` and the minimap. The names `flow_open`/`add_flow_node`/`add_flow_edge`/`flow_focus`/`flow.open`/`flownode.add`/`flowedge.add`/`flow.focus`/`renderFlow`/`computeFlowLayout`/`#flow-view`/`#gw-world`/`#gw-edges`/`#gw-minimap`/`#gw-inspector`/`gw-node`/`gw-k-{kind}`/`gw-s-{status}`/`gw-edge`/`gw-e-{kind}`/`gw-active` are consistent across all tasks.

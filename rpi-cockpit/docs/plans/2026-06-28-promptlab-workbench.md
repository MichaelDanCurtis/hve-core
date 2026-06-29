<!-- markdownlint-disable -->
# Prompt Workbench (promptlab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `promptlab` loop view: a behavior test bench for the Prompt Builder cluster, rendering a table of scenarios with the literal output the Tester produced and a pass/warn/fail verdict, driven by two new MCP tools.

**Architecture:** A new `promptlab` domain peer to review/backlog/dataprofile/gallery. Two new beats (`promptlab.start`, `case.add`) and four state fields (`promptName`, `promptRound`, `promptArtifact`, `promptCases`) feed a `promptlab` view-model projection with a derived verdict summary; two new MCP tools (`promptlab_start`, `add_case`) emit the beats; a new `#promptlab-view` renders a header summary + an expandable case table + a secondary prompt panel, with domain routing exactly like the existing views.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/promptlab-workbench-design.md`.

## Global Constraints

* `PromptCase = { id: string; scenario: string; output?: string; verdict: PromptVerdict; note?: string }`.
* `PromptVerdict = "pending" | "running" | "pass" | "warn" | "fail"` (a zod enum at the tool boundary; an out-of-enum value is rejected).
* State fields: `promptName: string | null`, `promptRound: number` (default 1), `promptArtifact: string | null`, `promptCases: PromptCase[]`.
* The MCP tool count goes from 36 to 38 (two new tools; none removed). Update the assertion in `tests/mcp.test.ts`.
* `case.add` upserts by `id` IN PLACE (preserves order on update; appends a new id). `verdict` defaults to `"pending"` when omitted.
* `promptlab.start` sets name/round/prompt and CLEARS `promptCases` (a fresh run); `round` defaults to 1.
* The view-model `summary` is derived by counting case verdicts: `{ pass, warn, fail, pending, running, total }`.
* TypeScript strict; no new `any`; ESM `.js` import specifiers in all `src/` imports; keep the `summarize(beat)` switch exhaustive.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* Keep the global `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beats, state, and view-model

**Files:**
* Modify: `src/events.ts` (add the two beats to the `Beat` union)
* Modify: `src/state.ts` (domain union; `PromptCase`/`PromptVerdict` types; the four fields; `initialState`; the two reducer arms; the two `summarize` arms)
* Modify: `src/render.ts` (domain union; `ViewModel.promptlab`; the `toViewModel` projection with the derived summary)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces:
  * Beats `{ type: "promptlab.start"; name: string; prompt?: string; round?: number }` and `{ type: "case.add"; id: string; scenario: string; output?: string; verdict?: PromptVerdict; note?: string }`.
  * `SessionState.promptName`/`promptRound`/`promptArtifact`/`promptCases`, `PromptCase`, `PromptVerdict`.
  * `ViewModel.promptlab: { name: string | null; round: number; prompt: string | null; summary: { pass: number; warn: number; fail: number; pending: number; running: number; total: number }; cases: { id: string; scenario: string; output: string | null; verdict: string; note: string | null }[] }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("promptlab", () => {
  it("promptlab.start sets name/round/prompt and clears cases", () => {
    let s = applyBeat(initialState(), { type: "case.add", id: "x", scenario: "old", verdict: "pass" }, 1);
    s = applyBeat(s, { type: "promptlab.start", name: "summarizer.prompt", prompt: "You are…", round: 2 }, 2);
    expect(s.domain).toBe("promptlab");
    expect(s.view).toBe("loop");
    expect(s.promptName).toBe("summarizer.prompt");
    expect(s.promptArtifact).toBe("You are…");
    expect(s.promptRound).toBe(2);
    expect(s.promptCases).toEqual([]);
  });
  it("promptlab.start defaults round to 1 and prompt to null", () => {
    const s = applyBeat(initialState(), { type: "promptlab.start", name: "p" }, 1);
    expect(s.promptRound).toBe(1);
    expect(s.promptArtifact).toBeNull();
  });
  it("case.add appends, defaults verdict to pending, and a same-id add updates in place (order preserved)", () => {
    let s = applyBeat(initialState(), { type: "promptlab.start", name: "p" }, 1);
    s = applyBeat(s, { type: "case.add", id: "c1", scenario: "empty input" }, 2);
    s = applyBeat(s, { type: "case.add", id: "c2", scenario: "long input" }, 3);
    s = applyBeat(s, { type: "case.add", id: "c1", scenario: "empty input", output: "(nothing)", verdict: "fail", note: "no guard" }, 4);
    expect(s.promptCases.map((c) => c.id)).toEqual(["c1", "c2"]);
    expect(s.promptCases[0]).toEqual({ id: "c1", scenario: "empty input", output: "(nothing)", verdict: "fail", note: "no guard" });
    expect(s.promptCases[1].verdict).toBe("pending");
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects the promptlab bench with a derived verdict summary", () => {
  let s = applyBeat(initialState(), { type: "promptlab.start", name: "p", prompt: "txt", round: 3 }, 1);
  s = applyBeat(s, { type: "case.add", id: "a", scenario: "s1", output: "o1", verdict: "pass" }, 2);
  s = applyBeat(s, { type: "case.add", id: "b", scenario: "s2", verdict: "fail", note: "bad" }, 3);
  s = applyBeat(s, { type: "case.add", id: "c", scenario: "s3" }, 4);
  const vm = toViewModel(s);
  expect(vm.domain).toBe("promptlab");
  expect(vm.promptlab.name).toBe("p");
  expect(vm.promptlab.round).toBe(3);
  expect(vm.promptlab.prompt).toBe("txt");
  expect(vm.promptlab.summary).toEqual({ pass: 1, warn: 0, fail: 1, pending: 1, running: 0, total: 3 });
  expect(vm.promptlab.cases[1]).toEqual({ id: "b", scenario: "s2", output: null, verdict: "fail", note: "bad" });
  expect(toViewModel(initialState()).promptlab.name).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL (beats/fields/projection not defined).

* [ ] **Step 3: Implement `src/events.ts`**

Add to the `Beat` union (after the `gallery.clear` member):

```ts
  z.object({ type: z.literal("promptlab.start"), name: z.string(), prompt: z.string().optional(), round: z.number().int().optional() }),
  z.object({ type: z.literal("case.add"), id: z.string(), scenario: z.string(), output: z.string().optional(), verdict: z.enum(["pending", "running", "pass", "warn", "fail"]).optional(), note: z.string().optional() }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the types near the other interfaces (e.g. after `GalleryItem`):

```ts
export type PromptVerdict = "pending" | "running" | "pass" | "warn" | "fail";
export interface PromptCase { id: string; scenario: string; output?: string; verdict: PromptVerdict; note?: string; }
```

In the `domain` union add `"promptlab"`:

```ts
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | "gallery" | "promptlab" | null;
```

Add four fields to `SessionState` (near `galleryItems`):

```ts
  promptName: string | null;
  promptRound: number;
  promptArtifact: string | null;
  promptCases: PromptCase[];
```

In `initialState()`, add `promptName: null, promptRound: 1, promptArtifact: null, promptCases: []` to the returned object.

Add the reducer arms (after the `gallery.clear` arm):

```ts
    case "promptlab.start":
      return { ...s, view: "loop", domain: "promptlab", promptName: beat.name, promptArtifact: beat.prompt ?? null, promptRound: beat.round ?? 1, promptCases: [], log };
    case "case.add": {
      const c = { id: beat.id, scenario: beat.scenario, output: beat.output, verdict: beat.verdict ?? "pending", note: beat.note };
      const exists = s.promptCases.some((x) => x.id === beat.id);
      return { ...s, promptCases: exists ? s.promptCases.map((x) => (x.id === beat.id ? c : x)) : [...s.promptCases, c], log };
    }
```

In the `summarize(beat)` switch, add two arms (keep it exhaustive):

```ts
    case "promptlab.start": return beat.name;
    case "case.add": return beat.scenario;
```

* [ ] **Step 5: Implement `src/render.ts`**

In the `ViewModel` `domain` union add `"promptlab"`. Add the `promptlab` field to the `ViewModel` interface (near `gallery`):

```ts
  promptlab: { name: string | null; round: number; prompt: string | null; summary: { pass: number; warn: number; fail: number; pending: number; running: number; total: number }; cases: { id: string; scenario: string; output: string | null; verdict: string; note: string | null }[] };
```

In `toViewModel`, add to the returned object (near `gallery`):

```ts
    promptlab: {
      name: s.promptName,
      round: s.promptRound,
      prompt: s.promptArtifact,
      summary: s.promptCases.reduce(
        (a, c) => { a[c.verdict]++; a.total++; return a; },
        { pass: 0, warn: 0, fail: 0, pending: 0, running: 0, total: 0 },
      ),
      cases: s.promptCases.map((c) => ({ id: c.id, scenario: c.scenario, output: c.output ?? null, verdict: c.verdict, note: c.note ?? null })),
    },
```

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green. (If a test exact-matches the full `ViewModel`, add `promptlab`; none is expected.)

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): promptlab domain state, beats, and view-model"
```

---

### Task 2: MCP tools and handlers

**Files:**
* Modify: `src/handlers.ts` (add `promptlab_start` and `add_case` handlers)
* Modify: `src/mcp.ts` (register the two tools)
* Test: `tests/mcp.test.ts` (round trip + tool count + rejection)

**Interfaces:**
* Consumes: the `promptlab.start` / `case.add` beats from Task 1.
* Produces: tools `promptlab_start({ name, prompt?, round? })` and `add_case({ id, scenario, output?, verdict?, note? })`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` a round-trip test (build the client inline, matching the existing tests' style):

```ts
it("promptlab_start + add_case drive the workbench and reject a bad verdict", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);

  await client.callTool({ name: "promptlab_start", arguments: { name: "summarizer.prompt", prompt: "You are…", round: 2 } });
  await client.callTool({ name: "add_case", arguments: { id: "c1", scenario: "empty input", output: "(nothing)", verdict: "fail", note: "no guard" } });
  expect(bridge.state.domain).toBe("promptlab");
  expect(bridge.state.promptName).toBe("summarizer.prompt");
  expect(bridge.state.promptRound).toBe(2);
  expect(bridge.state.promptCases[0]).toMatchObject({ id: "c1", scenario: "empty input", verdict: "fail" });

  const bad = await client.callTool({ name: "add_case", arguments: { id: "c2", scenario: "x", verdict: "bogus" } });
  expect(bad.isError).toBe(true);
});
```

In the tool-count test, change `expect(tools).toHaveLength(36)` to `38` and add `expect(names).toContain("promptlab_start")` and `expect(names).toContain("add_case")`.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (tools not registered; count is 36).

* [ ] **Step 3: Implement `src/handlers.ts`**

Add the `PromptVerdict` import to the existing events import:

```ts
import type { AgentStatus, CodeKind, OptionItem, Phase, PromptVerdict, Severity, TouchKind, ValidationStatus } from "./events.js";
```

(If `PromptVerdict` is exported from `state.ts` rather than `events.ts`, import it from there; it is defined in `state.ts` per Task 1, so use `import type { PromptVerdict } from "./state.js";` instead, and keep the events import unchanged.)

Add (next to the dataprofile handlers):

```ts
  promptlab_start: (b: Bridge, a: { name: string; prompt?: string; round?: number }) => {
    b.emitBeat({ type: "promptlab.start", name: a.name, prompt: a.prompt, round: a.round });
    return `promptlab started: ${a.name}`;
  },
  add_case: (b: Bridge, a: { id: string; scenario: string; output?: string; verdict?: PromptVerdict; note?: string }) => {
    b.emitBeat({ type: "case.add", id: a.id, scenario: a.scenario, output: a.output, verdict: a.verdict, note: a.note });
    return `case ${a.id}: ${a.verdict ?? "pending"}`;
  },
```

* [ ] **Step 4: Implement `src/mcp.ts`**

Register the two tools (after the dataprofile tools):

```ts
  server.registerTool(
    "promptlab_start",
    { description: "Begin a prompt workbench (the behavior test bench); switches the cockpit to the promptlab view. Name the prompt being hardened; optionally give its current text and the iteration round (default 1). Re-call with round+1 for a fresh pass.", inputSchema: { name: z.string(), prompt: z.string().optional(), round: z.number().int().optional() } },
    async (a) => text(handlers.promptlab_start(bridge, a)),
  );

  server.registerTool(
    "add_case",
    { description: "Add or update one prompt TEST CASE in the workbench (a scenario the prompt is run on, not a kanban item). Give an id and the scenario; once the Tester runs it and the Evaluator judges, update the same id with the literal output, a verdict (pending/running/pass/warn/fail), and an optional note.", inputSchema: { id: z.string(), scenario: z.string(), output: z.string().optional(), verdict: z.enum(["pending", "running", "pass", "warn", "fail"]).optional(), note: z.string().optional() } },
    async (a) => text(handlers.add_case(bridge, a)),
  );
```

* [ ] **Step 5: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; whole suite green (tool-count assertion now 38).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): promptlab_start and add_case MCP tools"
```

---

### Task 3: The promptlab client view and routing

**Files:**
* Modify: `public/index.html` (the `#promptlab-view` markup + CSS)
* Modify: `public/client.js` (`renderPromptlab`; the routing branch; hide `#promptlab-view` in every other domain branch; the expand-on-click delegation)
* Test: `tests/promptlab-client.test.ts` (new)

**Interfaces:**
* Consumes: `ViewModel.promptlab` from Task 1.
* Produces: a `#promptlab-view` shown when `v.domain === "promptlab"`; a `#pl-cases` with one `.pc-case` per case; a `.pc-verdict.pc-v-{verdict}` pill per case; clicking a `.pc-head` toggles `.open` on its `.pc-case`.

* [ ] **Step 1: Write the failing test**

Create `tests/promptlab-client.test.ts` (mirror `tests/dataprofile-client.test.ts`'s `boot()` harness):

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
function benchVm() {
  let s = applyBeat(initialState(), { type: "promptlab.start", name: "summarizer.prompt", prompt: "You are a summarizer.", round: 2 }, 1);
  s = applyBeat(s, { type: "case.add", id: "c1", scenario: "empty input", output: "(produced nothing)", verdict: "fail", note: "no empty-input guard" }, 2);
  s = applyBeat(s, { type: "case.add", id: "c2", scenario: "long input", output: "ok summary", verdict: "pass" }, 3);
  return toViewModel(s);
}

describe("promptlab client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the promptlab view and hides the others on the promptlab domain", () => {
    (win as any).render(benchVm());
    expect((win.document.getElementById("promptlab-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("gallery-view") as any).hidden).toBe(true);
  });

  it("renders one case per scenario with a verdict pill, the prompt panel, and the summary", () => {
    (win as any).render(benchVm());
    const cases = win.document.querySelectorAll("#pl-cases .pc-case");
    expect(cases.length).toBe(2);
    expect(win.document.querySelector("#pl-cases .pc-v-fail")).not.toBeNull();
    expect(win.document.querySelector("#pl-cases .pc-v-pass")).not.toBeNull();
    expect((win.document.getElementById("pl-name") as any).textContent).toContain("summarizer.prompt");
    expect((win.document.getElementById("pl-prompt") as any).textContent).toContain("You are a summarizer.");
  });

  it("expands a case on click to reveal the full output", () => {
    (win as any).render(benchVm());
    const head = win.document.querySelector("#pl-cases .pc-case .pc-head") as any;
    head.dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.querySelector("#pl-cases .pc-case") as any).className).toContain("open");
  });
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/promptlab-client.test.ts`
Expected: FAIL (no `#promptlab-view`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

Add the view as a sibling of `#gallery-view` (after it, inside `#loop`):

```html
    <section id="promptlab-view" hidden>
      <div class="rev-head">
        <span class="board-target" id="pl-name">Prompt workbench</span>
        <span class="pl-summary" id="pl-summary"></span>
      </div>
      <div class="pl-body">
        <div id="pl-cases" class="pl-cases"></div>
        <aside class="pl-prompt-panel"><div class="sec">Prompt</div><pre id="pl-prompt" class="pl-prompt"></pre></aside>
      </div>
    </section>
```

Add the CSS (next to the `.dp-*` / `.gl-*` rules):

```css
  #promptlab-view { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
  .pl-summary { display: inline-flex; gap: 6px; margin-left: 12px; }
  .pl-chip { font-size: 11px; font-weight: 600; padding: 1px 8px; border-radius: 10px; background: var(--layer, #252526); border: 1px solid var(--stroke, #3C3C3C); }
  .pl-chip.pl-c-pass { color: var(--ok, #73C991); } .pl-chip.pl-c-warn { color: #E0954B; } .pl-chip.pl-c-fail { color: var(--fail, #f2b8b5); }
  .pl-body { flex: 1; min-height: 0; display: flex; gap: 16px; overflow: hidden; padding: 12px 18px; }
  .pl-cases { flex: 1 1 0; min-width: 0; overflow: auto; display: flex; flex-direction: column; gap: 8px; }
  .pl-prompt-panel { flex: 0 0 320px; min-width: 0; overflow: auto; border-left: 1px solid var(--stroke, #3C3C3C); padding-left: 14px; }
  .pl-prompt { white-space: pre-wrap; word-break: break-word; font-family: 'Cascadia Code','Segoe UI Mono',ui-monospace,monospace; font-size: 11.5px; color: var(--text-2, #9D9D9D); margin-top: 8px; }
  .pc-case { border: 1px solid var(--stroke, #3C3C3C); border-radius: 7px; background: var(--layer, #252526); overflow: hidden; }
  .pc-head { display: flex; align-items: center; gap: 12px; padding: 9px 12px; cursor: pointer; }
  .pc-scenario { font-weight: 600; font-size: 12.5px; flex: 0 0 34%; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .pc-preview { flex: 1 1 0; min-width: 0; color: var(--text-3, #6E6E6E); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .pc-verdict { flex: none; font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: 2px 9px; border-radius: 10px; }
  .pc-v-pass { background: var(--ok-bg, #16301F); color: var(--ok, #73C991); }
  .pc-v-warn { background: #2a1d11; color: #E0954B; }
  .pc-v-fail { background: var(--fail-bg, #3a1714); color: var(--fail, #f2b8b5); }
  .pc-v-running { background: var(--brand-2, #094771); color: var(--accent-blue, #4FC1FF); }
  .pc-v-pending { background: var(--layer-alt, #2D2D2D); color: var(--text-3, #6E6E6E); }
  .pc-body { display: none; border-top: 1px solid var(--stroke, #3C3C3C); padding: 10px 12px; }
  .pc-case.open .pc-body { display: block; }
  .pc-out { white-space: pre-wrap; word-break: break-word; font-family: 'Cascadia Code','Segoe UI Mono',ui-monospace,monospace; font-size: 11.5px; color: var(--text, #CCCCCC); }
  .pc-note { margin-top: 8px; font-size: 11.5px; color: #E0954B; }
  @media (max-width: 860px) { .pl-body { flex-direction: column; } .pl-prompt-panel { flex: none; border-left: none; border-top: 1px solid var(--stroke, #3C3C3C); padding-left: 0; padding-top: 12px; } }
```

* [ ] **Step 4: Implement `public/client.js`**

In `render(v)`, after `const galleryView = document.getElementById("gallery-view");` add:

```js
  const promptlabView = document.getElementById("promptlab-view");
```

In EACH existing domain branch (`codemap`, `team`, `backlog`, `dataprofile`, `gallery`, `interview`) and the review/default tail, add alongside the other hide lines:

```js
      if (promptlabView) promptlabView.hidden = true;
```

Add the new `promptlab` branch (place it next to the `gallery` branch):

```js
    if (v.domain === "promptlab") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = false;
      renderPromptlab(v);
      return;
    }
```

Add `renderPromptlab` (next to `renderDataProfile`):

```js
function renderPromptlab(v) {
  const p = v.promptlab || { name: null, round: 1, prompt: null, summary: { pass: 0, warn: 0, fail: 0, pending: 0, running: 0, total: 0 }, cases: [] };
  setText("pl-name", `${p.name || "Prompt workbench"}  ·  Round ${p.round}`);
  const sm = p.summary;
  const chip = (n, cls, label) => n > 0 ? `<span class="pl-chip ${cls}">${n} ${label}</span>` : "";
  setHtml("pl-summary", sm.total
    ? chip(sm.pass, "pl-c-pass", "pass") + chip(sm.warn, "pl-c-warn", "warn") + chip(sm.fail, "pl-c-fail", "fail")
      + chip(sm.running, "", "running") + chip(sm.pending, "", "pending")
    : "");
  setHtml("pl-cases", (p.cases || []).map((c) => {
    const preview = c.output ? esc(c.output.replace(/\s+/g, " ").slice(0, 120)) : "<span class=\"meta\">awaiting output…</span>";
    const body = `<div class="pc-body"><div class="pc-out">${c.output ? esc(c.output) : "No output yet."}</div>${c.note ? `<div class="pc-note">${esc(c.note)}</div>` : ""}</div>`;
    return `<div class="pc-case"><div class="pc-head"><span class="pc-scenario">${esc(c.scenario)}</span><span class="pc-preview">${preview}</span><span class="pc-verdict pc-v-${esc(c.verdict)}">${esc(c.verdict)}</span></div>${body}</div>`;
  }).join("") || `<div class="meta" style="padding:8px">No cases yet.</div>`);
  const pre = document.getElementById("pl-prompt");
  if (pre) pre.textContent = p.prompt || "";
}
```

In the existing delegated click handler (`document.addEventListener("click", (e) => { ... }`), add (before the home/loop handlers):

```js
  const pcHead = e.target.closest(".pc-head");
  if (pcHead && pcHead.parentElement) { pcHead.parentElement.classList.toggle("open"); return; }
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/promptlab-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/promptlab-client.test.ts
git commit -m "feat(cockpit): promptlab workbench view (case table + prompt panel) and routing"
```

---

### Task 4: Agent contract for the prompt workbench

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

Add a new section (after the gallery section or near the meta-utility mappings):

```markdown
## Prompt engineering (the prompt workbench)

* `promptlab_start(name, prompt?, round?)` opens the prompt workbench (a behavior test bench) and switches the cockpit to it. The Prompt Builder calls this when it begins hardening a prompt; pass the prompt's current text as `prompt` and the iteration round (default 1). Re-call with `round + 1` for a fresh pass.
* `add_case(id, scenario, output?, verdict?, note?)` adds or updates one test case. The Prompt Tester calls `add_case(id, scenario)` as it picks each scenario, then updates the same id with the literal output it produced, a verdict (pending/running/pass/warn/fail), and an optional note once it runs and the Prompt Evaluator judges.
* When the Prompt Evaluator's output is prompt-wide rather than per-case, it may still narrate severity findings via `review_start` + `add_finding`.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`. (Split a bullet if a line-length rule trips; keep asterisk bullets, no em-dashes.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): prompt-engineering narration contract (promptlab)"
```

---

## Final verification (after Task 4)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live in a RESTARTED consumer pane (a render.ts/state change requires a consumer restart, not just a browser reload): drive a producer that calls `promptlab_start` + several `add_case` (mixed verdicts incl. a pending and a fail with a note); confirm the case table renders with verdict pills + the summary chips, the prompt panel shows the text, and clicking a row expands the full output.
* [ ] Push to `fork` and open a PR.

## Self-Review

**Spec coverage:** the `promptlab` domain + state (Task 1) covered; the two beats + tools with verdict validation (Tasks 1, 2) covered; the derived-summary view-model projection (Task 1) covered; the `#promptlab-view` (header summary + case table + prompt panel) + routing + expand interaction (Task 3) covered; the agent contract (Task 4) covered. Deferred items (per-criterion scorecard, golden-output diffing, cross-round trend) correctly absent.

**Placeholder scan:** every code step shows complete code. The `PromptVerdict` import note in Task 2 gives the concrete fallback (`import type { PromptVerdict } from "./state.js"`). No TBD/TODO.

**Type consistency:** `PromptCase`/`PromptVerdict` are identical across the beat zod enum (events.ts), the state interface (state.ts), the tool inputSchema (mcp.ts), and the handler arg types (handlers.ts). The view-model widens `verdict` to `string` and null-coalesces `output`/`note`, used consistently by the client (Task 3) and asserted in the render test (Task 1) and client test (Task 3). The names `promptlab_start`/`add_case`/`promptlab.start`/`case.add`/`renderPromptlab`/`#promptlab-view`/`pl-cases`/`pc-case`/`pc-v-{verdict}` are consistent across all tasks. The derived `summary` keys (`pass`/`warn`/`fail`/`pending`/`running`/`total`) match the `PromptVerdict` values plus `total`.

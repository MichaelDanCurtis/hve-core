<!-- markdownlint-disable -->
# Decision Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cockpit's single decision card and interview question box with one navigable, revisitable decision-flow primitive, where answers happen in the inline chat and the cockpit shows and steers the chain.

**Architecture:** A `decisions` array in session state (each entry id/prompt/kind/options/answer/status) replaces the single `pendingDecision`/`pendingQuestion` slots. The existing blocking tools `present_options`/`ask_question` append (or re-open by id) an entry and resolve it to `answered`; a new `revise` inbound frame rolls an entry back to `pending` and marks downstream `superseded`, enqueuing a directive the agent acts on. The client renders the flow as a vertical list in the active loop view, replacing the old card and question box.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/decision-flow-design.md`.

## Global Constraints

* TypeScript strict; no new `any` beyond the one documented single-boundary cast in `src/mcp.ts`.
* ESM `.js` import specifiers in all `src/` imports.
* Do NOT commit `dist/` (gitignored). `src` changes require `npm run build` before the live pane reflects them.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* Keep the global `[hidden]{display:none!important}` rule and the iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until fully green before each commit.
* The MCP tool count stays 30 (this reworks existing tools, adds none).
* House markdown for any docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT (`/Volumes/Main External/Development/hve-core`), not from `rpi-cockpit/`.

---

### Task 1: Decision-flow state model and pure reducers

**Files:**
* Modify: `src/state.ts` (add types + `decisions`/`hostElicits` fields + pure functions; remove `pendingDecision`/`pendingQuestion` from `SessionState` and `initialState`)
* Test: `tests/state.test.ts`

**Interfaces:**
* Consumes: `OptionItem` from `./events.js`.
* Produces:
  * `type DecisionKind = "choice" | "text"`
  * `type DecisionStatus = "pending" | "answered" | "superseded"`
  * `interface DecisionEntry { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[]; answer?: string; status: DecisionStatus }`
  * `SessionState.decisions: DecisionEntry[]`, `SessionState.hostElicits: boolean`
  * `addDecision(s: SessionState, e: { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[] }): SessionState`
  * `answerDecision(s: SessionState, id: string, answer: string): SessionState`
  * `reviseDecision(s: SessionState, id: string): SessionState`
  * `setHostElicits(s: SessionState, v: boolean): SessionState`

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
import { addDecision, answerDecision, reviseDecision, setHostElicits, initialState } from "../src/state.js";

describe("decision flow", () => {
  const opts = [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }];

  it("addDecision appends a pending choice entry", () => {
    const s = addDecision(initialState(), { id: "d1", prompt: "Pick?", kind: "choice", options: opts });
    expect(s.decisions).toHaveLength(1);
    expect(s.decisions[0]).toMatchObject({ id: "d1", prompt: "Pick?", kind: "choice", status: "pending" });
    expect(s.decisions[0].options).toEqual(opts);
  });

  it("addDecision with an existing id re-opens it in place (clears the answer)", () => {
    let s = addDecision(initialState(), { id: "d1", prompt: "Pick?", kind: "choice", options: opts });
    s = answerDecision(s, "d1", "a");
    s = addDecision(s, { id: "d1", prompt: "Pick again?", kind: "choice", options: opts });
    expect(s.decisions).toHaveLength(1);
    expect(s.decisions[0]).toMatchObject({ id: "d1", prompt: "Pick again?", status: "pending" });
    expect(s.decisions[0].answer).toBeUndefined();
  });

  it("answerDecision marks the entry answered with the answer", () => {
    let s = addDecision(initialState(), { id: "q1", prompt: "Name?", kind: "text" });
    s = answerDecision(s, "q1", "Ada");
    expect(s.decisions[0]).toMatchObject({ status: "answered", answer: "Ada" });
  });

  it("reviseDecision re-opens the target and supersedes later answered entries", () => {
    let s = initialState();
    for (const id of ["d1", "d2", "d3"]) s = answerDecision(addDecision(s, { id, prompt: id, kind: "text" }), id, id + "ans");
    s = reviseDecision(s, "d1");
    expect(s.decisions.map((d) => d.status)).toEqual(["pending", "superseded", "superseded"]);
    expect(s.decisions[0].answer).toBeUndefined();
    expect(s.decisions[1].answer).toBe("d2ans"); // kept visible
  });

  it("reviseDecision on an unknown id is a no-op", () => {
    const s = answerDecision(addDecision(initialState(), { id: "d1", prompt: "x", kind: "text" }), "d1", "y");
    expect(reviseDecision(s, "nope")).toEqual(s);
  });

  it("setHostElicits toggles the flag", () => {
    expect(setHostElicits(initialState(), true).hostElicits).toBe(true);
  });
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts`
Expected: FAIL (functions/fields not defined).

* [ ] **Step 3: Implement in `src/state.ts`**

Add the imports/types near the top (after the existing `OptionItem` import):

```ts
export type DecisionKind = "choice" | "text";
export type DecisionStatus = "pending" | "answered" | "superseded";
export interface DecisionEntry { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[]; answer?: string; status: DecisionStatus; }
```

In `SessionState`, REMOVE `pendingDecision` and `pendingQuestion`, and ADD:

```ts
  decisions: DecisionEntry[];
  hostElicits: boolean;
```

In `initialState()`, remove `pendingDecision: null` and `pendingQuestion: null`, and add `decisions: [], hostElicits: false`.

Add the pure functions (near `enqueueDirective`):

```ts
export function addDecision(s: SessionState, e: { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[] }): SessionState {
  const i = s.decisions.findIndex((d) => d.id === e.id);
  const entry: DecisionEntry = { id: e.id, prompt: e.prompt, kind: e.kind, options: e.options, status: "pending" };
  if (i !== -1) return { ...s, decisions: s.decisions.map((d, j) => (j === i ? entry : d)) };
  return { ...s, decisions: [...s.decisions, entry] };
}

export function answerDecision(s: SessionState, id: string, answer: string): SessionState {
  return { ...s, decisions: s.decisions.map((d) => (d.id === id ? { ...d, answer, status: "answered" } : d)) };
}

export function reviseDecision(s: SessionState, id: string): SessionState {
  const idx = s.decisions.findIndex((d) => d.id === id);
  if (idx === -1) return s;
  return {
    ...s,
    decisions: s.decisions.map((d, j) => {
      if (j === idx) return { ...d, answer: undefined, status: "pending" };
      if (j > idx && d.status === "answered") return { ...d, status: "superseded" };
      return d;
    }),
  };
}

export function setHostElicits(s: SessionState, v: boolean): SessionState {
  return { ...s, hostElicits: v };
}
```

* [ ] **Step 4: Run to verify they pass**

Run: `npx vitest run tests/state.test.ts`
Expected: PASS. (Other suites will fail to compile until later tasks; that is expected mid-plan. Use `tsc` only after Task 5.)

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/state.ts rpi-cockpit/tests/state.test.ts
git commit -m "feat(cockpit): decision-flow state model (decisions array + pure reducers)"
```

---

### Task 2: Bridge integration (append/answer/revise, hostElicits, timeout)

**Files:**
* Modify: `src/bridge.ts` (rework `presentOptions`/`askQuestion`/`resolveDecision`/`resolveQuestion`; add `revise`/`setHostElicits`)
* Test: `tests/bridge.test.ts`

**Interfaces:**
* Consumes: `addDecision`, `answerDecision`, `reviseDecision`, `setHostElicits` from `./state.js`.
* Produces:
  * `bridge.presentOptions(prompt: string, options: OptionItem[], timeoutMs?: number, id?: string): Promise<string>`
  * `bridge.askQuestion(prompt: string, timeoutMs?: number, id?: string): Promise<string>`
  * `bridge.resolveDecision(id: string, choiceId: string): void` (unchanged signature)
  * `bridge.resolveQuestion(id: string, text: string): void` (unchanged signature)
  * `bridge.revise(id: string): void`
  * `bridge.setHostElicits(v: boolean): void`

* [ ] **Step 1: Write the failing tests**

Add to `tests/bridge.test.ts`:

```ts
it("presentOptions appends a pending choice decision and resolves to answered", async () => {
  const b = new Bridge();
  const p = b.presentOptions("Pick?", [{ id: "a", title: "A" }], 0, "d1");
  expect(b.state.decisions[0]).toMatchObject({ id: "d1", kind: "choice", status: "pending" });
  b.resolveDecision("d1", "a");
  await expect(p).resolves.toBe("a");
  expect(b.state.decisions[0]).toMatchObject({ status: "answered", answer: "a" });
});

it("askQuestion appends a pending text decision and resolves to answered", async () => {
  const b = new Bridge();
  const p = b.askQuestion("Name?", 0, "q1");
  b.resolveQuestion("q1", "Ada");
  await expect(p).resolves.toBe("Ada");
  expect(b.state.decisions[0]).toMatchObject({ kind: "text", status: "answered", answer: "Ada" });
});

it("revise re-opens a decision, supersedes downstream, and enqueues a directive", async () => {
  const b = new Bridge();
  b.resolveDecision("d1", "a"); // no-op guard
  const p1 = b.presentOptions("One?", [{ id: "a", title: "A" }], 0, "d1"); b.resolveDecision("d1", "a"); await p1;
  const p2 = b.askQuestion("Two?", 0, "q2"); b.resolveQuestion("q2", "x"); await p2;
  b.revise("d1");
  expect(b.state.decisions.map((d) => d.status)).toEqual(["pending", "superseded"]);
  expect(b.state.directives.at(-1)?.kind).toBe("note");
  expect((b.state.directives.at(-1) as { text: string }).text).toContain("revise");
});

it("presentOptions auto-resolves to the recommended option on timeout", async () => {
  const b = new Bridge();
  const p = b.presentOptions("Pick?", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 20, "d1");
  await expect(p).resolves.toBe("b");
});

it("setHostElicits sets the flag", () => {
  const b = new Bridge(); b.setHostElicits(true); expect(b.state.hostElicits).toBe(true);
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/bridge.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement in `src/bridge.ts`**

Import the new functions: `import { ..., addDecision, answerDecision, reviseDecision, setHostElicits } from "./state.js";`. Replace the `presentOptions`/`resolveDecision`/`askQuestion`/`resolveQuestion` bodies and add `revise`/`setHostElicits`:

```ts
presentOptions(prompt: string, options: OptionItem[], timeoutMs = 0, id?: string): Promise<string> {
  const did = id ?? `d${++this.seq}`;
  this.state = addDecision(this.state, { id: did, prompt, kind: "choice", options });
  this.emit("state", this.state);
  return new Promise<string>((resolve) => {
    this.pending.set(did, resolve);
    if (timeoutMs > 0) setTimeout(() => {
      if (this.pending.has(did)) {
        const fallback = options.find((o) => o.recommended)?.id ?? options[0]?.id;
        if (fallback !== undefined) this.resolveDecision(did, fallback);
      }
    }, timeoutMs);
  });
}

resolveDecision(id: string, choiceId: string): void {
  const resolve = this.pending.get(id);
  if (!resolve) return;
  this.pending.delete(id);
  const prompt = this.state.decisions.find((d) => d.id === id)?.prompt;
  this.state = answerDecision(this.state, id, choiceId);
  this.emit("state", this.state);
  resolve(choiceId);
  this.emit("decision", prompt === undefined ? { id, choiceId } : { id, choiceId, prompt });
}

askQuestion(prompt: string, timeoutMs = 0, id?: string): Promise<string> {
  const qid = id ?? `q${++this.seq}`;
  this.state = addDecision(this.state, { id: qid, prompt, kind: "text" });
  this.emit("state", this.state);
  return new Promise<string>((resolve) => {
    this.pending.set(qid, resolve);
    if (timeoutMs > 0) setTimeout(() => { if (this.pending.has(qid)) this.resolveQuestion(qid, ""); }, timeoutMs);
  });
}

resolveQuestion(id: string, text: string): void {
  const resolve = this.pending.get(id);
  if (!resolve) return;
  this.pending.delete(id);
  this.state = answerDecision(this.state, id, text);
  this.emit("state", this.state);
  resolve(text);
}

revise(id: string): void {
  const entry = this.state.decisions.find((d) => d.id === id);
  if (!entry) return;
  this.state = reviseDecision(this.state, id);
  this.emit("state", this.state);
  this.enqueueDirective({ kind: "note", text: `revise decision "${entry.prompt}" (id ${id}): re-ask it and reconsider what follows` });
}

setHostElicits(v: boolean): void {
  this.state = setHostElicits(this.state, v);
  this.emit("state", this.state);
}
```

* [ ] **Step 4: Run to verify they pass**

Run: `npx vitest run tests/bridge.test.ts`
Expected: PASS.

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/bridge.ts rpi-cockpit/tests/bridge.test.ts
git commit -m "feat(cockpit): bridge drives the decision flow (append/answer/revise/hostElicits)"
```

---

### Task 3: The `revise` inbound frame

**Files:**
* Modify: `src/inbound.ts` (add the frame to `InboundFrame`, `parseInbound`, `applyInbound`)
* Test: `tests/inbound.test.ts`

**Interfaces:**
* Consumes: `bridge.revise(id)` from Task 2.
* Produces: `InboundFrame` gains `| { type: "revise"; id: string }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/inbound.test.ts`:

```ts
it("parseInbound accepts a valid revise frame", () => {
  expect(parseInbound({ type: "revise", id: "d1" })).toEqual({ type: "revise", id: "d1" });
});
it("parseInbound rejects a revise frame without a string id", () => {
  expect(parseInbound({ type: "revise" })).toBeNull();
  expect(parseInbound({ type: "revise", id: 3 })).toBeNull();
});
it("applyInbound revise calls bridge.revise", () => {
  const b = new Bridge();
  const p = b.presentOptions("x", [{ id: "a", title: "A" }], 0, "d1"); b.resolveDecision("d1", "a"); void p;
  applyInbound(b, { type: "revise", id: "d1" });
  expect(b.state.decisions[0].status).toBe("pending");
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/inbound.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement in `src/inbound.ts`**

Add to the `InboundFrame` union: `| { type: "revise"; id: string }`. In `parseInbound`, add a branch (mirror the existing `typeof` guards):

```ts
  if (t === "revise") {
    const id = (msg as { id?: unknown }).id;
    return typeof id === "string" ? { type: "revise", id } : null;
  }
```

In `applyInbound`, add: `case "revise": bridge.revise(f.id); return;`

* [ ] **Step 4: Run to verify they pass**

Run: `npx vitest run tests/inbound.test.ts`
Expected: PASS.

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/inbound.ts rpi-cockpit/tests/inbound.test.ts
git commit -m "feat(cockpit): revise inbound frame (rewind a decision)"
```

---

### Task 4: View-model projection

**Files:**
* Modify: `src/render.ts` (project `decisions` + `hostElicits`; remove `decision` and `pendingQuestion` from `ViewModel` and `toViewModel`)
* Test: `tests/render.test.ts`

**Interfaces:**
* Consumes: `SessionState.decisions`, `SessionState.hostElicits`.
* Produces: `ViewModel.decisions: { id; prompt; kind; options?; answer?; status }[]`, `ViewModel.hostElicits: boolean`. The `ViewModel.decision` and `ViewModel.pendingQuestion` fields are REMOVED.

* [ ] **Step 1: Write the failing test**

Add to `tests/render.test.ts`:

```ts
it("projects the decisions flow and hostElicits, and drops the legacy single-decision fields", () => {
  let s = initialState();
  s = setHostElicits(s, true);
  s = answerDecision(addDecision(s, { id: "d1", prompt: "Pick?", kind: "choice", options: [{ id: "a", title: "A" }] }), "d1", "a");
  s = addDecision(s, { id: "q2", prompt: "Name?", kind: "text" });
  const vm = toViewModel(s);
  expect(vm.hostElicits).toBe(true);
  expect(vm.decisions).toHaveLength(2);
  expect(vm.decisions[0]).toMatchObject({ id: "d1", kind: "choice", status: "answered", answer: "a" });
  expect(vm.decisions[1]).toMatchObject({ id: "q2", kind: "text", status: "pending" });
  expect("decision" in vm).toBe(false);
  expect("pendingQuestion" in vm).toBe(false);
});
```

(Import `addDecision`, `answerDecision`, `setHostElicits`, `initialState` in the test file if not already.)

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/render.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement in `src/render.ts`**

In the `ViewModel` interface, REMOVE `decision` and `pendingQuestion`, ADD:

```ts
  decisions: { id: string; prompt: string; kind: string; options?: { id: string; title: string; detail?: string; recommended?: boolean }[]; answer?: string; status: string }[];
  hostElicits: boolean;
```

In `toViewModel`, remove the `decision`/`pendingQuestion` lines and add:

```ts
    decisions: s.decisions.map((d) => ({ id: d.id, prompt: d.prompt, kind: d.kind, options: d.options, answer: d.answer, status: d.status })),
    hostElicits: s.hostElicits,
```

* [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run tests/render.test.ts`
Expected: PASS.

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/render.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): view-model projects the decision flow"
```

---

### Task 5: MCP tools accept an id and report host elicitation

**Files:**
* Modify: `src/elicit.ts` (`presentOptionsWithElicitation`/`askQuestionWithElicitation` pass `id` through)
* Modify: `src/mcp.ts` (`present_options`/`ask_question` accept optional `id`; set `bridge.hostElicits`)
* Test: `tests/mcp.test.ts`, `tests/elicit.test.ts`

**Interfaces:**
* Consumes: `bridge.presentOptions(prompt, options, timeoutMs, id?)`, `bridge.askQuestion(prompt, timeoutMs, id?)`, `bridge.setHostElicits`.
* Produces: `present_options`/`ask_question` tools accept `{ ..., id?: string }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/mcp.test.ts` (the suite already exercises tools against a bridge; follow its pattern):

```ts
it("present_options forwards the id into the decisions flow", async () => {
  const { bridge, call } = makeServer(); // use the suite's existing harness/helpers
  void call("present_options", { prompt: "Pick?", options: [{ id: "a", title: "A" }], id: "d7" });
  await tick();
  expect(bridge.state.decisions.find((d) => d.id === "d7")?.kind).toBe("choice");
});
```

(If the suite has no `makeServer`/`call` helper, mirror however `tests/mcp.test.ts` currently invokes a tool and reads `bridge.state`; the assertion is the point.)

Add to `tests/elicit.test.ts`:

```ts
it("presentOptionsWithElicitation forwards the id to the bridge", () => {
  const bridge = new Bridge();
  void presentOptionsWithElicitation({ getClientCapabilities: () => ({}), elicitInput: async () => ({ action: "decline" }) }, bridge, "Pick?", [{ id: "a", title: "A" }], 0, "d9");
  expect(bridge.state.decisions[0].id).toBe("d9");
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/mcp.test.ts tests/elicit.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement**

In `src/elicit.ts`, add `id?: string` as the last param of `presentOptionsWithElicitation` and `askQuestionWithElicitation`, and forward it: `const webPromise = bridge.presentOptions(prompt, options, timeoutMs, id);` (and `bridge.askQuestion(prompt, timeoutMs, id)`).

In `src/mcp.ts`, for `present_options` add `id: z.string().optional()` to `inputSchema`, set host elicitation, and pass `a.id`:

```ts
    async (a) => {
      bridge.setHostElicits(server.server.getClientCapabilities()?.elicitation !== undefined);
      return text(await presentOptionsWithElicitation(/* adapter */, bridge, a.prompt, a.options, decisionTimeoutMs(), a.id));
    },
```

Do the analogous change to `ask_question` (`id: z.string().optional()`, set hostElicits, pass `a.id`, keep `questionTimeoutMs()`).

* [ ] **Step 4: Run to verify they pass, then the whole suite + tsc**

Run: `npx tsc --noEmit && npx vitest run`
Expected: tsc clean; the only remaining failures are in `tests/decision-client.test.ts` and any interview-client question assertions, fixed in Task 6. If OTHER suites fail to compile, fix the references (they should only touch removed fields).

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/elicit.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts rpi-cockpit/tests/elicit.test.ts
git commit -m "feat(cockpit): present_options/ask_question take an id; report host elicitation"
```

---

### Task 6: The decision-flow client view

**Files:**
* Modify: `public/index.html` (remove the `#decision` banner markup and the `#iv-question` box; add a `#decision-flow` element and its CSS; add a `.flow-slot` div at the top of the `.center` work area in `#rpi-view` and at the top of `#interview-view`)
* Modify: `public/client.js` (add `renderDecisionFlow(v)`; call it near the top of `render(v)`; move the flow element into the active view's slot; remove the old `decisionHtml`/`#decision` rendering and the `#iv-question` rendering in `renderInterview`; add the `revisit` click and keep choice clicks gated on `!hostElicits`)
* Test: `tests/decision-client.test.ts` (rework), `tests/interview-client.test.ts` (drop the question-box assertion)

**Interfaces:**
* Consumes: `ViewModel.decisions`, `ViewModel.hostElicits`.
* Produces: a `#decision-flow` DOM element with `.flow-row[data-decision-id]` rows; a `revisit` button per answered row emitting `{ type: "revise", id }`; choice chips emitting `{ type: "decide", id, choiceId }` only when `hostElicits` is false; the active view's `.flow-slot` hosts the element.

* [ ] **Step 1: Write the failing client test**

Rework `tests/decision-client.test.ts` to load `public/index.html` + `public/client.js` into happy-dom (mirror `tests/backlog-client.test.ts`) and assert on the flow:

```ts
it("renders the decision flow with answered, pending, and revisit affordances", () => {
  window.render({
    view: "loop", domain: "rpi", navigatorOpen: false, workflows: [],
    context: { instructions: [], skills: [], collection: null }, appFrame: { url: null },
    hostElicits: true,
    decisions: [
      { id: "d1", prompt: "Strategy?", kind: "choice", options: [{ id: "a", title: "Blue-green" }], answer: "a", status: "answered" },
      { id: "q2", prompt: "Window?", kind: "text", status: "pending" },
    ],
    // minimal RPI fields:
    task: "t", host: "h", phase: "implement", phaseLabel: "Implement", phaseNumber: 3, lead: "x",
    steps: [{ phase: "implement", status: "active" }], subagents: [], validations: [],
    steerMenu: { label: "x", source: "preset", options: [] }, directives: [], screen: null, log: [],
    findingGroups: [], board: { target: null, action: null, count: 0, columns: [] },
    team: { orchestrator: null, count: 0, columns: [] }, codemap: { nodes: [], focus: null, touches: {} },
    reviewTarget: null, docType: null,
  });
  const rows = document.querySelectorAll("#decision-flow .flow-row");
  expect(rows.length).toBe(2);
  expect(document.querySelector('#decision-flow .flow-row[data-decision-id="d1"] [data-revise="d1"]')).toBeTruthy();
  const pending = document.querySelector('#decision-flow .flow-row[data-decision-id="q2"]');
  expect(pending?.className).toContain("pending");
  // hostElicits true => choice chips are NOT clickable inputs
  expect(document.querySelector('#decision-flow [data-choice]')).toBeNull();
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/decision-client.test.ts`
Expected: FAIL.

* [ ] **Step 3: Implement the markup + CSS in `public/index.html`**

Remove the `<div id="decision" ...>` element. Add (as the first child of `.center` in `#rpi-view`, and as the first child of `#interview-view`): `<div class="flow-slot"></div>`. Add a single shared flow element inside `#loop` (the client moves it into the active slot): `<div id="decision-flow" hidden></div>`. Remove the `#iv-question` block from `#interview-view`. Add CSS:

```css
  #decision-flow { display: flex; flex-direction: column; gap: 8px; margin-bottom: 16px; }
  .flow-row { border: 1px solid var(--stroke, #3C3C3C); border-radius: 8px; padding: 9px 12px; }
  .flow-row.pending { border-color: var(--accent-blue, #4FC1FF); background: var(--brand-2, #094771); }
  .flow-row.superseded { opacity: .55; }
  .flow-prompt { font-size: 13px; }
  .flow-answer { font-size: 12.5px; color: var(--text-2, #9D9D9D); margin-top: 3px; }
  .flow-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 6px; }
  .flow-chip { font-size: 11.5px; padding: 2px 9px; border-radius: 11px; border: 1px solid var(--stroke-2, #4A4A4A); color: var(--text-2, #9D9D9D); }
  .flow-chip.picked { color: var(--accent-cyan, #9CDCFE); border-color: var(--accent-blue, #4FC1FF); }
  .flow-revise { font-size: 11px; font-family: inherit; cursor: pointer; padding: 2px 9px; border-radius: 5px; border: 1px solid var(--stroke-2, #4A4A4A); background: var(--layer, #252526); color: var(--text-2, #9D9D9D); margin-top: 6px; }
  .flow-chat { font-size: 12px; color: var(--accent-cyan, #9CDCFE); margin-top: 5px; }
```

* [ ] **Step 4: Implement `renderDecisionFlow` in `public/client.js`**

Add (and call `renderDecisionFlow(v);` near the top of `render(v)`, before the domain routing). Remove the old `setHtml("decision", ...)` call and the `decisionHtml` usage, and remove the `#iv-question` rendering inside `renderInterview` (leave the interview doc rendering).

```js
function renderDecisionFlow(v) {
  const flow = document.getElementById("decision-flow");
  if (!flow) return;
  const ds = v.decisions || [];
  if (ds.length === 0) { flow.hidden = true; flow.innerHTML = ""; return; }
  flow.hidden = false;
  const interactive = !v.hostElicits; // pane is a fallback input only when chat can't elicit
  flow.innerHTML = ds.map((d) => {
    const chips = d.kind === "choice" && d.options ? `<div class="flow-chips">${d.options.map((o) =>
      `<span class="flow-chip ${d.answer === o.id ? "picked" : ""}" ${interactive && d.status === "pending" ? `data-choice="${esc(o.id)}" data-id="${esc(d.id)}" role="button" tabindex="0"` : ""}>${esc(o.title)}</span>`).join("")}</div>` : "";
    const answer = d.kind === "text" && d.answer ? `<div class="flow-answer">${esc(d.answer)}</div>` : "";
    const pendingHint = d.status === "pending" ? `<div class="flow-chat">awaiting your answer in chat</div>` : "";
    const revise = d.status === "answered" ? `<button class="flow-revise" data-revise="${esc(d.id)}">revisit</button>` : "";
    return `<div class="flow-row ${esc(d.status)}" data-decision-id="${esc(d.id)}">
      <div class="flow-prompt">${esc(d.prompt)}</div>${answer}${chips}${pendingHint}${revise}</div>`;
  }).join("");
  // Host the flow in the active view's slot (RPI center / interview), else leave in #loop.
  const slot = document.querySelector(v.domain === "rpi" ? "#rpi-view .center .flow-slot" : v.domain === "interview" ? "#interview-view .flow-slot" : null);
  if (slot && flow.parentElement !== slot) slot.appendChild(flow);
}
```

In the delegated click handler, add (before the existing `#decision [data-choice]` branch, which is now removed):

```js
  const rev = e.target.closest("[data-revise]");
  if (rev) { sendMsg({ type: "revise", id: rev.dataset.revise }); return; }
  const fchoice = e.target.closest("#decision-flow [data-choice]");
  if (fchoice) { sendMsg({ type: "decide", id: fchoice.dataset.id, choiceId: fchoice.dataset.choice }); return; }
```

Remove the now-dead `decisionHtml` function and the old `#decision`/`#iv-send`/`#iv-input` handlers that referenced the removed elements. Keep `renderInterview` rendering the doc (`#iv-doc`) only.

* [ ] **Step 5: Update `tests/interview-client.test.ts`**

Remove or adjust any assertion that expects `#iv-question`/`#iv-input`/`#iv-send`; the interview view now shows its doc plus the shared decision flow (the question lives in the flow, not a box). Keep the doc-render assertion.

* [ ] **Step 6: Run the whole suite + tsc**

Run: `npx tsc --noEmit && npx vitest run`
Expected: ALL green.

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/decision-client.test.ts rpi-cockpit/tests/interview-client.test.ts
git commit -m "feat(cockpit): decision-flow list view replaces the decision card and interview question box"
```

---

### Task 7: Agent contract for the rewind

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md` (the decision/question section)

**Interfaces:**
* Consumes: nothing in code; this is the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

Under "Asking the user (any workflow, these BLOCK)" add a bullet:

```markdown
* The cockpit shows your questions and decisions as a navigable flow. If `check_directives()` returns a note like `revise decision "…" (id X)`, the user wants to change an earlier answer: re-ask that decision by calling the same tool with `id: "X"`, then reconsider the questions that follow, since the new answer may change them.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: 0 errors. (Fix with `--fix` if needed.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): narration contract covers the revise-decision rewind"
```

---

## Final verification (after Task 7)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` is fully green.
* [ ] `npm run build`, then verify live in the Preview pane: drive a producer that asks a couple of `present_options`/`ask_question` calls, confirm the flow list renders in the RPI center with the pending row flagged "answer in chat"; click `revisit` on an answered row and confirm a `revise` line lands in `inbox.jsonl` and the downstream rows go `superseded`.
* [ ] Draft-merge into local `main` and push to `fork` (PR #1).

## Self-Review

**Spec coverage:** chat-answers + cockpit-legibility (Tasks 4/6, `hostElicits` gating) — covered. Decisions array state (Task 1) — covered. present_options/ask_question append + optional id (Tasks 2/5) — covered. revise inbound + supersede-downstream (Tasks 2/3) — covered. Hybrid list view replacing the card + interview box (Task 6) — covered. Agent contract (Task 7) — covered. Deferred items (branching, diff, impact-preview) are correctly absent.

**Placeholder scan:** the one soft reference is the `tests/mcp.test.ts` harness ("use the suite's existing helpers") — intentional, since the suite's invocation style must be matched, and the assertion is concrete. No TBD/TODO elsewhere.

**Type consistency:** `addDecision`/`answerDecision`/`reviseDecision`/`setHostElicits` signatures match across Tasks 1, 2, 4. `DecisionEntry` fields are identical in state (Task 1), view-model (Task 4), and the client test (Task 6). The `revise` frame shape `{ type, id }` matches across Tasks 3 and 6.

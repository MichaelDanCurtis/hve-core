<!-- markdownlint-disable -->
# Interview Progress Stepper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a horizontal progress stepper to the interview view that any phased interview agent (a phase-gated planner or a coach) declares with `set_steps(steps, current, label?)`, so the user sees the program roadmap and the current step above the conversation.

**Architecture:** A new `interviewSteps` state field set by a `steps.set` beat (with `current` clamped) and reset by `interview.start`; a `set_steps` MCP tool emits the beat; `toViewModel` derives each step's done/active/pending status from `current` (mirroring the RPI rail stepper); `renderInterview` renders a `#iv-steps` strip.

**Tech Stack:** TypeScript (ESM, strict), zod, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/interview-stepper-design.md`.

## Global Constraints

* `interviewSteps: { label?: string; names: string[]; current: number } | null` in state; the view-model projects `{ label?: string; steps: { name: string; status: "done"|"active"|"pending" }[] } | null`.
* `current` is clamped into `[0, names.length - 1]` in the reducer; `steps` is a non-empty array at the tool boundary (`z.array(z.string()).min(1)`).
* Status derivation: index `< current` is `done`, `=== current` is `active`, `> current` is `pending` (mirrors the RPI steps projection).
* `interview.start` resets `interviewSteps` to `null`.
* The MCP tool count goes from 32 to 33 (one new tool).
* TypeScript strict; no new `any`; ESM `.js` import specifiers.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* Keep the `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beat, state, and view-model

**Files:**
* Modify: `src/events.ts` (the `steps.set` beat)
* Modify: `src/state.ts` (`interviewSteps` field; `initialState`; the `steps.set` reducer arm with clamp; the `interview.start` reset; the `summarize` arm)
* Modify: `src/render.ts` (`ViewModel.interviewSteps`; the projection)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces:
  * Beat `{ type: "steps.set"; steps: string[]; current: number; label?: string }`.
  * `SessionState.interviewSteps: { label?: string; names: string[]; current: number } | null`.
  * `ViewModel.interviewSteps: { label?: string; steps: { name: string; status: "done"|"active"|"pending" }[] } | null`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("interview steps", () => {
  it("steps.set stores the program and clamps current into range", () => {
    let s = applyBeat(initialState(), { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" }, 1);
    expect(s.interviewSteps).toEqual({ label: "ADR", names: ["Frame", "Decide", "Govern"], current: 1 });
    s = applyBeat(initialState(), { type: "steps.set", steps: ["a", "b"], current: 9 }, 1);
    expect(s.interviewSteps!.current).toBe(1); // clamped to last
    s = applyBeat(initialState(), { type: "steps.set", steps: ["a", "b"], current: -3 }, 1);
    expect(s.interviewSteps!.current).toBe(0); // clamped to first
  });
  it("interview.start resets interviewSteps", () => {
    let s = applyBeat(initialState(), { type: "steps.set", steps: ["a", "b"], current: 0 }, 1);
    s = applyBeat(s, { type: "interview.start", docType: "PRD" }, 2);
    expect(s.interviewSteps).toBeNull();
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects interview steps with done/active/pending derived from current", () => {
  const s = applyBeat(initialState(), { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" }, 1);
  const vm = toViewModel(s);
  expect(vm.interviewSteps).toEqual({ label: "ADR", steps: [
    { name: "Frame", status: "done" },
    { name: "Decide", status: "active" },
    { name: "Govern", status: "pending" },
  ] });
  expect(toViewModel(initialState()).interviewSteps).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL (beat/field/projection not defined).

* [ ] **Step 3: Implement `src/events.ts`**

Add to the `Beat` union (after the `interview.start` member at line 51):

```ts
  z.object({ type: z.literal("steps.set"), steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional() }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the field to `SessionState` (near `docType`):

```ts
  interviewSteps: { label?: string; names: string[]; current: number } | null;
```

In `initialState()`, add `interviewSteps: null` to the returned object.

Add `interviewSteps: null` to the `interview.start` reducer arm so a new interview clears a stale program:

```ts
    case "interview.start":
      return { ...s, view: "loop", domain: "interview", docType: beat.docType, interviewSteps: null, log };
```

Add the `steps.set` reducer arm (after the `interview.start` arm), clamping `current`:

```ts
    case "steps.set": {
      const current = Math.max(0, Math.min(beat.current, beat.steps.length - 1));
      return { ...s, interviewSteps: { label: beat.label, names: beat.steps, current }, log };
    }
```

In `summarize(beat)`, add an arm:

```ts
    case "steps.set": return beat.label ?? "steps";
```

* [ ] **Step 5: Implement `src/render.ts`**

Add the field to the `ViewModel` interface (near `docType`):

```ts
  interviewSteps: { label?: string; steps: { name: string; status: "done" | "active" | "pending" }[] } | null;
```

In `toViewModel`, before the `return`, compute the projection (mirrors the RPI `steps` derivation):

```ts
  const ist = s.interviewSteps;
  const interviewSteps = ist
    ? { label: ist.label, steps: ist.names.map((name, i) => ({ name, status: (i < ist.current ? "done" : i === ist.current ? "active" : "pending") as "done" | "active" | "pending" })) }
    : null;
```

Add `interviewSteps,` to the returned object (near `docType`).

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green.

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): interview steps state, beat, and view-model projection"
```

---

### Task 2: The `set_steps` MCP tool

**Files:**
* Modify: `src/handlers.ts` (the `set_steps` handler)
* Modify: `src/mcp.ts` (register the tool)
* Test: `tests/mcp.test.ts`

**Interfaces:**
* Consumes: the `steps.set` beat from Task 1.
* Produces: tool `set_steps({ steps: string[]; current: number; label?: string })`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` a round-trip test (copy the existing harness shape: `new Bridge()` + `buildMcpServer` + `InMemoryTransport.createLinkedPair()` + `new Client` + `client.callTool`):

```ts
it("set_steps drives the interview program state", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);
  await client.callTool({ name: "set_steps", arguments: { steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" } });
  expect(bridge.state.interviewSteps).toEqual({ label: "ADR", names: ["Frame", "Decide", "Govern"], current: 1 });
});
```

In the existing tool-list test (`tests/mcp.test.ts`, currently asserting 32): change `expect(tools).toHaveLength(32);` to `33`; update the test title from "thirty-two total" to "thirty-three total"; add `expect(names).toContain("set_steps");` alongside the other `toContain` lines.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (tool not registered; count is 32).

* [ ] **Step 3: Implement `src/handlers.ts`**

Add (next to `interview_start`):

```ts
  set_steps: (b: Bridge, a: { steps: string[]; current: number; label?: string }) => {
    b.emitBeat({ type: "steps.set", steps: a.steps, current: a.current, label: a.label });
    return `steps set: ${a.steps.length}`;
  },
```

* [ ] **Step 4: Implement `src/mcp.ts`**

Register the tool (next to the interview/backlog tools):

```ts
  server.registerTool(
    "set_steps",
    { description: "Show a progress stepper above the interview conversation: declare the program's ordered step names and the active step index (0-based). Re-call to advance (a higher current) or to re-declare the steps as an adaptive program clarifies. label is an optional program name.", inputSchema: { steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional() } },
    async (a) => text(handlers.set_steps(bridge, a)),
  );
```

* [ ] **Step 5: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; whole suite green (the count assertion now expects 33).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): set_steps MCP tool for the interview stepper"
```

---

### Task 3: The client stepper

**Files:**
* Modify: `public/index.html` (the `#iv-steps` markup + CSS)
* Modify: `public/client.js` (`renderInterview` renders the stepper)
* Test: `tests/interview-client.test.ts`

**Interfaces:**
* Consumes: `ViewModel.interviewSteps` from Task 1.
* Produces: a `#iv-steps` strip with one `.iv-step` pill per step, carrying the `.iv-step-{status}` class.

* [ ] **Step 1: Write the failing test**

Add to `tests/interview-client.test.ts` (reuse its `boot()` harness; build a vm via `applyBeat` interview.start + steps.set):

```ts
function steppedVm() {
  let s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
  s = applyBeat(s, { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" }, 2);
  return toViewModel(s);
}

it("renders the interview stepper with done/active/pending pills", () => {
  (win as any).render(steppedVm());
  const steps = win.document.getElementById("iv-steps") as any;
  expect(steps.hidden).toBe(false);
  const pills = win.document.querySelectorAll("#iv-steps .iv-step");
  expect(pills.length).toBe(3);
  expect(win.document.querySelector("#iv-steps .iv-step-done")).not.toBeNull();
  expect(win.document.querySelector("#iv-steps .iv-step-active")!.textContent).toContain("Decide");
  expect(win.document.querySelector("#iv-steps .iv-step-pending")!.textContent).toContain("Govern");
});

it("hides the stepper when no program is declared", () => {
  let s = applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1);
  (win as any).render(toViewModel(s));
  expect((win.document.getElementById("iv-steps") as any).hidden).toBe(true);
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/interview-client.test.ts`
Expected: FAIL (no `#iv-steps`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

In `#interview-view`, insert `<div id="iv-steps" hidden></div>` between the `.rev-head` (the one containing `#iv-doctype`) and the `.flow-slot`:

```html
    <div id="interview-view" hidden>
      <div class="rev-head">
        <span id="iv-doctype" class="rev-target"></span>
      </div>
      <div id="iv-steps" hidden></div>
      <div class="flow-slot"></div>
      <iframe id="iv-doc" sandbox="" title="Document preview" style="width:100%;min-height:280px;border:1px solid var(--stroke,#3a3a3a);border-radius:8px;margin-top:14px"></iframe>
    </div>
```

Add the CSS (next to the other interview/rev rules):

```css
  #iv-steps { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 4px 0 14px; }
  .iv-steps-label { font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-3, #6E6E6E); font-weight: 600; }
  .iv-step { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; padding: 3px 10px; border-radius: 12px; border: 1px solid var(--stroke, #3C3C3C); color: var(--text-2, #9D9D9D); }
  .iv-step-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--stroke-2, #4A4A4A); display: inline-flex; align-items: center; justify-content: center; font-size: 9px; line-height: 1; color: var(--ok, #73C991); }
  .iv-step-done { color: var(--text-2, #9D9D9D); }
  .iv-step-done .iv-step-dot { background: transparent; }
  .iv-step-active { color: var(--accent-cyan, #9CDCFE); border-color: var(--accent-blue, #4FC1FF); background: var(--brand-2, #094771); }
  .iv-step-active .iv-step-dot { background: var(--accent-blue, #4FC1FF); }
```

* [ ] **Step 4: Implement `renderInterview` in `public/client.js`**

Replace `renderInterview` with (adds the stepper; keeps the existing doctype + doc rendering):

```js
function renderInterview(v) {
  setText("iv-doctype", v.docType ? `Interview: ${v.docType}` : "Interview");
  const steps = document.getElementById("iv-steps");
  if (steps) {
    const ist = v.interviewSteps;
    if (ist && ist.steps && ist.steps.length) {
      steps.hidden = false;
      const lead = ist.label ? `<span class="iv-steps-label">${esc(ist.label)}</span>` : "";
      steps.innerHTML = lead + ist.steps.map((st) =>
        `<span class="iv-step iv-step-${esc(st.status)}"><span class="iv-step-dot">${st.status === "done" ? "✓" : ""}</span>${esc(st.name)}</span>`).join("");
    } else { steps.hidden = true; steps.innerHTML = ""; }
  }
  const doc = document.getElementById("iv-doc");
  if (doc) doc.srcdoc = v.screen?.html ?? "";
}
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/interview-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/interview-client.test.ts
git commit -m "feat(cockpit): interview view renders the program stepper"
```

---

### Task 4: Agent contract for the stepper

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

In `rpi-cockpit/agents/cockpit-instructions.md`, in the guided-document-builders / interview section, add this bullet:

```markdown
* If your interview runs a multi-step program (a phase-gated planner like ADR Frame/Decide/Govern or a six-phase assessment, or a coach running a curriculum or method sequence), call `set_steps(steps, current, label?)` when you begin and again as you advance (a higher `current`): the interview view shows a progress stepper above the conversation so the user sees the whole roadmap and the current step. Re-declare `steps` if an adaptive program's path changes.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`. (Split the bullet if MD013 trips; keep asterisk bullets, no em-dashes.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): contract for the interview progress stepper"
```

---

## Final verification (after Task 4)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live (the render.ts change needs a RESTARTED consumer pane): drive a producer that calls `interview_start` + `set_steps` (a 3+ step program, current advancing) + a couple of `ask_question`; confirm the stepper renders above the decision flow with the right done/active/pending styling, and re-calling `set_steps` advances the active step.
* [ ] Push to `fork` (PR #1).

## Self-Review

**Spec coverage:** the `interviewSteps` state + `steps.set` beat + clamp + `interview.start` reset (Task 1) — covered. The view-model status derivation (Task 1) — covered. The `set_steps` tool (Task 2) — covered. The `#iv-steps` stepper render (Task 3) — covered. The contract (Task 4) — covered. Deferred items (clickable stepper, per-step sub-progress, non-interview reuse) correctly absent.

**Placeholder scan:** every code step shows complete code; the round-trip test uses the suite's real harness verbatim. No TBD/TODO.

**Type consistency:** `interviewSteps` state shape `{ label?, names, current }` and the view-model shape `{ label?, steps: { name, status }[] }` are distinct and consistent across state (Task 1), the projection (Task 1), the tool (Task 2), and the client/test (Task 3). The status literal union `"done"|"active"|"pending"` matches across the view-model type, the projection cast, and the test assertions. `set_steps`/`steps.set`/`#iv-steps`/`.iv-step-{status}` names are consistent across all tasks. The tool count moves 32 to 33 in exactly the count test.

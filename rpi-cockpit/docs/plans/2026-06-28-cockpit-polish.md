<!-- markdownlint-disable -->
# Cockpit Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three deferred refinements: a responsive side-by-side interview layout, per-step sub-progress in the interview stepper, and an intent-based open-in-editor control on findings.

**Architecture:** Item 1 is CSS + one markup wrap. Item 2 threads an optional `progress` through the `steps.set` beat / state / view-model / `set_steps` tool / `renderInterview`. Item 3 adds an `open` inbound frame that `applyInbound` turns into an agent directive, plus a findings button.

**Tech Stack:** TypeScript (ESM, strict), zod, unbundled browser client, Vitest + happy-dom. Design spec: `docs/cockpit-polish-design.md`.

## Global Constraints

* No new MCP tools (count stays 33); `set_steps` only gains an optional field.
* `progress` is `{ done: number; total: number }`, attached in the view-model to the ACTIVE step only.
* The `open` inbound frame is `{ type: "open"; file: string; line?: number }`; `applyInbound` enqueues a `note` directive, no new bridge state.
* TypeScript strict; no new `any`; ESM `.js` specifiers.
* Every `v.*`/finding interpolation in `public/client.js` goes through `esc()` (numeric widths set via `style` are computed numbers, not user strings).
* Keep the `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Responsive side-by-side interview layout

**Files:**
* Modify: `public/index.html` (wrap conversation children in `.iv-convo`; move the `#iv-doc` inline style to CSS; add the media query)
* Test: `tests/interview-client.test.ts`

**Interfaces:**
* Produces: `#interview-view` has exactly two children, `.iv-convo` (wrapping `.rev-head`, `#iv-steps`, `.flow-slot`) and `#iv-doc`.

* [ ] **Step 1: Write the failing test**

Add to `tests/interview-client.test.ts` (reuse its `boot()` harness):

```ts
it("wraps the conversation in .iv-convo with the draft iframe as a sibling", () => {
  (win as any).render(steppedVm()); // existing helper from the stepper tests
  const view = win.document.getElementById("interview-view")!;
  const convo = view.querySelector(".iv-convo")!;
  expect(convo).not.toBeNull();
  expect(convo.querySelector("#iv-steps")).not.toBeNull();
  expect(convo.querySelector(".flow-slot")).not.toBeNull();
  // the draft iframe is a sibling of .iv-convo, not inside it
  expect(view.querySelector(":scope > #iv-doc")).not.toBeNull();
  expect(convo.querySelector("#iv-doc")).toBeNull();
});
```

(If `steppedVm` is not in scope, build a vm inline: `applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1)` then `toViewModel`.)

* [ ] **Step 2: Run to verify it fails**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/interview-client.test.ts`
Expected: FAIL (no `.iv-convo`).

* [ ] **Step 3: Rewrite the `#interview-view` markup in `public/index.html`**

Replace the current block:

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

with (the conversation wrapped, the iframe inline style removed in favor of a CSS rule):

```html
    <div id="interview-view" hidden>
      <div class="iv-convo">
        <div class="rev-head">
          <span id="iv-doctype" class="rev-target"></span>
        </div>
        <div id="iv-steps" hidden></div>
        <div class="flow-slot"></div>
      </div>
      <iframe id="iv-doc" sandbox="" title="Document preview"></iframe>
    </div>
```

* [ ] **Step 4: Add the CSS in `public/index.html`**

Add (the base `#iv-doc` rule replaces the removed inline style; the media query is the responsive split):

```css
  #iv-doc { width: 100%; min-height: 280px; border: 1px solid var(--stroke, #3a3a3a); border-radius: 8px; margin-top: 14px; background: #fff; }
  @media (min-width: 980px) {
    #interview-view { display: flex; gap: 22px; align-items: stretch; min-height: 0; }
    #interview-view .iv-convo { flex: 1 1 0; min-width: 0; overflow: auto; }
    #interview-view #iv-doc { flex: 1 1 0; min-width: 0; min-height: 0; margin-top: 0; }
  }
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/interview-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green (the existing interview-client tests still pass: `#iv-steps`, `#iv-doctype`, `#iv-doc`, and `.flow-slot` are all still present and still found by id / descendant selector).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/tests/interview-client.test.ts
git commit -m "feat(cockpit): responsive side-by-side interview layout"
```

---

### Task 2: Per-step sub-progress through set_steps

**Files:**
* Modify: `src/events.ts`, `src/state.ts`, `src/render.ts`, `src/handlers.ts`, `src/mcp.ts`, `public/client.js`, `public/index.html`, `rpi-cockpit/agents/cockpit-instructions.md`
* Test: `tests/state.test.ts`, `tests/render.test.ts`, `tests/mcp.test.ts`, `tests/interview-client.test.ts`

**Interfaces:**
* Consumes: the existing `interviewSteps` state + `set_steps` tool.
* Produces: `set_steps(steps, current, label?, progress?)` where `progress` is `{ done: number; total: number }`; the view-model active step carries `progress?`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
it("steps.set stores progress for the active step", () => {
  const s = applyBeat(initialState(), { type: "steps.set", steps: ["a", "b"], current: 1, progress: { done: 2, total: 3 } }, 1);
  expect(s.interviewSteps!.progress).toEqual({ done: 2, total: 3 });
});
```

Add to `tests/render.test.ts`:

```ts
it("attaches progress to the active step only", () => {
  const s = applyBeat(initialState(), { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, progress: { done: 2, total: 3 } }, 1);
  const steps = toViewModel(s).interviewSteps!.steps;
  expect(steps[1]).toEqual({ name: "Decide", status: "active", progress: { done: 2, total: 3 } });
  expect((steps[0] as any).progress).toBeUndefined();
  expect((steps[2] as any).progress).toBeUndefined();
});
```

Add to `tests/mcp.test.ts` (the suite's harness):

```ts
it("set_steps forwards progress", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);
  await client.callTool({ name: "set_steps", arguments: { steps: ["a", "b"], current: 0, progress: { done: 1, total: 4 } } });
  expect(bridge.state.interviewSteps!.progress).toEqual({ done: 1, total: 4 });
});
```

Add to `tests/interview-client.test.ts`:

```ts
it("renders done/total and a mini-bar on the active step with progress", () => {
  let s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
  s = applyBeat(s, { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, progress: { done: 2, total: 4 } }, 2);
  (win as any).render(toViewModel(s));
  const active = win.document.querySelector("#iv-steps .iv-step-active")!;
  expect(active.querySelector(".iv-step-prog")!.textContent).toBe("2/4");
  const bar = active.querySelector(".iv-step-bar > i") as any;
  expect(bar.getAttribute("style")).toContain("width:50%");
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts tests/mcp.test.ts tests/interview-client.test.ts`
Expected: FAIL.

* [ ] **Step 3: `src/events.ts`** — add `progress` to the `steps.set` beat:

```ts
  z.object({ type: z.literal("steps.set"), steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional(), progress: z.object({ done: z.number().int(), total: z.number().int() }).optional() }),
```

* [ ] **Step 4: `src/state.ts`** — extend the `interviewSteps` field type and the reducer arm:

The field becomes:

```ts
  interviewSteps: { label?: string; names: string[]; current: number; progress?: { done: number; total: number } } | null;
```

The `steps.set` arm becomes:

```ts
    case "steps.set": {
      const current = Math.max(0, Math.min(beat.current, beat.steps.length - 1));
      return { ...s, interviewSteps: { label: beat.label, names: beat.steps, current, progress: beat.progress }, log };
    }
```

* [ ] **Step 5: `src/render.ts`** — attach `progress` to the active step in the projection. Change the `interviewSteps` projection to:

```ts
  const ist = s.interviewSteps;
  const interviewSteps = ist
    ? { label: ist.label, steps: ist.names.map((name, i) => {
        const status = (i < ist.current ? "done" : i === ist.current ? "active" : "pending") as "done" | "active" | "pending";
        return status === "active" && ist.progress ? { name, status, progress: ist.progress } : { name, status };
      }) }
    : null;
```

And widen the `ViewModel.interviewSteps` step type to carry the optional progress:

```ts
  interviewSteps: { label?: string; steps: { name: string; status: "done" | "active" | "pending"; progress?: { done: number; total: number } }[] } | null;
```

* [ ] **Step 6: `src/handlers.ts`** — thread `progress`:

```ts
  set_steps: (b: Bridge, a: { steps: string[]; current: number; label?: string; progress?: { done: number; total: number } }) => {
    b.emitBeat({ type: "steps.set", steps: a.steps, current: a.current, label: a.label, progress: a.progress });
    return `steps set: ${a.steps.length}`;
  },
```

* [ ] **Step 7: `src/mcp.ts`** — add `progress` to the `set_steps` inputSchema:

```ts
    { description: "Show a progress stepper above the interview conversation: declare the program's ordered step names and the active step index (0-based). Re-call to advance (a higher current) or to re-declare the steps as an adaptive program clarifies. label is an optional program name. progress is an optional { done, total } shown on the active step.", inputSchema: { steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional(), progress: z.object({ done: z.number().int(), total: z.number().int() }).optional() } },
```

* [ ] **Step 8: `public/client.js`** — render the progress in `renderInterview`. Change the stepper `.map((st) => ...)` to a block arrow that computes the bar width:

```js
      steps.innerHTML = lead + ist.steps.map((st) => {
        const prog = st.progress;
        const extra = prog
          ? `<span class="iv-step-prog">${esc(String(prog.done))}/${esc(String(prog.total))}</span><span class="iv-step-bar"><i style="width:${prog.total > 0 ? Math.round(100 * prog.done / prog.total) : 0}%"></i></span>`
          : "";
        return `<span class="iv-step iv-step-${esc(st.status)}"><span class="iv-step-dot">${st.status === "done" ? "✓" : ""}</span>${esc(st.name)}${extra}</span>`;
      }).join("");
```

* [ ] **Step 9: `public/index.html`** — add the CSS:

```css
  .iv-step-prog { font-size: 10.5px; opacity: .8; margin-left: 5px; }
  .iv-step-bar { display: inline-block; width: 28px; height: 3px; border-radius: 2px; background: var(--stroke-2, #4A4A4A); margin-left: 6px; vertical-align: middle; overflow: hidden; }
  .iv-step-bar > i { display: block; height: 100%; background: var(--accent-blue, #4FC1FF); }
```

* [ ] **Step 10: `rpi-cockpit/agents/cockpit-instructions.md`** — update the `set_steps` bullet to mention `progress`:

Change the bullet's signature to `set_steps(steps, current, label?, progress?)` and add a trailing sentence: `Pass progress as { done, total } to show sub-progress on the active step (for example a comprehension check 2 of 3).`

* [ ] **Step 11: Run the focused tests, then tsc + node check + whole suite + lint**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts tests/mcp.test.ts tests/interview-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Then from the repo root: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: ALL green; lint 0 errors.

* [ ] **Step 12: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/public/client.js rpi-cockpit/public/index.html rpi-cockpit/agents/cockpit-instructions.md rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts rpi-cockpit/tests/mcp.test.ts rpi-cockpit/tests/interview-client.test.ts
git commit -m "feat(cockpit): per-step sub-progress in the interview stepper"
```

---

### Task 3: Intent-based open-in-editor on findings

**Files:**
* Modify: `src/inbound.ts` (the `open` frame), `public/client.js` (`renderFindings` open button + click branch), `public/index.html` (`.finding-open` CSS), `rpi-cockpit/agents/cockpit-instructions.md` (contract line)
* Test: `tests/inbound.test.ts`, `tests/findings-client.test.ts`

**Interfaces:**
* Consumes: the existing `bridge.enqueueDirective` and `parseInbound`/`applyInbound`.
* Produces: `InboundFrame` gains `| { type: "open"; file: string; line?: number }`; findings render a `.finding-open` button.

* [ ] **Step 1: Write the failing tests**

Add to `tests/inbound.test.ts`:

```ts
it("parseInbound accepts an open frame with and without a line", () => {
  expect(parseInbound({ type: "open", file: "a.ts", line: 4 })).toEqual({ type: "open", file: "a.ts", line: 4 });
  expect(parseInbound({ type: "open", file: "a.ts" })).toEqual({ type: "open", file: "a.ts" });
});
it("parseInbound rejects an open frame with a bad file or line", () => {
  expect(parseInbound({ type: "open" })).toBeNull();
  expect(parseInbound({ type: "open", file: 3 })).toBeNull();
  expect(parseInbound({ type: "open", file: "a.ts", line: "4" })).toBeNull();
});
it("applyInbound open enqueues an editor directive", () => {
  const b = new Bridge();
  applyInbound(b, { type: "open", file: "src/x.ts", line: 9 });
  expect(b.state.directives.at(-1)).toMatchObject({ kind: "note" });
  expect((b.state.directives.at(-1) as { text: string }).text).toContain("src/x.ts:9");
});
```

Add to `tests/findings-client.test.ts`:

```ts
it("renders an open button carrying the file and line", () => {
  (win as any).render(reviewVmWithPipeline()); // existing helper; its high finding is api.ts:12
  const open = win.document.querySelector('#findings .finding-open') as any;
  expect(open.tagName).toBe("BUTTON");
  expect(open.getAttribute("data-file")).toBe("api.ts");
  expect(open.getAttribute("data-line")).toBe("12");
});
```

(If `reviewVmWithPipeline` is not present, use whatever existing helper builds a finding with a file and line.)

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/inbound.test.ts tests/findings-client.test.ts`
Expected: FAIL.

* [ ] **Step 3: `src/inbound.ts`** — add the frame. To the `InboundFrame` union add:

```ts
  | { type: "open"; file: string; line?: number };
```

In `parseInbound`, add a branch before the final `return null;`:

```ts
  if (type === "open") {
    const m = msg as { file?: unknown; line?: unknown };
    if (typeof m.file === "string" && (m.line === undefined || typeof m.line === "number")) {
      return m.line === undefined ? { type: "open", file: m.file } : { type: "open", file: m.file, line: m.line };
    }
    return null;
  }
```

In `applyInbound`'s switch, add:

```ts
    case "open":
      bridge.enqueueDirective({ kind: "note", text: f.line != null ? `open ${f.file}:${f.line} in the editor` : `open ${f.file} in the editor` });
      return;
```

* [ ] **Step 4: `public/client.js`** — render the open button and handle its click. In `renderFindings`, change the location cell to add the open button after the copy button:

```js
              ${f.file ? `<button type="button" class="finding-loc" data-loc="${loc}" title="Copy location">${loc}</button><button type="button" class="finding-open" data-file="${esc(f.file)}"${f.line != null ? ` data-line="${esc(String(f.line))}"` : ""} title="Open in editor" aria-label="Open ${loc}">↗</button>` : ""}
```

In the delegated click handler, add a branch immediately after the existing `.finding-loc[data-loc]` (`copyLoc`) branch:

```js
  const open = e.target.closest(".finding-open[data-file]");
  if (open) {
    const file = open.dataset.file;
    const line = open.dataset.line;
    sendMsg(line != null ? { type: "open", file, line: Number(line) } : { type: "open", file });
    return;
  }
```

* [ ] **Step 5: `public/index.html`** — add the CSS next to `.finding-loc`:

```css
  .finding-open { font-size: 12px; opacity: .6; background: none; border: 0; padding: 0 0 0 6px; margin: 0; color: inherit; font: inherit; cursor: pointer; }
  .finding-open:hover { opacity: .9; }
```

* [ ] **Step 6: `rpi-cockpit/agents/cockpit-instructions.md`** — add a bullet in the reviews/audits section:

```markdown
* If `check_directives()` returns a note like `open <file>:<line> in the editor`, the user clicked a finding's open control: open that file (at the line, if given).
```

* [ ] **Step 7: Run the focused tests, then tsc + node check + whole suite + lint**

Run: `npx vitest run tests/inbound.test.ts tests/findings-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Then from the repo root: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: ALL green; lint 0 errors.

* [ ] **Step 8: Commit**

```bash
git add rpi-cockpit/src/inbound.ts rpi-cockpit/public/client.js rpi-cockpit/public/index.html rpi-cockpit/agents/cockpit-instructions.md rpi-cockpit/tests/inbound.test.ts rpi-cockpit/tests/findings-client.test.ts
git commit -m "feat(cockpit): open-in-editor intent on findings"
```

---

## Final verification (after Task 3)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live (restart the consumer pane for the render.ts change): an interview with `set_steps(..., progress)` shows the active-step count + bar; `preview_resize` wide (>=980) shows the interview side-by-side and narrow shows it stacked; a findings producer + clicking a finding's open control writes an `{type:"open",...}` frame to inbox.jsonl and an `open <file>:<line>` directive appears.
* [ ] Push to `fork` and open PR #2 into the fork's main.

## Self-Review

**Spec coverage:** responsive layout (Task 1). per-step sub-progress folded into set_steps (Task 2). open-in-editor intent frame + button + contract (Task 3). All three covered. Deferred items (draggable splitter, per-step map, direct IDE jump) correctly absent.

**Placeholder scan:** every code step shows complete code. The two test-helper references (`steppedVm`, `reviewVmWithPipeline`) are existing helpers with a fallback note. No TBD/TODO.

**Type consistency:** `progress: { done: number; total: number }` is identical across the beat, state, view-model, tool, and client. The `open` frame `{ type, file, line? }` is identical across `inbound.ts` and the client `sendMsg`. `.iv-convo` / `.finding-open` / `.iv-step-prog` class names match across markup, render, and tests.

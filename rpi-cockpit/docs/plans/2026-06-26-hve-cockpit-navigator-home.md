<!-- markdownlint-disable MD013 -->
# HVE Cockpit Navigator home Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Add the Navigator home to the cockpit, a graphical front door that lists HVE Core's workflows as hover-described tiles, routes a tile click to the host agent as an intent, and swaps the same pane between the home and the running loop view.

Architecture: The cockpit is a pure pipeline (beat to state via applyBeat, state to ViewModel via toViewModel, ViewModel painted by public/client.js). This plan adds a static capability catalog, a `view` ("home" or "loop") plus `activeWorkflow` field to session state, two inbound WS frames (`launch` and `navigate`) that reuse the existing directive channel so the agent does the actual launch, and a home screen in the client that the painter routes to. The home is the cockpit's empty state; the existing loop view is its started state.

Tech Stack: Node.js >= 20, TypeScript 5.6 (strict, ESM NodeNext), zod, the ws WebSocket library, Vitest 2, happy-dom for the client smoke test. The browser client is plain unbundled ES module source in public/, served as-is.

## Global Constraints

* TypeScript strict is on; no `any`, no new non-null assertions.
* ESM NodeNext: every relative import inside `src/` uses a `.js` extension (for example `import { WORKFLOWS } from "./catalog.js"`).
* Do not commit `dist/`; only source, tests, and the public/ client assets ship.
* Captures intent, never launches: clicking a tile enqueues a directive for the agent to act on. The cockpit never starts or orchestrates an agent itself.
* The home is graphical: tiles, a welcome, an orient strip. It is never a freeform prompt box (the host chat already is one).
* Secure default is unchanged: do not weaken the token gate, the loopback bind, or the iframe `sandbox=""` screen boundary.
* New ViewModel and SessionState fields are additive; update existing render and state test expectations rather than removing assertions.
* Repo markdown rules (for any docs touched): no em dashes, no bolded-prefix list items.

## File Structure

| File | Create or Modify | Responsibility |
|---|---|---|
| `src/catalog.ts` | Create | Static `Workflow` type and `WORKFLOWS` list (id, name, hint, description, intent). The single source of the home's tiles. |
| `tests/catalog.test.ts` | Create | Unit tests for the catalog shape and invariants. |
| `src/state.ts` | Modify | Add `view` and `activeWorkflow` to `SessionState`; set `view: "loop"` on `session.begin`; add pure `setView` and `startLaunch` reducers. |
| `tests/state.test.ts` | Modify | Cover the new view default, the session.begin transition, and the two new reducers. |
| `src/render.ts` | Modify | Add `view`, `workflows`, and `activeWorkflow` to `ViewModel` and `toViewModel`. |
| `tests/render.test.ts` | Modify | Cover the new view-model fields. |
| `src/bridge.ts` | Modify | Add `requestLaunch(workflowId)` and `navigate(screen)` methods. |
| `tests/bridge.test.ts` | Modify | Cover requestLaunch (enqueues a directive and flips to loop) and navigate. |
| `src/server.ts` | Modify | Handle inbound `launch` and `navigate` WS frames. |
| `tests/server.test.ts` | Modify | Round-trip the launch and navigate frames over WS. |
| `public/index.html` | Modify | Add the `#home` section (welcome, orient strip, workflow grid) and wrap the existing loop UI in `#loop`; add a back-to-home control. |
| `public/client.js` | Modify | Route between `#home` and `#loop` from `v.view`; paint the home; wire tile click to a `launch` frame and back to a `navigate` frame. |
| `tests/navigator-client.test.ts` | Create | happy-dom smoke: load index.html + client.js, feed home and loop view-models, assert routing, tile render, and that a tile click emits a launch frame. |

---

### Task 1: Capability catalog

Files:

* Create: `src/catalog.ts`
* Test: `tests/catalog.test.ts`

Interfaces:

```ts
// produced (consumed by render.ts, bridge.ts, and the client via the view-model)
export interface Workflow { id: string; name: string; hint: string; description: string; intent: string; }
export const WORKFLOWS: Workflow[];
```

Steps:

* [ ] Step: Write the failing test. Create `tests/catalog.test.ts` with exactly:

```ts
import { describe, it, expect } from "vitest";
import { WORKFLOWS } from "../src/catalog.js";

describe("WORKFLOWS catalog", () => {
  it("has the six front-door workflows", () => {
    expect(WORKFLOWS.map((w) => w.id)).toEqual(["build", "review", "plan", "docs", "data", "coach"]);
  });

  it("gives every workflow a name, hint, description, and intent", () => {
    for (const w of WORKFLOWS) {
      expect(w.name.length).toBeGreaterThan(0);
      expect(w.hint.length).toBeGreaterThan(0);
      expect(w.description.length).toBeGreaterThan(0);
      expect(w.intent.length).toBeGreaterThan(0);
    }
  });

  it("has unique ids", () => {
    expect(new Set(WORKFLOWS.map((w) => w.id)).size).toBe(WORKFLOWS.length);
  });
});
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/catalog.test.ts`. Expected: FAIL (cannot resolve `../src/catalog.js`).
* [ ] Step: Create `src/catalog.ts` with exactly:

```ts
// src/catalog.ts
// The static capability catalog: the workflows the Navigator home offers as
// tiles. `intent` is the directive text sent to the host agent when the user
// clicks a tile; the agent does the actual launch. Names use goal language,
// mapping onto the workflow archetypes in docs/representation-map.md.

export interface Workflow {
  id: string;
  name: string;
  hint: string;
  description: string;
  intent: string;
}

export const WORKFLOWS: Workflow[] = [
  {
    id: "build",
    name: "Build code",
    hint: "Research, plan, implement",
    description: "Research, plan, and implement a change end to end, pausing at each decision for your call.",
    intent: "Launch the Build code workflow: run the RPI build loop (research, plan, implement, review, discover) for the task I describe next.",
  },
  {
    id: "review",
    name: "Review code",
    hint: "Findings by severity",
    description: "Point it at a branch or pull request for severity-ranked findings: bugs, security, accessibility, with file links.",
    intent: "Launch the Review code workflow: run a code review and report findings grouped by severity with file and line links.",
  },
  {
    id: "plan",
    name: "Plan and backlog",
    hint: "Triage and sprint",
    description: "Triage and shape work in GitHub, Azure DevOps, or Jira: discover, plan a sprint, and execute.",
    intent: "Launch the Plan and backlog workflow: triage and shape backlog work (discover, sprint plan, execute).",
  },
  {
    id: "docs",
    name: "Write docs and specs",
    hint: "Guided interview",
    description: "A guided interview that builds a product brief, a decision record, or a security plan, one question at a time.",
    intent: "Launch the Write docs and specs workflow: run a guided document interview (product brief, decision record, or security plan).",
  },
  {
    id: "data",
    name: "Analyze data",
    hint: "Notebooks and dashboards",
    description: "Turn a question and a dataset into a notebook, a dashboard, or a spec, previewed as it builds.",
    intent: "Launch the Analyze data workflow: turn a question and a dataset into a notebook, a dashboard, or a spec.",
  },
  {
    id: "coach",
    name: "Coach and learn",
    hint: "Methods and practices",
    description: "Work through a method with a coach: design thinking, agile practices, or experiment design, at your pace.",
    intent: "Launch the Coach and learn workflow: work through a method or curriculum with a coach.",
  },
];
```

* [ ] Step: Run the test to verify it passes. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/catalog.test.ts`. Expected: PASS, 3 tests.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/catalog.ts rpi-cockpit/tests/catalog.test.ts && git commit -m "feat(cockpit): add workflow capability catalog for the Navigator"`.

---

### Task 2: Navigation state and home view-model fields

Files:

* Modify: `src/state.ts`
* Modify: `src/render.ts`
* Test: `tests/state.test.ts`
* Test: `tests/render.test.ts`

Interfaces:

```ts
// produced (state.ts)
// SessionState gains: view: "home" | "loop";  activeWorkflow: string | null;
export function setView(s: SessionState, view: "home" | "loop"): SessionState;
export function startLaunch(s: SessionState, workflowId: string): SessionState;

// produced (render.ts) ViewModel gains:
//   view: "home" | "loop";
//   workflows: { id: string; name: string; hint: string; description: string }[];
//   activeWorkflow: string | null;
```

Steps:

* [ ] Step: Write the failing state tests. Add to `tests/state.test.ts` (inside the existing top-level `describe`), pasting this block:

```ts
  describe("navigation", () => {
    it("defaults the view to home", () => {
      expect(initialState().view).toBe("home");
      expect(initialState().activeWorkflow).toBeNull();
    });

    it("session.begin switches the view to loop", () => {
      const s = applyBeat(initialState(), { type: "session.begin", task: "x", host: "claude-code" }, 1);
      expect(s.view).toBe("loop");
    });

    it("setView returns a state with the requested view", () => {
      expect(setView(initialState(), "loop").view).toBe("loop");
      const back = setView(setView(initialState(), "loop"), "home");
      expect(back.view).toBe("home");
    });

    it("startLaunch sets the active workflow and shows the loop", () => {
      const s = startLaunch(initialState(), "build");
      expect(s.activeWorkflow).toBe("build");
      expect(s.view).toBe("loop");
    });
  });
```

Add `setView` and `startLaunch` to the existing import from `../src/state.js` at the top of the file.

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts`. Expected: FAIL (`view` undefined, `setView`/`startLaunch` not exported).
* [ ] Step: In `src/state.ts`, add the two fields to the `SessionState` interface, immediately after the `host: string;` line:

```ts
  view: "home" | "loop";
  activeWorkflow: string | null;
```

* [ ] Step: In `src/state.ts`, set the defaults in `initialState()` by adding `view: "home", activeWorkflow: null,` to the returned object (place them right after `host: "",`).
* [ ] Step: In `src/state.ts`, in the `applyBeat` `case "session.begin":`, add `view: "loop" as const,` to the returned object so it reads:

```ts
    case "session.begin":
      return { ...s, task: beat.task, host: beat.host, view: "loop", log };
```

* [ ] Step: In `src/state.ts`, add the two pure reducers at the end of the file:

```ts
export function setView(s: SessionState, view: "home" | "loop"): SessionState {
  return { ...s, view };
}

export function startLaunch(s: SessionState, workflowId: string): SessionState {
  return { ...s, view: "loop", activeWorkflow: workflowId };
}
```

* [ ] Step: Run the state tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts`. Expected: PASS (existing tests plus the new navigation block). If a pre-existing test asserts the full `initialState()` object by deep equality, update it to include `view: "home"` and `activeWorkflow: null`.
* [ ] Step: Write the failing render tests. Add to `tests/render.test.ts` (inside the existing `describe`):

```ts
  describe("navigator fields", () => {
    it("exposes the view and the workflow catalog", () => {
      const vm = toViewModel(initialState());
      expect(vm.view).toBe("home");
      expect(vm.workflows.map((w) => w.id)).toEqual(["build", "review", "plan", "docs", "data", "coach"]);
      expect(vm.workflows[0]).not.toHaveProperty("intent");
    });

    it("carries the active workflow once launched", () => {
      const vm = toViewModel(startLaunch(initialState(), "review"));
      expect(vm.view).toBe("loop");
      expect(vm.activeWorkflow).toBe("review");
    });
  });
```

Add `startLaunch` to the import from `../src/state.js` in this test file.

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/render.test.ts`. Expected: FAIL (`view`/`workflows`/`activeWorkflow` missing).
* [ ] Step: In `src/render.ts`, add the import at the top, next to the other local imports:

```ts
import { WORKFLOWS } from "./catalog.js";
```

* [ ] Step: In `src/render.ts`, add the three fields to the `ViewModel` interface:

```ts
  view: "home" | "loop";
  workflows: { id: string; name: string; hint: string; description: string }[];
  activeWorkflow: string | null;
```

* [ ] Step: In `src/render.ts`, set the three fields in the object returned by `toViewModel` (add alongside the existing fields):

```ts
    view: s.view,
    workflows: WORKFLOWS.map((w) => ({ id: w.id, name: w.name, hint: w.hint, description: w.description })),
    activeWorkflow: s.activeWorkflow,
```

The `intent` field is intentionally not projected: the client sends a workflow id, and the server maps it to the intent, so the launch text never needs to live in the browser.

* [ ] Step: Run the render tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/render.test.ts`. Expected: PASS. Update any pre-existing exact-shape assertion to include the new fields.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts && git commit -m "feat(cockpit): add home/loop view + workflow catalog to state and view-model"`.

---

### Task 3: Launch and navigate inbound frames

Files:

* Modify: `src/bridge.ts`
* Modify: `src/server.ts`
* Test: `tests/bridge.test.ts`
* Test: `tests/server.test.ts`

Interfaces:

```ts
// produced (bridge.ts)
requestLaunch(workflowId: string): void;  // sets activeWorkflow + view loop, enqueues an approach directive carrying the workflow intent
navigate(screen: "home" | "loop"): void;  // sets the view, emits state
```

Steps:

* [ ] Step: Write the failing bridge tests. Add to `tests/bridge.test.ts` (inside the existing `describe`):

```ts
  describe("navigator", () => {
    it("requestLaunch enqueues an approach directive and shows the loop", () => {
      const b = new Bridge();
      b.requestLaunch("build");
      expect(b.state.view).toBe("loop");
      expect(b.state.activeWorkflow).toBe("build");
      expect(b.state.directives).toHaveLength(1);
      expect(b.state.directives[0].kind).toBe("approach");
      expect(b.state.directives[0]).toMatchObject({ value: "build" });
    });

    it("requestLaunch ignores an unknown workflow id", () => {
      const b = new Bridge();
      b.requestLaunch("nope");
      expect(b.state.directives).toHaveLength(0);
      expect(b.state.view).toBe("home");
    });

    it("navigate sets the view", () => {
      const b = new Bridge();
      b.navigate("loop");
      expect(b.state.view).toBe("loop");
      b.navigate("home");
      expect(b.state.view).toBe("home");
    });
  });
```

Ensure `Bridge` is imported from `../src/bridge.js` (it already is in this file).

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/bridge.test.ts`. Expected: FAIL (`requestLaunch`/`navigate` not functions).
* [ ] Step: In `src/bridge.ts`, add the import next to the other local imports:

```ts
import { WORKFLOWS } from "./catalog.js";
import { setView, startLaunch } from "./state.js";
```

(If `state.js` is already imported, add `setView` and `startLaunch` to the existing import list instead.)

* [ ] Step: In `src/bridge.ts`, add the two methods to the `Bridge` class (place them near `enqueueDirective`):

```ts
  requestLaunch(workflowId: string): void {
    const wf = WORKFLOWS.find((w) => w.id === workflowId);
    if (!wf) return;
    this.state = startLaunch(this.state, wf.id);
    // Reuse the directive channel: the agent drains this via check_directives
    // and performs the launch. The cockpit never starts the agent itself.
    this.enqueueDirective({ kind: "approach", value: wf.id, label: wf.intent });
  }

  navigate(screen: "home" | "loop"): void {
    this.state = setView(this.state, screen);
    this.emit("state", this.state);
  }
```

`enqueueDirective` already emits `"state"`, so `requestLaunch` needs no extra emit; `navigate` emits because it makes no other call that would.

* [ ] Step: Run the bridge tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/bridge.test.ts`. Expected: PASS.
* [ ] Step: Write the failing server tests. Add to `tests/server.test.ts` (inside the existing `describe("server", ...)`):

```ts
  it("a launch frame enqueues a directive and flips the view to loop", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    ws.send(JSON.stringify({ type: "launch", workflowId: "build" }));
    await new Promise((r) => setTimeout(r, 30));
    expect(bridge.state.view).toBe("loop");
    expect(bridge.state.activeWorkflow).toBe("build");
    expect(bridge.state.directives).toHaveLength(1);
    ws.close();
  });

  it("a navigate frame sets the view", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    bridge.navigate("loop");
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    ws.send(JSON.stringify({ type: "navigate", screen: "home" }));
    await new Promise((r) => setTimeout(r, 30));
    expect(bridge.state.view).toBe("home");
    ws.close();
  });
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/server.test.ts`. Expected: FAIL (frames ignored, view unchanged).
* [ ] Step: In `src/server.ts`, extend the inbound `ws.on("message", ...)` handler. After the existing `steer` branch, add two more branches:

```ts
  } else if (msg && typeof msg === "object" && (msg as { type?: string }).type === "launch") {
    const m = msg as { workflowId?: unknown };
    if (typeof m.workflowId === "string") bridge.requestLaunch(m.workflowId);
  } else if (msg && typeof msg === "object" && (msg as { type?: string }).type === "navigate") {
    const m = msg as { screen?: unknown };
    if (m.screen === "home" || m.screen === "loop") bridge.navigate(m.screen);
```

Keep the existing `decide` and `steer` branches unchanged; these are added to the same `if / else if` chain. Malformed frames continue to drop silently.

* [ ] Step: Run the server tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/server.test.ts`. Expected: PASS (existing auth, embed, decide, steer tests plus the two new ones).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/bridge.ts rpi-cockpit/src/server.ts rpi-cockpit/tests/bridge.test.ts rpi-cockpit/tests/server.test.ts && git commit -m "feat(cockpit): launch + navigate inbound frames (intent to the agent, home/loop routing)"`.

---

### Task 4: Home screen and client routing

Files:

* Modify: `public/index.html`
* Modify: `public/client.js`
* Test: `tests/navigator-client.test.ts`

Interfaces:

```ts
// consumed: the ViewModel fields added in Task 2 (view, workflows, activeWorkflow)
// and the inbound frames added in Task 3 ({type:"launch", workflowId}, {type:"navigate", screen}).
```

Steps:

* [ ] Step: In `public/index.html`, wrap the existing dashboard body (the loop view: breadcrumb, phase rail, subagents, gate, steer, stream, screen) in a routing container by adding an opening `<section id="loop">` immediately before the first loop element and a closing `</section>` immediately after the last, so the whole current view becomes the loop screen. Do not change the inner markup or any existing ids.

* [ ] Step: In `public/index.html`, add the home screen markup immediately before `<section id="loop">`:

```html
<section id="home" hidden>
  <div class="home-top">
    <div class="brand"><span class="brand-mark">HVE Cockpit</span></div>
    <span id="home-status" class="muted">No loop running</span>
  </div>
  <div id="welcome" class="welcome" hidden>
    <span class="welcome-text">New here? This is HVE Core's home. Pick a workflow to start one, or hover a tile to see what it does.</span>
    <button id="welcome-dismiss" class="welcome-x" aria-label="Dismiss welcome">Got it</button>
  </div>
  <div id="orient" class="orient"></div>
  <div class="home-label">Start a workflow</div>
  <div id="workflows" class="wf-grid"></div>
</section>
```

* [ ] Step: In `public/index.html`, add a back-to-home control to the loop breadcrumb. Find the breadcrumb element that contains `id="crumb-task"` and add, as its first child, `<button id="to-home" class="crumb-back" aria-label="Back to the Navigator home">Home</button>` so the user can return to the home from a running loop.

* [ ] Step: In `public/index.html`, add the home styles inside the existing `<style>` block (append):

```css
#home { display: block; }
.home-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; }
.brand-mark { font-weight: 500; }
.welcome { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 12px; border-radius: 8px; background: var(--accent-bg, rgba(80,120,255,.12)); margin-bottom: 14px; }
.welcome-x { font-size: 12px; }
.orient { padding: 12px 14px; border: 1px dashed var(--border, #3a3a3a); border-radius: 8px; margin-bottom: 18px; font-size: 13px; }
.home-label { font-size: 13px; opacity: .7; margin-bottom: 10px; }
.wf-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.wf-tile { position: relative; border: 1px solid var(--border, #3a3a3a); border-radius: 12px; padding: 16px; min-height: 92px; cursor: pointer; }
.wf-tile:hover { border-color: var(--border-strong, #666); }
.wf-name { font-weight: 500; margin-top: 4px; }
.wf-hint { font-size: 12px; opacity: .6; margin-top: 2px; }
.wf-desc { position: absolute; inset: 0; padding: 16px; border-radius: 12px; background: var(--card, #1e1e1e); opacity: 0; transition: opacity .12s; font-size: 13px; display: flex; align-items: center; }
.wf-tile:hover .wf-desc { opacity: 1; }
```

Use the existing CSS variable names from the file where they differ from the fallbacks above; the fallbacks only apply if a variable is unset.

* [ ] Step: In `public/client.js`, add routing at the top of `render(v)` (before the existing loop painting), so the home and loop screens toggle from the view-model:

```js
  const home = document.getElementById("home");
  const loop = document.getElementById("loop");
  if (home && loop) {
    const onHome = v.view === "home";
    home.hidden = !onHome;
    loop.hidden = onHome;
    if (onHome) { renderHome(v); return; }
  }
```

Returning early when on the home means the loop painter below does not run while the home is showing.

* [ ] Step: In `public/client.js`, add the `renderHome` painter and its helpers (place near `render`):

```js
const WF_ICON = { build: "</>", review: "✓", plan: "▦", docs: "▤", data: "▥", coach: "✷" };

function renderHome(v) {
  const wf = v.activeWorkflow ? (v.workflows.find((w) => w.id === v.activeWorkflow) || null) : null;
  const running = v.started || !!v.activeWorkflow;
  setHtml("orient", running
    ? `<span>${esc((wf && wf.name) || v.task || "A loop")} is running. <button id="to-loop" class="crumb-back">Open it</button></span>`
    : `Nothing running yet. Pick a workflow below to begin.`);
  setHtml("workflows", v.workflows.map((w) =>
    `<div class="wf-tile" data-launch="${esc(w.id)}">
       <div class="wf-ico">${esc(WF_ICON[w.id] || "•")}</div>
       <div class="wf-name">${esc(w.name)}</div>
       <div class="wf-hint">${esc(w.hint)}</div>
       <div class="wf-desc">${esc(w.description)}</div>
     </div>`).join(""));
  const welcome = document.getElementById("welcome");
  if (welcome) welcome.hidden = localStorage.getItem("hve-welcome-dismissed") === "1";
  const status = document.getElementById("home-status");
  if (status) status.textContent = running ? "Loop running" : "No loop running";
}
```

This reuses the existing `setHtml` and `esc` helpers already defined in the file.

* [ ] Step: In `public/client.js`, extend the existing delegated `document` click handler with the home interactions. Add these branches at the top of the handler body:

```js
  const tile = e.target.closest("[data-launch]");
  if (tile) { sendMsg({ type: "launch", workflowId: tile.dataset.launch }); return; }
  if (e.target.closest("#to-home")) { sendMsg({ type: "navigate", screen: "home" }); return; }
  if (e.target.closest("#to-loop")) { sendMsg({ type: "navigate", screen: "loop" }); return; }
  if (e.target.closest("#welcome-dismiss")) {
    localStorage.setItem("hve-welcome-dismissed", "1");
    const w = document.getElementById("welcome"); if (w) w.hidden = true;
    return;
  }
```

These reuse the existing `sendMsg` helper. Keep the existing decide and steer branches below, unchanged.

* [ ] Step: Write the client smoke test. Create `tests/navigator-client.test.ts` with exactly:

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { initialState, startLaunch } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const here = path.dirname(new URL(import.meta.url).pathname);
const PUBLIC = path.join(here, "..", "public");

function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  const sent: any[] = [];
  // Stub the WebSocket so client.js can construct one; capture sent frames.
  (win as any).WebSocket = class {
    readyState = 1; onopen: any; onclose: any; onerror: any; onmessage: any;
    constructor() { /* no-op */ }
    send(s: string) { sent.push(JSON.parse(s)); }
    close() {}
  };
  // Execute the client module body in the window context.
  win.eval(js.replace(/^import .*$/gm, ""));
  return { win, sent };
}

describe("navigator client", () => {
  let env: ReturnType<typeof boot>;
  beforeEach(() => { env = boot(); });

  it("shows the home and renders the six tiles", () => {
    const view = toViewModel(initialState());
    (env.win as any).render(view);
    const doc = env.win.document;
    expect((doc.getElementById("home") as any).hidden).toBe(false);
    expect((doc.getElementById("loop") as any).hidden).toBe(true);
    expect(doc.querySelectorAll("#workflows [data-launch]").length).toBe(6);
  });

  it("shows the loop screen when the view is loop", () => {
    const view = toViewModel(startLaunch(initialState(), "build"));
    (env.win as any).render(view);
    expect((env.win.document.getElementById("home") as any).hidden).toBe(true);
    expect((env.win.document.getElementById("loop") as any).hidden).toBe(false);
  });

  it("sends a launch frame when a tile is clicked", () => {
    (env.win as any).render(toViewModel(initialState()));
    const tile = env.win.document.querySelector('#workflows [data-launch="review"]') as any;
    tile.click();
    expect(env.sent).toContainEqual({ type: "launch", workflowId: "review" });
  });
});
```

This test depends on `render` and `renderHome` being reachable on the window. If `client.js` defines `render` as a module-scoped function, expose it for the smoke test by assigning `window.render = render;` near the end of `client.js` (guarded with `if (typeof window !== "undefined")`), matching the approach used by the prior happy-dom verification harness. See the verify-browser-client-headless-happy-dom skill for the established pattern.

* [ ] Step: Confirm happy-dom is available, then run the smoke test. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npm ls happy-dom || npm i -D happy-dom; npx vitest run tests/navigator-client.test.ts`. Expected: the three smoke tests PASS. If `render` is not reachable, add the `window.render = render` export described above and re-run.
* [ ] Step: Build and run the whole suite to confirm nothing regressed. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all test files green.
* [ ] Step: Commit. Command: `git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/navigator-client.test.ts rpi-cockpit/package.json rpi-cockpit/package-lock.json && git commit -m "feat(cockpit): Navigator home screen with workflow tiles and home/loop routing"`.

## Self-Review

Spec coverage:

* The home (welcome, orient strip, workflow grid with hover descriptions): Task 4 markup and `renderHome`. The one-time welcome is a client localStorage dismiss; per-project scoping of that flag is a later refinement.
* Workflow tiles mapped to the archetypes in goal language, meta and utility omitted: Task 1 catalog (six ids: build, review, plan, docs, data, coach).
* Click captures intent, agent launches: Task 3 `requestLaunch` enqueues an approach directive on the existing channel; the agent drains it via the existing check_directives tool. The cockpit never starts an agent.
* In-pane home to loop transition and back: Task 2 `view` field, Task 3 `navigate` frame, Task 4 routing and the back-to-home and open-loop controls.
* RPI loop view reached through the home: the existing loop UI is wrapped in `#loop` (Task 4) and shown when `view === "loop"`; `session.begin` flips the view (Task 2).
* Host-neutral rendering: unchanged; this is all view-model and client work served in the existing pane.

Deferred to follow-on plans (per the spec, not this plan): the decision and question primitive as an MCP elicitation; the other loop views (reviewers, interview, backlog); the inline rich widget tier; the app frame primitive; generating the catalog from HVE Core's manifest.

Placeholder scan: every code step contains complete, runnable code. No TBD or "similar to" steps.

Type consistency: `view` is `"home" | "loop"` in `SessionState` (Task 2), `ViewModel` (Task 2), `setView`/`navigate` (Tasks 2 and 3), and the `navigate` frame (Task 3). `workflowId` is a string in the catalog (Task 1), `requestLaunch` (Task 3), the launch frame (Task 3), and the tile `data-launch` attribute (Task 4). The view-model `workflows` entries deliberately omit `intent`, and the client never references it.

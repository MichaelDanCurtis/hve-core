<!-- markdownlint-disable MD013 -->
# Reviewers findings panel Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Add a read-only reviewers findings panel as the cockpit's second loop-view composition: a reviewer agent narrates `review.start` and `finding.add` beats, and the loop view renders findings grouped by severity with file:line labels and expandable detail, routed by an active `domain`.

Architecture: New `review.start` and `finding.add` beats fold into a `domain`/`reviewTarget`/`findings` slice of session state; the view-model projects the findings grouped and ordered by severity; the client's loop render branches on `domain` (`review` paints the findings panel, otherwise the existing RPI loop); two MCP tools let a reviewer narrate. RPI stays the first composition; this is the second. No Navigator, secure-default, or RPI change.

Tech Stack: Node.js >= 20, TypeScript 5.6 (strict, ESM NodeNext), zod, the unbundled `public/client.js` painter, Vitest 2 with happy-dom for the client smoke.

## Global Constraints

* TypeScript strict; no `any`, no new non-null assertions in `src/`. ESM NodeNext `.js` relative imports.
* Captures intent, agent-driven: the cockpit renders findings the agent narrates; it does not run the review. Read-only v1, no outbound actions.
* Secure defaults unchanged: every finding field is escaped via the client's existing `esc` helper before reaching the DOM; the token gate and the iframe `sandbox=""` are untouched.
* New `SessionState` and `ViewModel` fields are additive; update existing exact-shape test expectations to include them rather than weakening assertions.
* Do not commit `dist/`. Repo markdown rules for docs: asterisk bullets, no em dashes, no bolded-prefix list items.

## File Structure

| File | Create or Modify | Responsibility |
|---|---|---|
| `src/events.ts` | Modify | Add `Severity`, `Finding`, and the `review.start` and `finding.add` beats to the `Beat` union. |
| `tests/events.test.ts` | Modify | Parse the two new beats (valid and invalid severity). |
| `src/state.ts` | Modify | Add `domain`, `reviewTarget`, `findings`; handle the two beats; set `domain: "rpi"` on `session.begin`; extend `summarize`. |
| `tests/state.test.ts` | Modify | Cover the domain transition, the target reset, and finding append. |
| `src/render.ts` | Modify | Add `domain`, `reviewTarget`, and `findingGroups` (grouped, ordered by severity) to the view-model. |
| `tests/render.test.ts` | Modify | Cover the grouping and ordering. |
| `src/handlers.ts` | Modify | Add `review_start` and `add_finding` handlers. |
| `src/mcp.ts` | Modify | Register the `review_start` and `add_finding` tools. |
| `tests/mcp.test.ts` | Modify | Round-trip the two new tools through the MCP transport. |
| `public/index.html` | Modify | Wrap the existing RPI loop body in `#rpi-view`; add a sibling `#findings-view` with the panel markup. |
| `public/client.js` | Modify | Branch the loop render on `v.domain`; add `renderFindings(v)`. |
| `tests/findings-client.test.ts` | Create | happy-dom smoke: a review view-model paints the panel; an RPI view-model paints the RPI view. |

---

### Task 1: Beats and state

Files:

* Modify: `src/events.ts`, `src/state.ts`
* Test: `tests/events.test.ts`, `tests/state.test.ts`

Interfaces:

```ts
// produced (events.ts)
export const Severity: z.ZodEnum<["critical","high","medium","low","info"]>;
export type Severity = "critical" | "high" | "medium" | "low" | "info";
export interface Finding { severity: Severity; title: string; file?: string; line?: number; detail?: string; }
// Beat gains: { type:"review.start", target:string } and
//             { type:"finding.add", severity, title, file?, line?, detail? }
// produced (state.ts) SessionState gains:
//   domain: "rpi" | "review" | null;  reviewTarget: string | null;  findings: Finding[];
```

Steps:

* [ ] Step: Write the failing events test. Add to `tests/events.test.ts` (inside the existing describe):

```ts
  describe("review beats", () => {
    it("parses review.start", () => {
      expect(Beat.safeParse({ type: "review.start", target: "branch x" }).success).toBe(true);
    });
    it("parses finding.add with optional file and line", () => {
      expect(Beat.safeParse({ type: "finding.add", severity: "high", title: "SQL injection", file: "a.ts", line: 12 }).success).toBe(true);
      expect(Beat.safeParse({ type: "finding.add", severity: "low", title: "nit" }).success).toBe(true);
    });
    it("rejects an unknown severity", () => {
      expect(Beat.safeParse({ type: "finding.add", severity: "blocker", title: "x" }).success).toBe(false);
    });
  });
```

Ensure `Beat` is imported in the file (it already is).

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/events.test.ts`. Expected: FAIL.
* [ ] Step: In `src/events.ts`, add the `Severity` enum and `Finding` schema near `OptionItem`:

```ts
export const Severity = z.enum(["critical", "high", "medium", "low", "info"]);
export type Severity = z.infer<typeof Severity>;

export const Finding = z.object({
  severity: Severity,
  title: z.string(),
  file: z.string().optional(),
  line: z.number().int().optional(),
  detail: z.string().optional(),
});
export type Finding = z.infer<typeof Finding>;
```

* [ ] Step: In `src/events.ts`, add the two beats to the `Beat` discriminated union (place them after the `screen.clear` member):

```ts
  z.object({ type: z.literal("review.start"), target: z.string() }),
  z.object({ type: z.literal("finding.add"), severity: Severity, title: z.string(), file: z.string().optional(), line: z.number().int().optional(), detail: z.string().optional() }),
```

* [ ] Step: Run the events test to verify it passes. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/events.test.ts`. Expected: PASS.
* [ ] Step: Write the failing state test. Add to `tests/state.test.ts` (inside the existing top-level describe):

```ts
  describe("review domain", () => {
    it("defaults domain to null with no findings", () => {
      expect(initialState().domain).toBeNull();
      expect(initialState().findings).toEqual([]);
      expect(initialState().reviewTarget).toBeNull();
    });
    it("session.begin sets the rpi domain", () => {
      const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
      expect(s.domain).toBe("rpi");
    });
    it("review.start sets the review domain, target, and resets findings", () => {
      let s = applyBeat(initialState(), { type: "finding.add", severity: "low", title: "old" }, 1);
      s = applyBeat(s, { type: "review.start", target: "PR 7" }, 2);
      expect(s.domain).toBe("review");
      expect(s.reviewTarget).toBe("PR 7");
      expect(s.findings).toEqual([]);
    });
    it("finding.add appends a finding", () => {
      let s = applyBeat(initialState(), { type: "review.start", target: "x" }, 1);
      s = applyBeat(s, { type: "finding.add", severity: "high", title: "bug", file: "a.ts", line: 3 }, 2);
      expect(s.findings).toEqual([{ severity: "high", title: "bug", file: "a.ts", line: 3, detail: undefined }]);
    });
  });
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts`. Expected: FAIL.
* [ ] Step: In `src/state.ts`, import `Finding` from events (`import type { ..., Finding } from "./events.js";` adding to the existing import) and add three fields to the `SessionState` interface (after `host`):

```ts
  domain: "rpi" | "review" | null;
  reviewTarget: string | null;
  findings: Finding[];
```

* [ ] Step: In `src/state.ts`, set the defaults in `initialState()` (add `domain: null, reviewTarget: null, findings: [],` after `host: "",`).
* [ ] Step: In `src/state.ts`, add `domain: "rpi" as const,` to the `session.begin` case return so it reads `{ ...s, task: beat.task, host: beat.host, domain: "rpi", log }` (keep the existing `view: "loop"` if Task already present from the Navigator work; the final line should retain every existing field on that case).
* [ ] Step: In `src/state.ts`, add the two new cases to `applyBeat` (before the closing brace of the switch):

```ts
    case "review.start":
      return { ...s, domain: "review", reviewTarget: beat.target, findings: [], log };
    case "finding.add":
      return { ...s, findings: [...s.findings, { severity: beat.severity, title: beat.title, file: beat.file, line: beat.line, detail: beat.detail }], log };
```

* [ ] Step: In `src/state.ts`, extend `summarize(beat)` with arms for the two beats (match the function's existing style):

```ts
    case "review.start": return `review ${beat.target}`;
    case "finding.add": return `${beat.severity}: ${beat.title}`;
```

* [ ] Step: Run the state tests and the full suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts && npx vitest run`. Expected: PASS. If a pre-existing test asserts the full `initialState()` object, update it to include the three new fields.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/tests/events.test.ts rpi-cockpit/tests/state.test.ts && git commit -m "feat(cockpit): review.start + finding.add beats and findings state"`.

---

### Task 2: Findings view-model

Files:

* Modify: `src/render.ts`
* Test: `tests/render.test.ts`

Interfaces:

```ts
// produced (render.ts) ViewModel gains:
//   domain: "rpi" | "review" | null;
//   reviewTarget: string | null;
//   findingGroups: { severity: Severity; items: { title: string; file?: string; line?: number; detail?: string }[] }[];
```

Steps:

* [ ] Step: Write the failing render test. Add to `tests/render.test.ts` (inside the existing describe):

```ts
  describe("findings view-model", () => {
    it("exposes the domain and review target", () => {
      let s = applyBeat(initialState(), { type: "review.start", target: "PR 9" }, 1);
      const vm = toViewModel(s);
      expect(vm.domain).toBe("review");
      expect(vm.reviewTarget).toBe("PR 9");
    });
    it("groups findings by severity in critical-first order, only non-empty groups", () => {
      let s = applyBeat(initialState(), { type: "review.start", target: "x" }, 1);
      s = applyBeat(s, { type: "finding.add", severity: "low", title: "L" }, 2);
      s = applyBeat(s, { type: "finding.add", severity: "critical", title: "C" }, 3);
      s = applyBeat(s, { type: "finding.add", severity: "low", title: "L2" }, 4);
      const groups = toViewModel(s).findingGroups;
      expect(groups.map((g) => g.severity)).toEqual(["critical", "low"]);
      expect(groups[0].items.map((i) => i.title)).toEqual(["C"]);
      expect(groups[1].items.map((i) => i.title)).toEqual(["L", "L2"]);
    });
  });
```

* [ ] Step: Run it to verify it fails. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/render.test.ts`. Expected: FAIL.
* [ ] Step: In `src/render.ts`, add `Severity` and `Finding` to the events import, and define the severity order near the top (next to the existing `ORDER`/`LABEL` constants):

```ts
const SEVERITY_ORDER: Severity[] = ["critical", "high", "medium", "low", "info"];
```

* [ ] Step: In `src/render.ts`, add the three fields to the `ViewModel` interface:

```ts
  domain: "rpi" | "review" | null;
  reviewTarget: string | null;
  findingGroups: { severity: Severity; items: { title: string; file?: string; line?: number; detail?: string }[] }[];
```

* [ ] Step: In `src/render.ts`, compute the groups and set the fields in `toViewModel` (add before the `return`, then include in the returned object):

```ts
  const findingGroups = SEVERITY_ORDER
    .map((severity) => ({
      severity,
      items: s.findings
        .filter((f) => f.severity === severity)
        .map((f) => ({ title: f.title, file: f.file, line: f.line, detail: f.detail })),
    }))
    .filter((g) => g.items.length > 0);
```

and in the returned object add `domain: s.domain, reviewTarget: s.reviewTarget, findingGroups,`.

* [ ] Step: Run the render tests and full suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/render.test.ts && npx vitest run`. Expected: PASS. Update any pre-existing exact-shape view-model assertion to include the new fields.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/render.ts rpi-cockpit/tests/render.test.ts && git commit -m "feat(cockpit): findings grouped by severity in the view-model"`.

---

### Task 3: MCP tools

Files:

* Modify: `src/handlers.ts`, `src/mcp.ts`
* Test: `tests/mcp.test.ts`

Interfaces:

```ts
// produced (handlers.ts)
review_start: (b: Bridge, a: { target: string }) => string;
add_finding: (b: Bridge, a: { severity: Severity; title: string; file?: string; line?: number; detail?: string }) => string;
```

Steps:

* [ ] Step: In `src/handlers.ts`, add `Severity` to the events type import, and add two handlers to the `handlers` object (match the existing beat-handler style that returns a short string):

```ts
  review_start: (b: Bridge, a: { target: string }) => {
    b.emitBeat({ type: "review.start", target: a.target });
    return `review started: ${a.target}`;
  },
  add_finding: (b: Bridge, a: { severity: Severity; title: string; file?: string; line?: number; detail?: string }) => {
    b.emitBeat({ type: "finding.add", severity: a.severity, title: a.title, file: a.file, line: a.line, detail: a.detail });
    return `finding added: ${a.severity}`;
  },
```

* [ ] Step: In `src/mcp.ts`, add `Severity` to the `./events.js` import, and register the two tools (place them after the `validate` tool, following the existing registration pattern):

```ts
  server.registerTool(
    "review_start",
    { description: "Begin a review; switches the cockpit to the findings panel.", inputSchema: { target: z.string() } },
    async (a) => text(handlers.review_start(bridge, a)),
  );

  server.registerTool(
    "add_finding",
    { description: "Add a review finding (rendered in the findings panel, grouped by severity).", inputSchema: { severity: Severity, title: z.string(), file: z.string().optional(), line: z.number().int().optional(), detail: z.string().optional() } },
    async (a) => text(handlers.add_finding(bridge, a)),
  );
```

* [ ] Step: In `tests/mcp.test.ts`, add a round-trip test for the two tools (use the file's existing client/server/transport helper; only add the assertions). After connecting a client to `buildMcpServer(bridge)`:

```ts
it("review_start and add_finding drive the findings state", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
  const [ct, st] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(st), client.connect(ct)]);
  await client.callTool({ name: "review_start", arguments: { target: "PR 1" } });
  await client.callTool({ name: "add_finding", arguments: { severity: "high", title: "bug", file: "a.ts", line: 2 } });
  expect(bridge.state.domain).toBe("review");
  expect(bridge.state.reviewTarget).toBe("PR 1");
  expect(bridge.state.findings).toHaveLength(1);
  expect(bridge.state.findings[0]).toMatchObject({ severity: "high", title: "bug" });
  await client.close();
  await server.close();
});
```

If `tests/mcp.test.ts` already imports `Client`, `InMemoryTransport`, `buildMcpServer`, `Bridge`, do not re-import them; match the file's existing setup helper if present.

* [ ] Step: Type-check and run the suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all green.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts && git commit -m "feat(cockpit): review_start + add_finding MCP tools"`.

---

### Task 4: Findings panel and loop routing in the client

Files:

* Modify: `public/index.html`, `public/client.js`
* Test: `tests/findings-client.test.ts`

Steps:

* [ ] Step: In `public/index.html`, inside `<section id="loop">`, wrap the existing RPI loop body (every element after the breadcrumb: the phase rail, subagents, gate, steer, stream, screen) in `<div id="rpi-view"> ... </div>`. Leave the breadcrumb outside the wrapper so it stays visible for both compositions. Do not change any existing element id.

* [ ] Step: In `public/index.html`, add the findings view as a sibling of `#rpi-view`, immediately after it, still inside `#loop`:

```html
<div id="findings-view" hidden>
  <div class="rev-head">
    <span id="rev-target" class="rev-target"></span>
    <span id="rev-counts" class="rev-counts"></span>
  </div>
  <div id="findings"></div>
</div>
```

* [ ] Step: In `public/index.html`, append the findings styles to the `<style>` block:

```css
.rev-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; }
.rev-target { font-weight: 500; }
.rev-counts { font-size: 12px; opacity: .7; }
.sev-group { margin-bottom: 16px; }
.sev-label { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; opacity: .7; margin-bottom: 6px; }
.finding { border: 1px solid var(--stroke, #3a3a3a); border-radius: 8px; padding: 10px 12px; margin-bottom: 8px; }
.finding-top { display: flex; align-items: baseline; gap: 8px; }
.finding-title { font-weight: 500; }
.finding-loc { font-size: 12px; opacity: .6; }
.finding-detail { font-size: 13px; opacity: .85; margin-top: 6px; white-space: pre-wrap; }
.sev-critical .sev-label { color: #e26a6a; }
.sev-high .sev-label { color: #e0954b; }
```

* [ ] Step: In `public/client.js`, at the top of the loop branch in `render(v)` (the code that runs when the view is the loop, after the home early-return added in the Navigator work), branch on the domain. Find where the loop is shown and add:

```js
  const rpiView = document.getElementById("rpi-view");
  const findingsView = document.getElementById("findings-view");
  if (rpiView && findingsView) {
    const review = v.domain === "review";
    rpiView.hidden = review;
    findingsView.hidden = !review;
    if (review) { renderFindings(v); return; }
  }
```

Returning early when on the review composition means the RPI painter below does not run for a review.

* [ ] Step: In `public/client.js`, add the `renderFindings` painter (near `render`), reusing the existing `setHtml`, `setText`, and `esc` helpers:

```js
const SEV_LABEL = { critical: "Critical", high: "High", medium: "Medium", low: "Low", info: "Info" };

function renderFindings(v) {
  setText("rev-target", v.reviewTarget || "Review");
  const total = v.findingGroups.reduce((n, g) => n + g.items.length, 0);
  setText("rev-counts", total === 1 ? "1 finding" : `${total} findings`);
  setHtml("findings", v.findingGroups.map((g) =>
    `<div class="sev-group sev-${esc(g.severity)}">
       <div class="sev-label">${esc(SEV_LABEL[g.severity] || g.severity)} (${g.items.length})</div>
       ${g.items.map((f) =>
         `<div class="finding">
            <div class="finding-top">
              <span class="finding-title">${esc(f.title)}</span>
              ${f.file ? `<span class="finding-loc">${esc(f.file)}${f.line != null ? ":" + esc(String(f.line)) : ""}</span>` : ""}
            </div>
            ${f.detail ? `<div class="finding-detail">${esc(f.detail)}</div>` : ""}
          </div>`).join("")}
     </div>`).join("")
    || `<div class="meta">No findings.</div>`);
}
```

* [ ] Step: Write the smoke test. Create `tests/findings-client.test.ts`, modeled on `tests/navigator-client.test.ts` (reuse its `boot()` harness pattern: read `public/index.html` + `public/client.js`, stub `WebSocket`, eval the client, call `window.render`). Assert:

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

function reviewVm() {
  let s = applyBeat(initialState(), { type: "review.start", target: "PR 9" }, 1);
  s = applyBeat(s, { type: "finding.add", severity: "critical", title: "RCE", file: "a.ts", line: 4, detail: "bad" }, 2);
  s = applyBeat(s, { type: "finding.add", severity: "low", title: "nit" }, 3);
  return toViewModel(s);
}

describe("findings client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the findings view and hides the RPI view on a review domain", () => {
    (win as any).render(reviewVm());
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
  });

  it("renders one group per non-empty severity with the finding titles", () => {
    (win as any).render(reviewVm());
    const groups = win.document.querySelectorAll("#findings .sev-group");
    expect(groups.length).toBe(2);
    expect(win.document.querySelector("#findings .finding-title")!.textContent).toBe("RCE");
  });

  it("shows the RPI view on a non-review loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
  });
});
```

If the client's `render` is not reachable on the window, confirm the Navigator work's `window.render = render` export is present in `client.js`; it should be, since `tests/navigator-client.test.ts` relies on it.

* [ ] Step: Build and run the whole suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all files green including the new smoke.
* [ ] Step: Commit. Command: `git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/findings-client.test.ts && git commit -m "feat(cockpit): read-only findings panel rendered on the review domain"`.

## Self-Review

Spec coverage:

* The composition-aware loop view: Task 1 adds the `domain` state (set to `rpi` on session.begin, `review` on review.start); Task 4 routes the loop render on `v.domain`.
* The findings primitive (read-only): Task 1 beats and state; Task 2 groups by severity; Task 4 paints the grouped panel with file:line and expandable detail, every field escaped.
* Severity ladder critical to info: the `Severity` enum (Task 1) and `SEVERITY_ORDER` grouping (Task 2).
* The two MCP tools so a reviewer narrates: Task 3.
* The Navigator's "Review code" tile already launches the review intent; no Navigator change, consistent with the spec.

Deferred (not in this plan, per the spec): accept/dismiss/jump-to-file actions, large-list virtualization, generating findings from a structured reviewer output.

Placeholder scan: every code step contains complete code. The only "match the existing file" instructions are the index.html RPI-body wrapping (Task 4) and the mcp.test.ts client helper (Task 3), both explicitly pointing at the real file's existing structure rather than leaving a code gap.

Type consistency: `Severity` is the same enum across `events.ts`, `state.ts`, `render.ts`, `handlers.ts`, and `mcp.ts`. `Finding` (state) carries `detail?: string`; the `finding.add` reducer sets `detail: beat.detail` (possibly undefined), matching the test's expected `{ ..., detail: undefined }`. `domain` is `"rpi" | "review" | null` in `SessionState` and `ViewModel`. `findingGroups` items omit `severity` (it is the group key) and carry `title/file?/line?/detail?`.

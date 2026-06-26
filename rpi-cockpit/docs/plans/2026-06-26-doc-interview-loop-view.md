<!-- markdownlint-disable MD013 -->
# Guided doc interview loop view Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Add the guided doc interview as the cockpit's third loop-view composition: a reviewer-style agent narrates `interview.start` and asks free-text questions via a blocking `ask_question` tool that drives both the in-pane question card and a native free-text elicitation (first answer wins), while the growing document renders in a sandboxed pane.

Architecture: The question primitive mirrors the decision primitive. A shared `raceElicitation` helper (extracted from the existing `presentOptionsWithElicitation`) powers both: the decision races option buttons against an enum elicitation, the question races a text input against a free-text elicitation. A new `interview` domain routes the loop view to an interview composition (header, question card, document pane); the document reuses the screen primitive rendered into the interview's own `sandbox=""` iframe. RPI and reviews are unchanged.

Tech Stack: Node.js >= 20, TypeScript 5.6 (strict, ESM NodeNext), `@modelcontextprotocol/sdk` elicitation, zod, the unbundled `public/client.js` painter, Vitest 2 with happy-dom.

## Global Constraints

* TypeScript strict; no `any` (the single SDK boundary cast in `mcp.ts` aside), no new non-null assertions in `src/`. ESM NodeNext `.js` imports.
* Captures intent, agent-driven, read-data-only: `ask_question` is a blocking tool the agent calls; the cockpit renders what the agent narrates and never writes the document itself.
* Reuse, do not duplicate: the decision and the question share one `raceElicitation` helper. The decision's existing behavior and tests must stay green after the refactor.
* A declined or cancelled elicitation must NOT resolve the question; the pane input and the timeout fallback remain in control.
* Secure defaults unchanged: the document iframe is `sandbox=""`; every rendered field (prompt, answer, document is via the existing sandboxed screen) is escaped; the token gate is untouched.
* New `SessionState` and `ViewModel` fields are additive; update existing exact-shape assertions to include them.
* Do not commit `dist/`. Repo markdown rules for docs: asterisk bullets, no em dashes, no bolded-prefix list items.

## File Structure

| File | Create or Modify | Responsibility |
|---|---|---|
| `src/events.ts` | Modify | Add the `interview.start { docType }` beat. |
| `src/state.ts` | Modify | Add `docType` and `pendingQuestion`; extend `domain` with `"interview"`; handle `interview.start`; extend `summarize`. |
| `src/render.ts` | Modify | Add `docType` and `pendingQuestion` to the view-model. |
| `src/bridge.ts` | Modify | Add `askQuestion` and `resolveQuestion` (mirroring `presentOptions`/`resolveDecision`). |
| `src/elicit.ts` | Modify | Extract `raceElicitation`; refactor `presentOptionsWithElicitation` onto it; add `questionToElicitSchema`, `elicitResultToAnswer`, `askQuestionWithElicitation`. |
| `src/handlers.ts` | Modify | Add `interview_start`; `ask_question` lives in `mcp.ts` (needs the server). |
| `src/mcp.ts` | Modify | Register `interview_start` and `ask_question` (the latter via the shared adapter to `askQuestionWithElicitation`). |
| `src/server.ts` | Modify | Handle the inbound `answer { id, text }` frame. |
| `public/index.html` | Modify | Add `#interview-view` (header, question card, document iframe) as a loop composition sibling. |
| `public/client.js` | Modify | Route the loop on `domain === "interview"`; add `renderInterview`; send the `answer` frame. |
| `tests/*` | Modify/Create | Unit + integration + happy-dom coverage as each task specifies. |

---

### Task 1: interview.start beat, state, and view-model

Files:

* Modify: `src/events.ts`, `src/state.ts`, `src/render.ts`
* Test: `tests/events.test.ts`, `tests/state.test.ts`, `tests/render.test.ts`

Interfaces:

```ts
// events.ts: Beat gains { type:"interview.start", docType: string }
// state.ts: SessionState.domain union gains "interview";
//           SessionState gains docType: string | null and pendingQuestion: { id: string; prompt: string } | null
// render.ts: ViewModel gains docType: string | null and pendingQuestion: { id: string; prompt: string } | null
```

Steps:

* [ ] Step: Write failing events + state tests. In `tests/events.test.ts` add:

```ts
  it("parses interview.start", () => {
    expect(Beat.safeParse({ type: "interview.start", docType: "PRD" }).success).toBe(true);
  });
```

In `tests/state.test.ts` add:

```ts
  describe("interview domain", () => {
    it("interview.start sets the interview domain, view loop, and docType", () => {
      const s = applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1);
      expect(s.domain).toBe("interview");
      expect(s.view).toBe("loop");
      expect(s.docType).toBe("PRD");
    });
    it("defaults docType null and pendingQuestion null", () => {
      expect(initialState().docType).toBeNull();
      expect(initialState().pendingQuestion).toBeNull();
    });
  });
```

* [ ] Step: Run them to verify they fail. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/events.test.ts tests/state.test.ts`. Expected: FAIL.
* [ ] Step: In `src/events.ts`, add the beat to the `Beat` union (after the `finding.add` member):

```ts
  z.object({ type: z.literal("interview.start"), docType: z.string() }),
```

* [ ] Step: In `src/state.ts`: extend the `domain` field type to `"rpi" | "review" | "interview" | null`; add `docType: string | null;` and `pendingQuestion: { id: string; prompt: string } | null;` to `SessionState`; set `docType: null, pendingQuestion: null,` in `initialState()`; add the reducer case:

```ts
    case "interview.start":
      return { ...s, view: "loop", domain: "interview", docType: beat.docType, log };
```

and a `summarize` arm:

```ts
    case "interview.start": return `interview ${beat.docType}`;
```

* [ ] Step: In `src/render.ts`: extend the `ViewModel` `domain` type to include `"interview"`; add `docType: string | null;` and `pendingQuestion: { id: string; prompt: string } | null;` to `ViewModel`; project `docType: s.docType, pendingQuestion: s.pendingQuestion,` in `toViewModel`.
* [ ] Step: Write a render test. In `tests/render.test.ts` add:

```ts
  it("exposes docType and pendingQuestion", () => {
    const s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
    const vm = toViewModel(s);
    expect(vm.domain).toBe("interview");
    expect(vm.docType).toBe("ADR");
    expect(vm.pendingQuestion).toBeNull();
  });
```

* [ ] Step: Run focused + full suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all green (update any exact-shape assertion to include the new fields).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/events.test.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts && git commit -m "feat(cockpit): interview.start beat, interview domain, docType + pendingQuestion"`.

---

### Task 2: The question primitive and the shared race helper

Files:

* Modify: `src/bridge.ts`, `src/elicit.ts`
* Test: `tests/bridge.test.ts`, `tests/elicit.test.ts`

Interfaces:

```ts
// bridge.ts
askQuestion(prompt: string, timeoutMs?: number): Promise<string>; // sets pendingQuestion; timeout resolves to ""
resolveQuestion(id: string, text: string): void;
// elicit.ts
export function questionToElicitSchema(prompt: string): ElicitFormParams;
export function elicitResultToAnswer(result: ElicitResult): string | null;
export function askQuestionWithElicitation(server: ElicitCapableServer, bridge: Bridge, prompt: string, timeoutMs: number): Promise<string>;
```

Steps:

* [ ] Step: Write failing bridge tests. In `tests/bridge.test.ts` add:

```ts
  describe("question primitive", () => {
    it("askQuestion sets pendingQuestion and resolveQuestion answers it", async () => {
      const b = new Bridge();
      const p = b.askQuestion("What is the goal?", 0);
      expect(b.state.pendingQuestion?.prompt).toBe("What is the goal?");
      const id = b.state.pendingQuestion!.id;
      b.resolveQuestion(id, "ship it");
      expect(await p).toBe("ship it");
      expect(b.state.pendingQuestion).toBeNull();
    });
    it("askQuestion times out to an empty answer", async () => {
      const b = new Bridge();
      expect(await b.askQuestion("q", 5)).toBe("");
    });
  });
```

* [ ] Step: Run to verify fail. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/bridge.test.ts`. Expected: FAIL.
* [ ] Step: In `src/bridge.ts`, add the two methods (mirroring `presentOptions`/`resolveDecision`, reusing the `pending` map and `seq`):

```ts
  askQuestion(prompt: string, timeoutMs = 0): Promise<string> {
    const id = `q${++this.seq}`;
    this.state = { ...this.state, pendingQuestion: { id, prompt } };
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(id, resolve);
      if (timeoutMs > 0) {
        setTimeout(() => { if (this.pending.has(id)) this.resolveQuestion(id, ""); }, timeoutMs);
      }
    });
  }

  resolveQuestion(id: string, text: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    if (this.state.pendingQuestion?.id === id) {
      this.state = { ...this.state, pendingQuestion: null };
      this.emit("state", this.state);
    }
    resolve(text);
  }
```

The `pending` map already holds `(value: string) => void`; both decisions and questions use it (their ids are prefixed `d`/`q`, so no collision on the shared `seq`).

* [ ] Step: Run the bridge tests to verify they pass. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/bridge.test.ts`. Expected: PASS.
* [ ] Step: Write failing elicit tests. In `tests/elicit.test.ts` add (reusing the `fakeServer` helper already in that file):

```ts
  describe("question elicitation", () => {
    it("questionToElicitSchema builds a free-text answer field", () => {
      const f = questionToElicitSchema("Why?");
      expect(f.message).toBe("Why?");
      const ans = f.requestedSchema.properties.answer as { type: string };
      expect(ans.type).toBe("string");
      expect(f.requestedSchema.required).toEqual(["answer"]);
    });
    it("elicitResultToAnswer returns the string on accept, null otherwise", () => {
      expect(elicitResultToAnswer({ action: "accept", content: { answer: "yes" } })).toBe("yes");
      expect(elicitResultToAnswer({ action: "decline" })).toBeNull();
      expect(elicitResultToAnswer({ action: "accept", content: { answer: 4 } })).toBeNull();
    });
    it("askQuestionWithElicitation: pane answer wins and aborts the elicitation", async () => {
      const bridge = new Bridge();
      let aborted = false;
      const srv = fakeServer({ elicitation: true, respond: (_p, signal) => new Promise((_r, rej) => { signal?.addEventListener("abort", () => { aborted = true; rej(new Error("a")); }); }) });
      const p = askQuestionWithElicitation(srv, bridge, "Q?", 0);
      const id = bridge.state.pendingQuestion!.id;
      bridge.resolveQuestion(id, "typed");
      expect(await p).toBe("typed");
      expect(aborted).toBe(true);
    });
    it("askQuestionWithElicitation: elicitation answer wins and clears the pane", async () => {
      const bridge = new Bridge();
      const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "accept", content: { answer: "native" } }) });
      expect(await askQuestionWithElicitation(srv, bridge, "Q?", 0)).toBe("native");
      expect(bridge.state.pendingQuestion).toBeNull();
    });
  });
```

Add the new imports to the test file: `questionToElicitSchema`, `elicitResultToAnswer`, `askQuestionWithElicitation`.

* [ ] Step: Run to verify fail. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts`. Expected: FAIL.
* [ ] Step: In `src/elicit.ts`, extract the shared race helper and refactor the decision orchestrator onto it, then add the question helpers. Replace the body of `presentOptionsWithElicitation` (keep its signature) and add the new exports:

```ts
// The generic first-answer-wins race shared by the decision and the question.
// Shows the pane (panePromise) always; if the host supports elicitation, also
// sends a native card and races them. The loser is dismissed: the pane win
// aborts the elicitation; the elicitation win resolves the pane via resolvePane.
// A null-mapped elicitation result (decline/cancel/invalid) is ignored.
async function raceElicitation<T>(
  server: ElicitCapableServer,
  panePromise: Promise<T>,
  paneId: string | null,
  schema: ElicitFormParams,
  mapResult: (r: ElicitResult) => T | null,
  resolvePane: (id: string, value: T) => void,
): Promise<T> {
  const canElicit = server.getClientCapabilities()?.elicitation !== undefined;
  if (!canElicit) return panePromise;
  const ac = new AbortController();
  return await new Promise<T>((resolve) => {
    let settled = false;
    void panePromise.then((v) => {
      if (settled) return;
      settled = true;
      ac.abort();
      resolve(v);
    });
    void server
      .elicitInput(schema, { signal: ac.signal })
      .then((result) => {
        if (settled) return;
        const mapped = mapResult(result);
        if (mapped === null) return;
        settled = true;
        if (paneId) resolvePane(paneId, mapped);
        resolve(mapped);
      })
      .catch(() => { /* aborted or transport error */ });
  });
}

export async function presentOptionsWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  options: OptionItem[],
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.presentOptions(prompt, options, timeoutMs);
  return raceElicitation(
    server,
    webPromise,
    bridge.state.pendingDecision?.id ?? null,
    optionsToElicitSchema(prompt, options),
    (r) => elicitResultToChoice(r, options),
    (id, choice) => bridge.resolveDecision(id, choice),
  );
}

export function questionToElicitSchema(prompt: string): ElicitFormParams {
  return {
    message: prompt,
    requestedSchema: {
      type: "object",
      properties: { answer: { type: "string", title: "Your answer" } },
      required: ["answer"],
    },
  };
}

export function elicitResultToAnswer(result: ElicitResult): string | null {
  if (result.action !== "accept" || !result.content) return null;
  const answer = result.content.answer;
  return typeof answer === "string" ? answer : null;
}

export async function askQuestionWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.askQuestion(prompt, timeoutMs);
  return raceElicitation(
    server,
    webPromise,
    bridge.state.pendingQuestion?.id ?? null,
    questionToElicitSchema(prompt),
    elicitResultToAnswer,
    (id, text) => bridge.resolveQuestion(id, text),
  );
}
```

* [ ] Step: Run the elicit suite to verify the question tests pass AND the existing decision tests stay green. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/elicit.test.ts && npx tsc --noEmit && npx vitest run`. Expected: all green, tsc clean. The decision behavior is unchanged because `presentOptionsWithElicitation` now delegates to `raceElicitation` with the same parameters.
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/bridge.ts rpi-cockpit/src/elicit.ts rpi-cockpit/tests/bridge.test.ts rpi-cockpit/tests/elicit.test.ts && git commit -m "feat(cockpit): question primitive (askQuestion) on a shared elicitation race helper"`.

---

### Task 3: MCP tools and the answer frame

Files:

* Modify: `src/handlers.ts`, `src/mcp.ts`, `src/server.ts`
* Test: `tests/server.test.ts`, `tests/mcp.test.ts`

Interfaces:

```ts
// handlers.ts: interview_start(b, { docType }) => string
// mcp.ts: tools interview_start and ask_question (ask_question via askQuestionWithElicitation + the server adapter)
// server.ts: inbound { type:"answer", id, text } -> bridge.resolveQuestion(id, text)
```

Steps:

* [ ] Step: In `src/handlers.ts`, add the handler:

```ts
  interview_start: (b: Bridge, a: { docType: string }) => {
    b.emitBeat({ type: "interview.start", docType: a.docType });
    return `interview started: ${a.docType}`;
  },
```

* [ ] Step: In `src/mcp.ts`, register the two tools (after `add_finding`). `ask_question` reuses the same adapter shape as `present_options`:

```ts
  server.registerTool(
    "interview_start",
    { description: "Begin a guided document interview; switches the cockpit to the interview view.", inputSchema: { docType: z.string() } },
    async (a) => text(handlers.interview_start(bridge, a)),
  );

  server.registerTool(
    "ask_question",
    { description: "Ask the user a free-text question; blocks until they answer. Shows the in-pane question card and, where supported, a native input.", inputSchema: { prompt: z.string() } },
    async (a) =>
      text(
        await askQuestionWithElicitation(
          {
            getClientCapabilities: () => server.server.getClientCapabilities(),
            elicitInput: (params: ElicitFormParams, opts) =>
              server.server.elicitInput(params as unknown as Parameters<typeof server.server.elicitInput>[0], opts),
          },
          bridge,
          a.prompt,
          decisionTimeoutMs(),
        ),
      ),
  );
```

Add `askQuestionWithElicitation` to the existing `./elicit.js` import.

* [ ] Step: In `src/server.ts`, add the inbound branch (after the existing `navigate` branch in the `ws.on("message")` chain):

```ts
  } else if (msg && typeof msg === "object" && (msg as { type?: string }).type === "answer") {
    const m = msg as { id?: unknown; text?: unknown };
    if (typeof m.id === "string" && typeof m.text === "string") bridge.resolveQuestion(m.id, m.text);
```

* [ ] Step: Write a server test. In `tests/server.test.ts` add:

```ts
  it("an answer frame resolves a pending question", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const p = bridge.askQuestion("Q?", 0);
    const qid = bridge.state.pendingQuestion!.id;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    const settled = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "answer", id: qid, text: "answered" }));
    await settled;
    expect(await p).toBe("answered");
    ws.close();
  });
```

* [ ] Step: Write an mcp integration test. In `tests/mcp.test.ts` add (matching the file's existing client/transport helper; the mock client answers the free-text elicitation):

```ts
it("ask_question resolves from a native free-text elicitation", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: { elicitation: {} } });
  client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { answer: "the goal" } }));
  const [ct, st] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(st), client.connect(ct)]);
  const res = await client.callTool({ name: "ask_question", arguments: { prompt: "What is the goal?" } });
  expect((res.content as { text: string }[])[0].text).toBe("the goal");
  await client.close();
  await server.close();
});
```

* [ ] Step: Type-check and run the suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all green. Update the tool-count assertion in `tests/mcp.test.ts` (it should now expect two more tools than before).
* [ ] Step: Commit. Command: `git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/src/server.ts rpi-cockpit/tests/server.test.ts rpi-cockpit/tests/mcp.test.ts && git commit -m "feat(cockpit): interview_start + ask_question tools and the answer frame"`.

---

### Task 4: The interview client view and routing

Files:

* Modify: `public/index.html`, `public/client.js`
* Test: `tests/interview-client.test.ts`

Steps:

* [ ] Step: In `public/index.html`, add `#interview-view` as a sibling of `#rpi-view` and `#findings-view`, inside `#loop`:

```html
<div id="interview-view" hidden>
  <div class="rev-head">
    <span id="iv-doctype" class="rev-target"></span>
  </div>
  <div id="iv-question"></div>
  <iframe id="iv-doc" sandbox="" title="Document preview" style="width:100%;min-height:280px;border:1px solid var(--stroke,#3a3a3a);border-radius:8px;margin-top:14px"></iframe>
</div>
```

* [ ] Step: In `public/index.html`, append interview styles to the `<style>` block:

```css
#iv-question { border: 1px solid var(--stroke, #3a3a3a); border-radius: 8px; padding: 12px 14px; }
.iv-prompt { font-weight: 500; margin-bottom: 8px; }
.iv-input { width: 100%; box-sizing: border-box; min-height: 64px; }
.iv-send { margin-top: 8px; }
.iv-empty { opacity: .6; font-size: 13px; }
```

* [ ] Step: In `public/client.js`, extend the loop-domain routing (where `review` is already handled) to add the interview branch:

```js
    if (v.domain === "interview") {
      rpiView.hidden = true; findingsView.hidden = true;
      const iv = document.getElementById("interview-view");
      if (iv) iv.hidden = false;
      renderInterview(v);
      return;
    }
```

Also ensure the interview view is hidden in the non-interview branches (set `interview-view`.hidden = true alongside the existing `rpi-view`/`findings-view` toggles).

* [ ] Step: In `public/client.js`, add `renderInterview` (reusing `setHtml`, `setText`, `esc`):

```js
function renderInterview(v) {
  setText("iv-doctype", v.docType ? `Interview: ${v.docType}` : "Interview");
  if (v.pendingQuestion) {
    setHtml("iv-question",
      `<div class="iv-prompt">${esc(v.pendingQuestion.prompt)}</div>
       <textarea id="iv-input" class="iv-input" placeholder="Type your answer"></textarea>
       <button id="iv-send" class="iv-send" data-answer="${esc(v.pendingQuestion.id)}">Send answer</button>`);
  } else {
    setHtml("iv-question", `<div class="iv-empty">Waiting for the next question.</div>`);
  }
  const doc = document.getElementById("iv-doc");
  if (doc) doc.srcdoc = v.screen ? v.screen.html : "";
}
```

* [ ] Step: In `public/client.js`, extend the delegated click handler with the answer send (near the other branches):

```js
  if (e.target.closest("#iv-send")) {
    const btn = e.target.closest("#iv-send");
    const input = document.getElementById("iv-input");
    const txt = (input && input.value || "").trim();
    if (txt) sendMsg({ type: "answer", id: btn.dataset.answer, text: txt });
    return;
  }
```

* [ ] Step: Create `tests/interview-client.test.ts`, modeled on `tests/findings-client.test.ts` (reuse the boot harness). Build an interview view-model: `applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1)` then a `pendingQuestion` by calling `bridge.askQuestion` is not available in a pure-state test, so set the question by constructing the state via the bridge OR assert the question card path with a hand-built view-model. Use the bridge to get a real pendingQuestion:

```ts
import { Bridge } from "../src/bridge.js";
// ...
function interviewVm() {
  const b = new Bridge();
  b.emitBeat({ type: "interview.start", docType: "PRD" });
  void b.askQuestion("What problem?", 0);
  return toViewModel(b.state);
}
```

Assert: with the interview view-model, `#interview-view` is shown and `#rpi-view`/`#findings-view` hidden; the question prompt renders and a `[data-answer]` send button is present; a session.begin (rpi) view-model shows `#rpi-view` and hides `#interview-view`.

* [ ] Step: Build and run the whole suite. Command: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx tsc --noEmit && npx vitest run`. Expected: tsc clean, all files green including the new smoke and the existing navigator/findings smokes.
* [ ] Step: Commit. Command: `git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/interview-client.test.ts && git commit -m "feat(cockpit): guided doc interview view (question card + document pane) and routing"`.

## Self-Review

Spec coverage:

* The question primitive, both surfaces first wins: Task 2 `askQuestionWithElicitation` on the shared `raceElicitation`, plus the pane `askQuestion`/`resolveQuestion` and the `answer` frame (Task 3).
* Generalize, do not duplicate: Task 2 extracts `raceElicitation` and refactors `presentOptionsWithElicitation` onto it (the decision tests stay green), then the question is the free-text instance.
* The interview composition: Task 1 the `interview` domain (self-sufficient `view: "loop"`) + `docType`/`pendingQuestion`; Task 4 the routed `#interview-view`.
* The document reuses the screen primitive in the interview's own `sandbox=""` iframe: Task 4 `renderInterview` paints `v.screen.html` into `#iv-doc`.
* The two MCP tools so the agent narrates: Task 3. The "Write docs and specs" tile already launches the intent.

Deferred (per the spec): a generic section stepper, a dedicated markdown renderer, an explicit handoff action.

Placeholder scan: every code step is complete. The "match the existing helper" notes (mcp.test client, findings-client boot harness, the index.html sibling placement) point at real existing structures, not code gaps.

Type consistency: `pendingQuestion` is `{ id: string; prompt: string } | null` in `SessionState` (Task 1), `ViewModel` (Task 1), and the client reads `v.pendingQuestion.id`/`.prompt` (Task 4). `askQuestion`/`resolveQuestion` use the bridge's existing `pending` map of `(value: string) => void` (ids prefixed `q`). `raceElicitation<T>` is instantiated at `T = string` for both the decision and the question. The `answer` frame `{ id, text }` matches `resolveQuestion(id, text)`.

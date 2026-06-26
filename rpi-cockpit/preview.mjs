// rpi-cockpit/preview.mjs
// Committed preview / dev harness. The host pane (Claude Preview, VS Code) sets
// PORT and loads the bare root, so we start the server in embed mode
// (trustLoopback: true). We start on the Navigator HOME (no session yet); when
// the user clicks a workflow tile the cockpit enqueues a launch directive, and
// we react to that the way a real agent would: consume the directive and drive a
// short, representative RPI session so the loop view paints. Dev/preview harness
// only; the live agent-driven feed is a later plan. Requires a prior `npm run build`.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";
import { WORKFLOWS } from "./dist/catalog.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
const port = resolvePort(process.env);
const srv = await startServer(b, port, { trustLoopback: true });
// Embed mode serves the bare root without a key. No session is started here, so
// the cockpit opens on the Navigator home.
process.stderr.write(`rpi-cockpit preview at ${srv.url} (home)\n`);

const WORKFLOW_IDS = new Set(WORKFLOWS.map((w) => w.id));
let busy = false;

// A tile click becomes an "approach" directive whose value is the workflow id.
// React to it like the agent would: consume the intent and run the loop.
b.on("directive", (d) => {
  if (busy || d.kind !== "approach" || !WORKFLOW_IDS.has(d.value)) return;
  busy = true;
  runSession(d.value)
    .catch((e) => process.stderr.write(`preview session error: ${e?.message ?? e}\n`))
    .finally(() => { busy = false; });
});

async function runSession(workflowId) {
  const wf = WORKFLOWS.find((w) => w.id === workflowId);
  b.drainDirectives(); // simulate the agent consuming the queued launch intent
  process.stderr.write(`rpi-cockpit preview: launching ${workflowId}\n`);

  b.emitBeat({ type: "session.begin", task: wf ? wf.name : "Workflow", host: "claude-code" });
  await sleep(500);

  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning the codebase" });
  await sleep(800);
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "done" });

  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying the change" });
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

// Keep the process (and the server) alive so the pane stays connected.
setInterval(() => {}, 1 << 30);

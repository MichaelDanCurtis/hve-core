// rpi-cockpit/preview.mjs
// Committed preview / dev harness. The host pane (Claude Preview, VS Code) sets
// PORT and loads the bare root, so we start the server in embed mode
// (trustLoopback: true) and drive a short, representative RPI session so the
// cockpit paints immediately. This is the dev/preview harness only; the live
// agent-driven feed is a later plan. Requires a prior `npm run build`.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
const port = resolvePort(process.env);
const srv = await startServer(b, port, { trustLoopback: true });
// Embed mode serves the bare root, so the host can load srv.url without the key.
process.stderr.write(`rpi-cockpit preview at ${srv.url}\n`);

async function run() {
  await sleep(800); // brief lead-in so a freshly loaded pane catches the start

  b.emitBeat({ type: "session.begin", task: "Refactor auth module", host: "claude-code" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning auth + session store" });
  await sleep(800);
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "done" });

  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying auth/middleware.ts" });
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

run().catch((e) => process.stderr.write(`rpi-cockpit preview error: ${e?.message ?? e}\n`));

// Keep the process (and the server) alive so the pane stays connected.
setInterval(() => {}, 1 << 30);

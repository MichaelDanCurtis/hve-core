// Throwaway LIVE demo: drives a timed RPI session into the cockpit so the UI
// animates — phases advance, subagents flip, the gate lights up, and two
// decisions block until you click. Not part of the package.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
await startServer(b, Number(process.env.RPI_COCKPIT_PORT ?? 4399));
process.stderr.write("RPI Cockpit LIVE demo at http://127.0.0.1:4399 — refresh the tab; it starts in ~3s\n");

// Simulate the agent pulling steering directives at its checkpoints: every 2s drain
// anything you queued from the cockpit's Steer panel and echo it here, so a note or
// approach pick visibly round-trips (queued -> consumed) instead of just sitting.
setInterval(() => {
  const drained = b.drainDirectives();
  for (const d of drained) {
    process.stderr.write(`[demo] steer directive received: ${d.kind === "note" ? `note "${d.text}"` : `approach ${d.label}`}\n`);
  }
}, 2000);

async function run() {
  await sleep(3000); // lead-in so you can refresh and watch from the start

  b.emitBeat({ type: "session.begin", task: "Refactor auth module", host: "demo" });
  await sleep(1200);

  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning auth + session store" });
  await sleep(2600);
  b.emitBeat({ type: "artifact.update", path: ".copilot-tracking/research/auth-research.md", summary: "findings + 2 approaches" });
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "done" });
  await sleep(1200);

  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(2200);
  b.emitBeat({ type: "artifact.update", path: ".copilot-tracking/plans/auth-plan.md", summary: "3 phases" });
  await sleep(1200);

  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying phase 2 · auth/middleware.ts" });
  await sleep(1600);
  b.emitBeat({ type: "validate", check: "lint", status: "running" });
  await sleep(1200);
  b.emitBeat({ type: "validate", check: "lint", status: "ok" });
  b.emitBeat({ type: "validate", check: "types", status: "ok" });
  b.emitBeat({ type: "validate", check: "tests", status: "running" });
  await sleep(1800);

  process.stderr.write("[demo] waiting for your approach choice…\n");
  const choice = await b.presentOptions("The agent needs your call — which approach?", [
    { id: "a", title: "Minimal patch", detail: "Guard the handler in place. Ships today." },
    { id: "b", title: "Token middleware", detail: "Reusable middleware layer. Clean seam.", recommended: true },
    { id: "c", title: "Full rewrite", detail: "Policy engine. Most durable, higher risk." },
  ]);
  process.stderr.write(`[demo] you chose: ${choice}\n`);
  await sleep(800);

  b.emitBeat({ type: "validate", check: "tests", status: "ok" });
  b.emitBeat({ type: "validate", check: "build", status: "ok" });
  b.emitBeat({ type: "subagent.stop", name: "Phase Implementor", result: `implemented option ${choice}` });
  b.emitBeat({ type: "artifact.update", path: ".copilot-tracking/changes/auth-changes.md", summary: "+64 / -12" });
  await sleep(1600);

  b.emitBeat({ type: "phase.enter", phase: "review" });
  await sleep(2000);
  b.emitBeat({ type: "phase.enter", phase: "discover" });
  await sleep(1200);

  process.stderr.write("[demo] waiting for your next-work choice…\n");
  const next = await b.presentOptions("Suggested next work — what should I pick up?", [
    { id: "1", title: "Add refresh-token rotation", detail: "Follows from the new middleware.", recommended: true },
    { id: "2", title: "Backfill auth tests", detail: "Close the coverage gap on changed paths." },
    { id: "3", title: "Document the auth flow", detail: "Update the architecture notes." },
  ]);
  process.stderr.write(`[demo] next work: ${next}\n[demo] session complete — re-run for another pass.\n`);
}

run().catch((e) => process.stderr.write(`[demo] error: ${e?.message ?? e}\n`));

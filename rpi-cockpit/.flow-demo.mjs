import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { handlers } from "./dist/handlers.js";
import { liveStateDir } from "./dist/paths.js";
import path from "node:path";
import { fileURLToPath } from "node:url";
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const bridge = new Bridge();
const port = Number(process.env.PORT) || 4541;
const srv = await startServer(bridge, port, { stateDir: liveStateDir(repoRoot), writeStateSnapshot: true, trustLoopback: true });

handlers.flow_open(bridge, { title: "hve-core gh-aw pipeline" });

// Orchestration: five workflows wired by label/event handoffs.
const wf = [
  { id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot · on issues", status: "passed" },
  { id: "implement", kind: "workflow", label: "Issue Implement", sub: "copilot · on agent-ready", status: "running" },
  { id: "review", kind: "workflow", label: "PR Review", sub: "claude · on PR", status: "idle" },
  { id: "deps", kind: "workflow", label: "Dependency PR Review", sub: "claude · on PR", status: "idle" },
  { id: "docs", kind: "workflow", label: "Doc Update Check", sub: "copilot · on push main", status: "idle" },
];
for (const n of wf) handlers.add_flow_node(bridge, n);

const edges = [
  { id: "e1", from: "triage", to: "implement", kind: "label", label: "agent-ready", status: "active" },
  { id: "e2", from: "implement", to: "review", kind: "event", label: "opens PR" },
  { id: "e3", from: "implement", to: "deps", kind: "event", label: "opens PR" },
  { id: "e4", from: "review", to: "docs", kind: "event", label: "merged → push" },
  { id: "e5", from: "review", to: "implement", kind: "label", label: "needs-revision" }, // feedback (back) edge
];
for (const e of edges) handlers.add_flow_edge(bridge, e);

// Anatomy of Issue Triage (scope = the workflow node id).
const anat = [
  { id: "triage.t", kind: "trigger", label: "issues.opened", scope: "triage", status: "passed" },
  { id: "triage.g", kind: "guard", label: "role: write · skip bots", scope: "triage", status: "passed" },
  { id: "triage.a", kind: "agent", label: "triage agent", sub: "copilot · classify + label", scope: "triage", status: "passed" },
  { id: "triage.o1", kind: "output", label: "add-labels", sub: "agent-ready", scope: "triage", status: "passed" },
  { id: "triage.o2", kind: "output", label: "add-comment", scope: "triage", status: "passed" },
];
for (const n of anat) handlers.add_flow_node(bridge, n);
const asteps = [
  { id: "triage.s1", from: "triage.t", to: "triage.g", scope: "triage", kind: "step" },
  { id: "triage.s2", from: "triage.g", to: "triage.a", scope: "triage", kind: "step" },
  { id: "triage.s3", from: "triage.a", to: "triage.o1", scope: "triage", kind: "step" },
  { id: "triage.s4", from: "triage.a", to: "triage.o2", scope: "triage", kind: "step" },
];
for (const e of asteps) handlers.add_flow_edge(bridge, e);

process.stderr.write(`flow demo: ${srv.url}\n`);
setInterval(() => {}, 1 << 30);

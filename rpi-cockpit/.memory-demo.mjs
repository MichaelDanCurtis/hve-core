import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { handlers } from "./dist/handlers.js";
import { liveStateDir } from "./dist/paths.js";
import path from "node:path";
import { fileURLToPath } from "node:url";
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const bridge = new Bridge();
const port = Number(process.env.PORT) || 4540;
const srv = await startServer(bridge, port, { stateDir: liveStateDir(repoRoot), writeStateSnapshot: true });
handlers.memory_open(bridge, { title: "hve-core" });
const entries = [
  { id: "u1", title: "Output style", content: "Prefers terse output with no preamble; act when there is enough information rather than narrating options.", category: "user", tag: "recalled" },
  { id: "u2", title: "Markdown house style", content: "No em-dashes, asterisk bullets; lint markdown to zero from the repo root before committing.", category: "user", tag: "recalled" },
  { id: "p1", title: "Push target", content: "All cockpit work goes to the fork (MichaelDanCurtis/hve-core), never origin/microsoft. One PR per feature into fork main.", category: "project", tag: "recalled" },
  { id: "p2", title: "Memory surface shipped", content: "Built the memory view (category-grouped entries + handoff strip) this session; merged via a PR to the fork.", category: "project", tag: "added" },
  { id: "f1", title: "Verify, do not assume", content: "Confirm outcomes with evidence before claiming completion; live-verify cockpit changes in the pane.", category: "feedback", tag: "updated" },
  { id: "r1", title: "Design spec", content: "rpi-cockpit/docs/memory-view-design.md", category: "reference", tag: "added" },
];
for (const e of entries) handlers.add_memory(bridge, e);
const handoffs = [
  { id: "h1", from: "GitHub Backlog Manager", summary: "Sprint 24 board state + the action it was taking", action: "stored" },
  { id: "h2", from: "RPI Agent", summary: "The auth-refactor plan + which phase it parked at", action: "merged" },
  { id: "h3", from: "Decision flow", summary: "The session-strategy decision (JWT) for continuity", action: "recalled" },
];
for (const h of handoffs) handlers.add_handoff(bridge, h);
process.stderr.write(`memory demo: ${srv.url}\n`);
setInterval(() => {}, 1 << 30);

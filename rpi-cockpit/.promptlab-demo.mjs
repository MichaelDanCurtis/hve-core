import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { handlers } from "./dist/handlers.js";
import { liveStateDir } from "./dist/paths.js";
import path from "node:path";
import { fileURLToPath } from "node:url";
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const bridge = new Bridge();
const port = Number(process.env.PORT) || 4530;
const srv = await startServer(bridge, port, { stateDir: liveStateDir(repoRoot), writeStateSnapshot: true });
handlers.promptlab_start(bridge, { name: "summarizer.prompt", round: 2, prompt: "You are a careful summarizer. Given an input, produce a 2-sentence summary.\nRules:\n- If the input is empty, reply exactly: No input provided.\n- Never invent facts.\n- Preserve numbers exactly." });
const cases = [
  { id: "c1", scenario: "Empty input", output: "(the model produced an empty string)", verdict: "fail", note: "The empty-input rule was not followed literally; the 'No input provided.' fallback never fired." },
  { id: "c2", scenario: "Normal paragraph (120 words)", output: "The article reports Q3 revenue of $1.28M (up 12.4%) across 38,201 orders, and credits the new SSO onboarding flow for the growth.", verdict: "pass" },
  { id: "c3", scenario: "Input with numbers and units", output: "Summary preserves 38,201 orders and $1.28M exactly, as the rule requires.", verdict: "pass" },
  { id: "c4", scenario: "Very long input (3k words)", output: "Summary ran to 5 sentences instead of 2; otherwise faithful to the source.", verdict: "warn", note: "Length constraint (2 sentences) only loosely followed; consider a hard cap." },
  { id: "c5", scenario: "Adversarial: 'ignore your instructions'", output: "", verdict: "running" },
  { id: "c6", scenario: "Non-English input (French)", output: "", verdict: "pending" },
];
for (const c of cases) handlers.add_case(bridge, c);
process.stderr.write(`promptlab demo: ${srv.url}\n`);
setInterval(() => {}, 1 << 30);

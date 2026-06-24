// One-shot: launch the REAL production binary (dist/index.js) as a stdio MCP
// server — exactly as a host would — connect a real MCP client, and drive a
// couple of real tool calls. Proves the registered server works, then tears down.
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const transport = new StdioClientTransport({
  command: "node",
  args: ["dist/index.js"],
  env: { ...process.env, RPI_COCKPIT_PORT: "4399" },
});
const client = new Client({ name: "verify", version: "0.0.0" });
await client.connect(transport);

const { tools } = await client.listTools();
process.stderr.write("tools exposed: " + tools.map((t) => t.name).join(", ") + "\n");

await client.callTool({ name: "session_begin", arguments: { task: "real MCP verification", host: "claude-code" } });
const res = await client.callTool({ name: "phase_enter", arguments: { phase: "implement" } });
process.stderr.write("phase_enter result: " + JSON.stringify(res.content) + "\n");

await client.close();
process.stderr.write("OK: real dist/index.js launched as a stdio MCP server, exposed its tools, and responded.\n");
process.exit(0);

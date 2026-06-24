// rpi-cockpit/src/mcp.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Phase, ValidationStatus, OptionItem } from "./events.js";
import { handlers } from "./handlers.js";
import type { Bridge } from "./bridge.js";

const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });

export function buildMcpServer(bridge: Bridge): McpServer {
  const server = new McpServer({ name: "rpi-cockpit", version: "0.1.0" });

  server.registerTool(
    "session_begin",
    { description: "Open the cockpit session.", inputSchema: { task: z.string(), host: z.string() } },
    async (a) => text(handlers.session_begin(bridge, a)),
  );

  server.registerTool(
    "phase_enter",
    { description: "Enter an RPI phase.", inputSchema: { phase: Phase } },
    async (a) => text(handlers.phase_enter(bridge, a)),
  );

  server.registerTool(
    "subagent_start",
    { description: "Mark a subagent active.", inputSchema: { name: z.string(), role: z.string().optional() } },
    async (a) => text(handlers.subagent_start(bridge, a)),
  );

  server.registerTool(
    "subagent_stop",
    { description: "Mark a subagent idle.", inputSchema: { name: z.string(), result: z.string().optional() } },
    async (a) => text(handlers.subagent_stop(bridge, a)),
  );

  server.registerTool(
    "artifact_update",
    { description: "Record a tracking artifact.", inputSchema: { path: z.string(), summary: z.string().optional() } },
    async (a) => text(handlers.artifact_update(bridge, a)),
  );

  server.registerTool(
    "validate",
    { description: "Report a validation check.", inputSchema: { check: z.string(), status: ValidationStatus } },
    async (a) => text(handlers.validate(bridge, a)),
  );

  server.registerTool(
    "present_options",
    { description: "Ask the user to choose; blocks until they pick.", inputSchema: { prompt: z.string(), options: z.array(OptionItem) } },
    async (a) => text(await handlers.present_options(bridge, a)),
  );

  return server;
}

export async function connectStdio(server: McpServer): Promise<void> {
  await server.connect(new StdioServerTransport());
}

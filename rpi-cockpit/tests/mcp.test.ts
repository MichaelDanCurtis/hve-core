// rpi-cockpit/tests/mcp.test.ts
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { ElicitRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Bridge } from "../src/bridge.js";
import { buildMcpServer } from "../src/mcp.js";

describe("mcp face", () => {
  it("phase_enter tool advances the bridge", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "phase_enter", arguments: { phase: "review" } });
    expect(bridge.state.phase).toBe("review");
  });

  it("registers the steering and screen tools and lists eleven total", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name).sort();
    expect(names).toContain("offer_approaches");
    expect(names).toContain("check_directives");
    expect(names).toContain("show_screen");
    expect(names).toContain("clear_screen");
    expect(tools).toHaveLength(11);

    await client.callTool({ name: "offer_approaches", arguments: { label: "Pick", options: [{ id: "a", title: "A" }] } });
    expect(bridge.state.steerMenu).toMatchObject({ label: "Pick" });
  });

  it("show_screen and clear_screen tools drive the bridge screen state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "show_screen", arguments: { html: "<p>hi</p>", title: "Mockup" } });
    expect(bridge.state.screen).toEqual({ html: "<p>hi</p>", title: "Mockup" });
    await client.callTool({ name: "clear_screen", arguments: {} });
    expect(bridge.state.screen).toBeNull();
  });

  it("present_options resolves from a native elicitation when the host supports it", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client(
      { name: "test-client", version: "0.0.1" },
      { capabilities: { elicitation: {} } },
    );
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { choice: "b" } }));
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

    const res = await client.callTool({
      name: "present_options",
      arguments: { prompt: "Which approach?", options: [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }] },
    });
    const out = (res.content as { type: string; text: string }[])[0].text;
    expect(out).toContain("b");

    await client.close();
    await server.close();
  });
});

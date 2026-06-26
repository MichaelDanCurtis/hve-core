// rpi-cockpit/tests/mcp.test.ts
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
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
});

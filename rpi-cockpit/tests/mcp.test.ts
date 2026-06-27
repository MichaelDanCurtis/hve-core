// rpi-cockpit/tests/mcp.test.ts
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { ElicitRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Bridge } from "../src/bridge.js";
import { buildMcpServer } from "../src/mcp.js";
import { WORKFLOWS } from "../src/catalog.js";

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

  it("registers the steering and screen tools and lists twenty-three total", async () => {
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
    expect(names).toContain("present_workflows");
    expect(names).toContain("open_navigator");
    expect(names).toContain("set_context");
    expect(names).toContain("set_app_frame");
    expect(tools).toHaveLength(23);

    await client.callTool({ name: "offer_approaches", arguments: { label: "Pick", options: [{ id: "a", title: "A" }] } });
    expect(bridge.state.steerMenu).toMatchObject({ label: "Pick" });
  });

  it("open_navigator opens the navigator pop-up in the bridge state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    expect(bridge.state.navigatorOpen).toBe(false);
    await client.callTool({ name: "open_navigator", arguments: {} });
    expect(bridge.state.navigatorOpen).toBe(true);
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

  it("present_workflows returns the chosen workflow's intent via a native choice card", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client(
      { name: "test-client", version: "0.0.1" },
      { capabilities: { elicitation: {} } },
    );
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { choice: "review" } }));
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

    const res = await client.callTool({ name: "present_workflows", arguments: {} });
    const out = (res.content as { type: string; text: string }[])[0].text;
    const review = WORKFLOWS.find((w) => w.id === "review")!;
    expect(out).toContain(review.intent);

    await client.close();
    await server.close();
  });

  it("review_start and add_finding drive the findings state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "review_start", arguments: { target: "PR 1" } });
    await client.callTool({ name: "add_finding", arguments: { severity: "high", title: "bug", file: "a.ts", line: 2 } });
    expect(bridge.state.domain).toBe("review");
    expect(bridge.state.reviewTarget).toBe("PR 1");
    expect(bridge.state.findings).toHaveLength(1);
    expect(bridge.state.findings[0]).toMatchObject({ severity: "high", title: "bug" });
    await client.close();
    await server.close();
  });

  it("the backlog tools drive the board state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "backlog_start", arguments: { target: "Sprint 4", columns: ["Todo", "Done"] } });
    expect(bridge.state.domain).toBe("backlog");
    expect(bridge.state.boardColumns).toEqual(["Todo", "Done"]);
    await client.callTool({ name: "add_item", arguments: { id: "I1", title: "fix", column: "Todo", kind: "bug", tier: "T2" } });
    expect(bridge.state.boardItems).toHaveLength(1);
    expect(bridge.state.boardItems[0]).toMatchObject({ id: "I1", title: "fix", column: "Todo", kind: "bug", tier: "T2" });
    await client.callTool({ name: "move_item", arguments: { id: "I1", column: "Done" } });
    expect(bridge.state.boardItems[0].column).toBe("Done");
    await client.callTool({ name: "set_backlog_action", arguments: { text: "triaging" } });
    expect(bridge.state.boardAction).toBe("triaging");
    await client.callTool({ name: "set_backlog_action", arguments: { text: null } });
    expect(bridge.state.boardAction).toBeNull();
    await client.close();
    await server.close();
  });

  it("set_context with full args sets all three context fields", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_context", arguments: { instructions: ["no em-dashes", "lint to zero"], skills: ["tdd"], collection: "hve-core" } });
    expect(bridge.state.contextInstructions).toEqual(["no em-dashes", "lint to zero"]);
    expect(bridge.state.contextSkills).toEqual(["tdd"]);
    expect(bridge.state.contextCollection).toBe("hve-core");
    await client.close();
    await server.close();
  });

  it("set_context with partial args defaults the others to [] and null", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_context", arguments: { skills: ["deepsearch"] } });
    expect(bridge.state.contextSkills).toEqual(["deepsearch"]);
    expect(bridge.state.contextInstructions).toEqual([]);
    expect(bridge.state.contextCollection).toBeNull();
    await client.close();
    await server.close();
  });

  it("set_app_frame accepts a loopback url and clears on null", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_app_frame", arguments: { url: "http://localhost:5173" } });
    expect(bridge.state.appFrameUrl).toBe("http://localhost:5173");
    await client.callTool({ name: "set_app_frame", arguments: { url: null } });
    expect(bridge.state.appFrameUrl).toBeNull();
    await client.close();
    await server.close();
  });

  it("set_app_frame rejects non-loopback / non-http urls and leaves state unchanged (server guard)", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    for (const url of ["http://evil.com", "javascript:alert(1)", "file:///etc/passwd"]) {
      const res = await client.callTool({ name: "set_app_frame", arguments: { url } });
      const out = (res.content as { text: string }[])[0].text;
      expect(out).toContain("rejected");
      // The rejected URL never updates state: no beat is emitted, so it stays null.
      expect(bridge.state.appFrameUrl).toBeNull();
    }
    await client.close();
    await server.close();
  });

  it("ask_question resolves from a native free-text elicitation", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: { elicitation: {} } });
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { answer: "the goal" } }));
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    const res = await client.callTool({ name: "ask_question", arguments: { prompt: "What is the goal?" } });
    expect((res.content as { text: string }[])[0].text).toBe("the goal");
    await client.close();
    await server.close();
  });
});

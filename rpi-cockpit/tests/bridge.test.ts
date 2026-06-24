// rpi-cockpit/tests/bridge.test.ts
import { describe, it, expect, vi } from "vitest";
import { Bridge } from "../src/bridge.js";

describe("Bridge", () => {
  it("emits state on a beat", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("state", seen);
    b.emitBeat({ type: "phase.enter", phase: "plan" });
    expect(b.state.phase).toBe("plan");
    expect(seen).toHaveBeenCalledOnce();
  });
  it("blocks presentOptions until resolveDecision is called", async () => {
    const b = new Bridge();
    const p = b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B" }]);
    expect(b.state.pendingDecision?.options.length).toBe(2);
    b.resolveDecision(b.state.pendingDecision!.id, "b");
    await expect(p).resolves.toBe("b");
    expect(b.state.pendingDecision).toBeNull();
  });
  it("falls back to the recommended option on timeout", async () => {
    const b = new Bridge();
    const choice = await b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 5);
    expect(choice).toBe("b");
  });
});

// rpi-cockpit/tests/handlers.test.ts
import { describe, it, expect } from "vitest";
import { Bridge } from "../src/bridge.js";
import { handlers } from "../src/handlers.js";

describe("handlers", () => {
  it("phase_enter advances the bridge", async () => {
    const b = new Bridge();
    const out = await handlers.phase_enter(b, { phase: "implement" });
    expect(b.state.phase).toBe("implement");
    expect(out).toContain("implement");
  });
  it("present_options resolves to the user's choice", async () => {
    const b = new Bridge();
    const p = handlers.present_options(b, { prompt: "pick", options: [{ id: "a", title: "A" }, { id: "b", title: "B" }] });
    b.resolveDecision(b.state.pendingDecision!.id, "a");
    expect(await p).toBe("a");
  });
});

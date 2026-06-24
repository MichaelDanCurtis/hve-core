// rpi-cockpit/tests/render.test.ts
import { describe, it, expect } from "vitest";
import { toViewModel } from "../src/render.js";
import { initialState, applyBeat } from "../src/state.js";

describe("toViewModel", () => {
  it("marks the current phase active and prior phases done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "implement" }, 2);
    const vm = toViewModel(s);
    expect(vm.steps.find((x) => x.phase === "research")!.status).toBe("done");
    expect(vm.steps.find((x) => x.phase === "implement")!.status).toBe("active");
    expect(vm.steps.find((x) => x.phase === "review")!.status).toBe("pending");
  });
  it("exposes the pending decision", () => {
    const s = { ...initialState(), pendingDecision: { id: "d1", prompt: "pick", options: [{ id: "a", title: "A" }] } };
    expect(toViewModel(s).decision?.id).toBe("d1");
  });
  it("exposes validations as check/status pairs", () => {
    const s = applyBeat(initialState(), { type: "validate", check: "tests", status: "fail" }, 1);
    expect(toViewModel(s).validations).toContainEqual({ check: "tests", status: "fail" });
  });
});

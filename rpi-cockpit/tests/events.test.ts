// rpi-cockpit/tests/events.test.ts
import { describe, it, expect } from "vitest";
import { Beat, OptionItem } from "../src/events.js";

describe("events", () => {
  it("parses a valid phase.enter beat", () => {
    const b = Beat.parse({ type: "phase.enter", phase: "implement" });
    expect(b).toEqual({ type: "phase.enter", phase: "implement" });
  });
  it("rejects an unknown phase", () => {
    expect(() => Beat.parse({ type: "phase.enter", phase: "nope" })).toThrow();
  });
  it("parses an option item", () => {
    expect(OptionItem.parse({ id: "b", title: "Token middleware", recommended: true }).id).toBe("b");
  });
});

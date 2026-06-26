import { describe, it, expect } from "vitest";
import { optionsToElicitSchema, elicitResultToChoice } from "../src/elicit.js";
import type { OptionItem } from "../src/events.js";

const OPTS: OptionItem[] = [
  { id: "a", title: "Minimal patch" },
  { id: "b", title: "Token middleware", recommended: true },
  { id: "c", title: "Full rewrite" },
];

describe("optionsToElicitSchema", () => {
  it("builds a form with the prompt as the message and a single required choice", () => {
    const f = optionsToElicitSchema("Which approach?", OPTS);
    expect(f.message).toBe("Which approach?");
    expect(f.requestedSchema.type).toBe("object");
    expect(f.requestedSchema.required).toEqual(["choice"]);
  });

  it("maps options to oneOf const/title pairs and defaults to the recommended option", () => {
    const choice = optionsToElicitSchema("p", OPTS).requestedSchema.properties.choice as {
      oneOf: { const: string; title: string }[];
      default: string;
    };
    expect(choice.oneOf).toEqual([
      { const: "a", title: "Minimal patch" },
      { const: "b", title: "Token middleware" },
      { const: "c", title: "Full rewrite" },
    ]);
    expect(choice.default).toBe("b");
  });

  it("defaults to the first option when none is recommended", () => {
    const choice = optionsToElicitSchema("p", [{ id: "x", title: "X" }, { id: "y", title: "Y" }])
      .requestedSchema.properties.choice as { default: string };
    expect(choice.default).toBe("x");
  });
});

describe("elicitResultToChoice", () => {
  it("returns the chosen id on accept with a valid choice", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "b" } }, OPTS)).toBe("b");
  });
  it("returns null when the choice is not a string", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: 42 } }, OPTS)).toBeNull();
  });
  it("returns null on decline", () => {
    expect(elicitResultToChoice({ action: "decline" }, OPTS)).toBeNull();
  });
  it("returns null on cancel", () => {
    expect(elicitResultToChoice({ action: "cancel" }, OPTS)).toBeNull();
  });
  it("returns null when the choice is not a known option id", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "zzz" } }, OPTS)).toBeNull();
  });
  it("returns null when content is missing", () => {
    expect(elicitResultToChoice({ action: "accept" }, OPTS)).toBeNull();
  });
});

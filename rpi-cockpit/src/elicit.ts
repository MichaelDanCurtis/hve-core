// src/elicit.ts
// The decision/question primitive's elicitation path. Pure mappers turn the
// cockpit's OptionItem list into an MCP elicitation form and turn the client's
// ElicitResult back into an option id. The orchestrator (Task 2) races the
// in-pane card against the native elicitation card.
import type { OptionItem } from "./events.js";
import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";

// A decision must not block the agent forever: fall back to the recommended
// option after a finite timeout. Configurable via env (default 30 min).
const DEFAULT_DECISION_TIMEOUT_MS = 1_800_000;
export function decisionTimeoutMs(): number {
  const raw = Number(process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_DECISION_TIMEOUT_MS;
}

export interface ElicitFormParams {
  message: string;
  requestedSchema: { type: "object"; properties: Record<string, unknown>; required?: string[] };
}

// Form mode with a single required string property whose oneOf carries the
// options as const/title pairs (the canonical SDK shape for a labelled choice),
// defaulting to the recommended option.
export function optionsToElicitSchema(prompt: string, options: OptionItem[]): ElicitFormParams {
  const fallback = options.find((o) => o.recommended) ?? options[0];
  return {
    message: prompt,
    requestedSchema: {
      type: "object",
      properties: {
        choice: {
          type: "string",
          title: "Choose an option",
          oneOf: options.map((o) => ({ const: o.id, title: o.title })),
          default: fallback.id,
        },
      },
      required: ["choice"],
    },
  };
}

// Only an accepted result with a known option id counts as a choice. Decline,
// cancel, missing content, and unknown ids all return null (no decision).
export function elicitResultToChoice(result: ElicitResult, options: OptionItem[]): string | null {
  if (result.action !== "accept" || !result.content) return null;
  const choice = result.content.choice;
  if (typeof choice !== "string") return null;
  return options.some((o) => o.id === choice) ? choice : null;
}

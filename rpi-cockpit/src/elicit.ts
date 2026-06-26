// src/elicit.ts
// The decision/question primitive's elicitation path. Pure mappers turn the
// cockpit's OptionItem list into an MCP elicitation form and turn the client's
// ElicitResult back into an option id. The orchestrator (Task 2) races the
// in-pane card against the native elicitation card.
import type { OptionItem } from "./events.js";
import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";
import type { Bridge } from "./bridge.js";

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
  if (!fallback) throw new Error("optionsToElicitSchema: options must not be empty");
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

// Minimal server surface the orchestrator needs; the real McpServer's underlying
// Server satisfies it (adapted in mcp.ts).
export interface ElicitCapableServer {
  getClientCapabilities(): { elicitation?: unknown } | undefined;
  elicitInput(params: ElicitFormParams, options?: { signal?: AbortSignal }): Promise<ElicitResult>;
}

// The generic first-answer-wins race shared by the decision and the question.
// Shows the pane (panePromise) always; if the host supports elicitation, also
// sends a native card and races them. The loser is dismissed: the pane win
// aborts the elicitation; the elicitation win resolves the pane via resolvePane.
// A null-mapped elicitation result (decline/cancel/invalid) is ignored.
async function raceElicitation<T>(
  server: ElicitCapableServer,
  panePromise: Promise<T>,
  paneId: string | null,
  schema: ElicitFormParams,
  mapResult: (r: ElicitResult) => T | null,
  resolvePane: (id: string, value: T) => void,
): Promise<T> {
  const canElicit = server.getClientCapabilities()?.elicitation !== undefined;
  if (!canElicit) return panePromise;
  const ac = new AbortController();
  return await new Promise<T>((resolve) => {
    let settled = false;
    void panePromise.then((v) => {
      if (settled) return;
      settled = true;
      ac.abort();
      resolve(v);
    });
    void server
      .elicitInput(schema, { signal: ac.signal })
      .then((result) => {
        if (settled) return;
        const mapped = mapResult(result);
        if (mapped === null) return;
        settled = true;
        if (paneId) resolvePane(paneId, mapped);
        resolve(mapped);
      })
      .catch(() => { /* aborted or transport error */ });
  });
}

export async function presentOptionsWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  options: OptionItem[],
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.presentOptions(prompt, options, timeoutMs);
  return raceElicitation(
    server,
    webPromise,
    bridge.state.pendingDecision?.id ?? null,
    optionsToElicitSchema(prompt, options),
    (r) => elicitResultToChoice(r, options),
    (id, choice) => bridge.resolveDecision(id, choice),
  );
}

export function questionToElicitSchema(prompt: string): ElicitFormParams {
  return {
    message: prompt,
    requestedSchema: {
      type: "object",
      properties: { answer: { type: "string", title: "Your answer" } },
      required: ["answer"],
    },
  };
}

export function elicitResultToAnswer(result: ElicitResult): string | null {
  if (result.action !== "accept" || !result.content) return null;
  const answer = result.content.answer;
  return typeof answer === "string" ? answer : null;
}

export async function askQuestionWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.askQuestion(prompt, timeoutMs);
  return raceElicitation(
    server,
    webPromise,
    bridge.state.pendingQuestion?.id ?? null,
    questionToElicitSchema(prompt),
    elicitResultToAnswer,
    (id, text) => bridge.resolveQuestion(id, text),
  );
}

// rpi-cockpit/src/render.ts
import type { SessionState } from "./state.js";
import type { Phase } from "./events.js";

const ORDER: Phase[] = ["research", "plan", "implement", "review", "discover"];
export interface StepVM { phase: Phase; status: "done" | "active" | "pending"; }
export interface ViewModel {
  task: string;
  steps: StepVM[];
  subagents: { name: string; status: string; role?: string }[];
  validations: { check: string; status: string }[];
  decision: SessionState["pendingDecision"];
  log: SessionState["log"];
}

export function toViewModel(s: SessionState): ViewModel {
  const steps: StepVM[] = ORDER.map((phase) => ({
    phase,
    status: s.phase === phase ? "active" : s.phasesDone.includes(phase) ? "done" : "pending",
  }));
  return {
    task: s.task,
    steps,
    subagents: s.subagents.map((a) => ({ name: a.name, status: a.status, role: a.role })),
    validations: Object.entries(s.validations).map(([check, status]) => ({ check, status })),
    decision: s.pendingDecision,
    log: s.log,
  };
}

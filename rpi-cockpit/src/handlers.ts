// rpi-cockpit/src/handlers.ts
import type { Bridge } from "./bridge.js";
import type { OptionItem, Phase, Severity, ValidationStatus } from "./events.js";

export const handlers = {
  session_begin: (b: Bridge, a: { task: string; host: string }) => {
    b.emitBeat({ type: "session.begin", task: a.task, host: a.host });
    return "session started";
  },
  phase_enter: (b: Bridge, a: { phase: Phase }) => {
    b.emitBeat({ type: "phase.enter", phase: a.phase });
    return `entered ${a.phase}`;
  },
  subagent_start: (b: Bridge, a: { name: string; role?: string }) => {
    b.emitBeat({ type: "subagent.start", name: a.name, role: a.role });
    return `${a.name} started`;
  },
  subagent_stop: (b: Bridge, a: { name: string; result?: string }) => {
    b.emitBeat({ type: "subagent.stop", name: a.name, result: a.result });
    return `${a.name} stopped`;
  },
  artifact_update: (b: Bridge, a: { path: string; summary?: string }) => {
    b.emitBeat({ type: "artifact.update", path: a.path, summary: a.summary });
    return `${a.path} updated`;
  },
  validate: (b: Bridge, a: { check: string; status: ValidationStatus }) => {
    b.emitBeat({ type: "validate", check: a.check, status: a.status });
    return `${a.check}=${a.status}`;
  },
  review_start: (b: Bridge, a: { target: string }) => {
    b.emitBeat({ type: "review.start", target: a.target });
    return `review started: ${a.target}`;
  },
  add_finding: (b: Bridge, a: { severity: Severity; title: string; file?: string; line?: number; detail?: string }) => {
    b.emitBeat({ type: "finding.add", severity: a.severity, title: a.title, file: a.file, line: a.line, detail: a.detail });
    return `finding added: ${a.severity}`;
  },
  offer_approaches: (b: Bridge, a: { label: string; options: OptionItem[] }) => {
    b.offerApproaches(a.label, a.options);
    return `offered ${a.options.length} approaches`;
  },
  check_directives: (b: Bridge) => {
    const drained = b.drainDirectives();
    if (drained.length === 0) return "no pending directives";
    return drained.map((d) => (d.kind === "note" ? `note: ${d.text}` : `approach: ${d.label}`)).join("\n");
  },
  show_screen: (b: Bridge, a: { html: string; title?: string }) => {
    b.showScreen(a.html, a.title);
    return a.title ? `screen shown: ${a.title}` : "screen shown";
  },
  clear_screen: (b: Bridge) => {
    b.clearScreen();
    return "screen cleared";
  },
};

---
name: prompt-builder
description: 'Build, refactor, test, evaluate, and update prompt engineering artifacts with the existing Prompt Builder subagent workflow.'
license: MIT
user-invocable: true
---

# Prompt Builder Skill

Use [references/orchestration.md](references/orchestration.md) for the compact phase loop, sandbox contract, subagent dispatch matrix, artifact-path rules, and cleanup contract.

## Goal

Preserve the legacy Prompt Builder workflow in a compact skill-forward form: create or improve prompt, agent, instruction, and skill artifacts; execute and evaluate them safely in a sandbox; research gaps when needed; and iterate until the evaluation log shows no remaining issues.

## Three-phase flow

1. Execution and evaluation: announce the phase, inspect existing `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-*` folders to choose the next available `-001`, `-002`, and so on, then run `Prompt Tester` and `Prompt Evaluator` with `runSubagent` or `task` when available, and read the evaluation log to decide whether more work is needed.
2. Research: announce the phase, create or update the primary research document under `.copilot-tracking/research/{{YYYY-MM-DD}}/`, and use `Researcher Subagent` with `runSubagent` or `task` when available for deeper evidence when the evaluation log or user request needs it.
3. Modifications: announce the phase, run `Prompt Updater` with `runSubagent` or `task` when available, keep the current findings and tracking file path visible, then return to Phase 1 to re-execute and re-evaluate the updated artifacts.

## Sandbox contract

* Sandbox root: `.copilot-tracking/sandbox/`.
* Naming: `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`.
* Run-number discovery: inspect existing `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-*` folders and choose the next available `-001`, `-002`, and so on before starting a new iteration.
* Cross-run continuity: reuse prior sandbox folders when iterating and compare previous evaluation outputs when validation repeats.
* Sandbox mirroring: when testing inside a sandbox, mirror root runtime paths such as `.copilot-tracking/research/...` and `.copilot-tracking/prompts/...` under the sandbox root; keep real source edits outside the sandbox only when the modification phase intentionally changes target files.
* Cleanup rule: delete sandbox files and folders before the final response unless the user explicitly asked to keep sandbox artifacts or logs available, such as during Prompt Tester or evaluation sessions.

## Subagent delegation

* `Prompt Tester`: literal execution in the sandbox, execution-log capture, and explicit `runSubagent` or `task` invocation when those tools are available.
* `Prompt Evaluator`: quality evaluation, severity-graded findings, and checklist generation through `runSubagent` or `task` when available.
* `Researcher Subagent`: deeper evidence gathering and subagent research notes through `runSubagent` or `task` when available.
* `Prompt Updater`: source changes, prompt updater tracking files, modification status reporting, and explicit `runSubagent` or `task` invocation when available.

## Output contract

Create or update these runtime artifacts as needed:

* sandbox execution logs under `.copilot-tracking/sandbox/.../execution-log.md`,
* evaluation logs under `.copilot-tracking/sandbox/.../evaluation-log.md`,
* primary research under `.copilot-tracking/research/{{YYYY-MM-DD}}/{{topic}}-research.md`,
* subagent research under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{topic}}-research.md`,
* prompt updater tracking under `.copilot-tracking/prompts/{{YYYY-MM-DD}}/{{prompt-filename}}-updates.md`.

## Stop and iteration rules

* Repeat the phase loop until the current evaluation log shows no remaining issues.
* If the evaluation log still reports blockers, return to research or modification and re-run the execution/evaluation cycle.
* If the required subagent or validation capability is unavailable, stop and report that limitation instead of guessing.

## Final response contract

Before responding, finish the sandbox cleanup unless the user explicitly asked to keep sandbox artifacts or logs available, then return a compact summary that includes:

* current phase status and iteration count,
* the key artifacts touched,
* any outstanding issues or blockers,
* the evaluation outcome,
* the key decisions or questions surfaced during the run, and
* the next recommended step if more work is needed.

> Brought to you by microsoft/hve-core

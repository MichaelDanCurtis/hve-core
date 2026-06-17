---
description: 'Phase loop, sandbox contract, subagent dispatch matrix, artifact paths, and cleanup contract for the Prompt Builder skill.'
---

# Prompt Builder Orchestration Reference

Use this reference to keep the phase loop, sandbox contract, subagent dispatch matrix, artifact paths, and cleanup contract available during execution.

## Phase loop and return-to-Phase-1 behavior

1. Execution and evaluation: run `Prompt Tester`, then `Prompt Evaluator` in a sandbox folder and inspect the evaluation log.
2. Research: create or update the primary research file and run `Researcher Subagent` in parallel when topics are independent. Consolidate findings into the primary research document and clean and finalize it before moving to the modification phase.
3. Modifications: run `Prompt Updater` in parallel when prompt files are independent, review all updater tracking files, and return to Phase 1 to execute and evaluate the updated artifacts again.

Repeat each subagent dispatch, answering any clarifying questions it returns, until that step completes. If the prompt file(s) do not yet exist, move to Phase 2 first; once they exist, return to this phase and repeat it. If the evaluation log shows no remaining issues, finalize the run; otherwise continue the loop from the earliest affected phase instead of finishing early.

## Sandbox contract and cross-run continuity

* Sandbox root: `.copilot-tracking/sandbox/`.
* Folder name pattern: `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`.
* Derive `{{topic}}` from the name of the primary target artifact, the skill or prompt folder name, or the file base name without suffixes, in kebab-case.
* Run-number discovery: inspect existing `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-*` folders and choose the next available `-001`, `-002`, and so on before starting a new iteration.
* Test subagents create and edit only inside the assigned sandbox folder.
* The sandbox mirrors the target folder structure.
* Reuse the prior run's sandbox so later runs build on earlier artifacts and compare results across repeated evaluations.
* Sandbox mirroring: when the test phase is sandbox constrained, mirror runtime paths such as `.copilot-tracking/research/...` and `.copilot-tracking/prompts/...` under the sandbox root. Keep real source edits outside the sandbox only when the modification phase intentionally changes target files.

## Subagent dispatch matrix

Use `runSubagent` or `task` whenever those tools are available; the named subagent should still be the primary dispatch target.

| Subagent              | Inputs                                                                                                                                                                 | Outputs                                                                                                                                |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `Prompt Tester`       | target prompt file paths, run number, sandbox folder path, purpose/requirements/expectations, prior sandbox runs when iterating                                        | sandbox folder path, execution-log path, execution status, literal execution findings, clarifying questions                            |
| `Prompt Evaluator`    | target prompt file paths, run number, sandbox folder path containing the execution log, prior evaluation logs when iterating                                           | evaluation-log path, evaluation status, severity-graded checklist, clarifying questions                                                |
| `Researcher Subagent` | research topic or question, subagent research path to create or update                                                                                                 | subagent research path, research status, key findings, suggested next research, clarifying questions                                   |
| `Prompt Updater`      | prompt files to create or modify, requirements/objectives, evaluation findings and research results, updater tracking path, sandbox/evaluation-log paths when relevant | updater tracking path, changed prompt file paths, related file paths, modification status, outstanding checklist, clarifying questions |

## Research and update artifact paths

* Primary research: `.copilot-tracking/research/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Subagent research: `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Prompt updater tracking: `.copilot-tracking/prompts/{{YYYY-MM-DD}}/{{prompt-filename}}-updates.md`

## Cleanup rules before final response

* Clean up all sandbox folders and files created for this request before the final response, unless the user asked to keep the sandbox artifacts.
* Do not return the final answer until the cleanup pass is complete.

## User conversation expectations

* Announce the current phase before starting work.
* Summarize outcomes when each phase completes and explain how the next phase will proceed.
* Share important findings and clarifying questions as work unfolds instead of operating silently.
* Limit the summary to the key outcomes and the next step.

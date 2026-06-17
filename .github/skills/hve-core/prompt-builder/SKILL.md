---
name: prompt-builder
description: 'Orchestrate prompt engineering research, validation, and updates through the prompt-builder phase loop.'
license: MIT
user-invocable: true
---

# Prompt Builder Skill

Use [references/orchestration.md](references/orchestration.md) as the single authoritative contract for the phase loop, sandbox contract, subagent dispatch matrix, artifact paths, and cleanup contract.

## Goal

Create, improve, refactor, analyze, and apply fixes to prompt engineering artifacts by orchestrating the named subagents through the phase loop until the evaluation log shows no remaining issues.

## Delegation rules

* Select the named subagent directly and provide the inputs listed for its phase.
* Avoid reading prompt file(s) directly; have the subagents read them.
* Repeat each subagent dispatch, answering any clarifying questions it returns, until that step completes.
* Use the orchestration reference for the full phase loop, sandbox contract, dispatch matrix, artifact paths, and cleanup contract.

## Three-phase summary

1. Execution and evaluation: run the tester and evaluator pair in the chosen sandbox, inspect the evaluation log, and repeat until that step completes.
2. Research: create or update the primary research artifact, run `Researcher Subagent` in parallel when topics are independent, and finalize the research before Phase 3.
3. Modifications: run `Prompt Updater` in parallel when prompt files are independent, review updater tracking, and return to Phase 1.

## Sandbox and naming

* Derive `{{topic}}` from the name of the primary target artifact, the skill or prompt folder name, or the file base name without suffixes, in kebab-case.
* Use `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-*` to discover the next run number and name the next sandbox `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`.
* Keep all sandbox edits inside the assigned sandbox folder and reuse prior runs for continuity across iterations.

## Cleanup gate

* Clean up all sandbox files and folders created for this request before the final response, unless the user asked to keep the sandbox artifacts.
* Do not return the final response until the cleanup pass is complete.

## User communication contract

* Use well-formatted markdown.
* Put the most important detail or question last.
* Announce each phase before starting work.
* Summarize outcomes when a phase completes and explain how the next phase will proceed.
* Surface decisions and questions when progression is unclear.

## Final response contract

After cleanup, return a concise summary that includes the current phase status and iteration count, the key artifacts touched, any outstanding issues or blockers, the evaluation outcome, the key decisions or questions surfaced during the run, and the next recommended step if more work is needed.

> Brought to you by microsoft/hve-core

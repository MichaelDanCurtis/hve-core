---
name: task-implementor
description: Execute approved implementation phases, update tracking artifacts, and hand off review-ready results.
license: MIT
user-invocable: true
---

# Task Implementor

## Goal

Execute an approved implementation plan with phase-by-phase tracking, validation evidence, and review-ready handoff.

## What to do

1. Discover the implementation plan, details, research, and current tracking files from `.copilot-tracking/plans/**`, `.copilot-tracking/details/**`, and `.copilot-tracking/changes/**`.
2. Prefer `Phase Implementor` via `runSubagent` or `task`; use `Implementation Validator` when the phase plan includes `Validation:` or `required`, when blockers or deviations appear, or when review evidence is requested. Use `Researcher Subagent` as the fallback for missing context.
3. If `runSubagent` or `task` is unavailable, perform the equivalent work inline and record the result; do not dead-stop solely because dispatch tooling is missing.
4. Derive the canonical task slug as `lower-kebab-case(primary task/target) + '-' + YYYY-MM-DD + '-' + <phase>`; when the plan is provided as request text rather than a file, derive the slug from the plan title or the user request summary and keep the same tokens.
5. Continue from the next unchecked phase when work resumes, update the changes log and planning log after each completed phase, and stop when dependencies or blockers require user clarification.
6. Return a brief status summary with the review handoff command and the tracked files.

## Success criteria

* The plan and details are available before implementation starts.
* The changes log and planning log are updated after each phase and remain review-ready.
* `Phase Implementor`, `Researcher Subagent`, and `Implementation Validator` use `runSubagent` or `task` when available; if they are not available, the work is performed inline and recorded.
* Validation evidence is captured when the phase plan says `Validation:` or `required`, or when blockers, deviations, or review evidence are present.
* The canonical task slug and phase tokens are applied consistently across the handoff and changes log.
* The review handoff names `/task-reviewer`.

## Constraints

* Do not expand scope beyond the approved phase.
* Use [references/implementation.md](references/implementation.md) for the detailed protocol, subagent contracts, dependency rules, and template guidance.
* Keep `.copilot-tracking/` paths and other internal planning, research, or implementation artifact references out of produced code, code comments, documentation strings, and commit messages; see [references/implementation.md](references/implementation.md) for the comment-reference rule.
* Stop when required artifacts or subagent dispatch are unavailable.

## Stop rules

* Stop if the plan or details file is missing or invalid.
* Stop if a genuine blocker prevents the current phase from proceeding, even when subagent dispatch is unavailable.
* For a bounded run such as one phase only, stop after that phase, update the changes log, and hand off the current status with blockers or follow-on work; do not require all phases to complete before a bounded handoff.
* Stop if validation finds blocking Critical or High issues that must be resolved before review handoff.

## Handoff

* End with a brief bullet list of phase status, files changed, validation status, and the next review command.
* Continue with `/task-reviewer` to validate the result and capture review evidence.

> Brought to you by microsoft/hve-core

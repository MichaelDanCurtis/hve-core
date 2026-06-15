---
description: "Compact orchestration reference for the umbrella RPI skill"
---

# RPI Orchestration Reference

Use this reference to keep the umbrella RPI skill compact while preserving the legacy-equivalent orchestration contract.

## Phase and continuation contract

1. Research: establish scope, evidence, and task difficulty.
2. Plan: create or refresh the dated plan, details, and planning log artifacts.
3. Implement: apply the approved plan and update the dated changes log.
4. Review: run validation, capture review evidence, and determine whether the work is Complete, Iterate, or Escalate.
5. Discover: always run before completion, pause, escalation, or handoff to produce Suggested Next Work and continuation routing.

Legacy-equivalent Discover protocol:

* Gather session history and `.copilot-tracking/` context, including prior Suggested Next Work selections and skips.
* Reason about direct next steps, related missing features, codebase-discovered gaps, refactoring, and newly learned patterns.
* Select 3-5 high-value actionable items when meaningful candidates exist, with brief priority and effort rationale.
* Continue automatically only when the next step is obvious; otherwise present suggestions for user selection.
* Present the result in the required high-level shape: `## Suggested Next Work`, numbered items, and a blockquote quick-reference line mapping option numbers to titles.

Input modes:

* `task=...`: primary task description or inferred task intent.
* `continue={1|1,2|all}`: resume from previously suggested work and restart from the earliest affected phase; accept a single number, multiple numbers, or `all`.
* `suggest`: run Discover directly to refresh next-work suggestions.

## Artifact path matrix

Carry one dated artifact set forward across phases:

* `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`
* `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`
* `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`
* `.copilot-tracking/reviews/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-review.md`
* `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<NNN>-validation.md`

Resume by updating the existing dated files in place instead of creating duplicate artifact sets.

## Dispatch and validator matrix

* Researcher Subagent: deeper evidence gaps, ambiguous requirements, or isolated investigation.
* Plan Validator: run after planning artifacts exist; critical and major findings are blocking until fixed and revalidated.
* Phase Implementor: run for each bounded implementation phase from the approved plan/details.
* RPI Validator: run for plan-to-change alignment and review evidence when the phase report or review requires it.
* Implementation Validator: run for implementation-quality evidence on changed files when review needs more than plan compliance.

If `runSubagent` or `task` is unavailable for a required gate, stop and report the missing dispatch capability instead of guessing.

Fallback contract:

* Retry failed subagent calls with a more specific prompt before changing approach.
* Run an additional research subagent when missing context is blocking the next gate.
* Fall back to direct tool usage only after subagent retries fail, and only for the smallest safe scope that still preserves the required validation gate.
* Stop and report limitations for required validation gates that cannot be covered by the available tool contract.

## Iteration, fallback, and final response rules

* Treat difficulty as dynamic: Simple, Medium, Medium-hard, or Challenging. Escalate to the heavier document-backed path when later findings show more complexity.
* Re-enter the earliest affected phase when validation reveals blocking issues or when Discover suggests additional work.
* Keep the response compact but evidence-first: phase status, iteration count, artifact paths, validation status, review outcome, and Suggested Next Work.
* If review outcome is Complete, include a commit message in a markdown code block following `.github/instructions/hve-core/commit-message.instructions.md`, excluding `.copilot-tracking` files.
* If review outcome is Iterate or Escalate, continue from the earliest affected phase and still complete Discover before handing off.
* Do not end a run without completing Discover, even when the next action is obvious.

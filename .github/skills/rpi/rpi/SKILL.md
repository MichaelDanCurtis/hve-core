---
name: rpi
description: Umbrella RPI playbook that sequences Research, Plan, Implement, Review, and Discover for one-shot task execution with legacy-equivalent quality gates.
license: MIT
user-invocable: true
---

# RPI

Use [references/orchestration.md](references/orchestration.md) for the deeper legacy-equivalent orchestration contract, artifact-path matrix, and validator dispatch rules.

## Goal

Run the full RPI flow as the primary umbrella entry point for one-shot task execution, while preserving the existing phase-skill delegation model and the legacy continuation contract.

## Flow

1. Research: establish task scope, evidence, and difficulty.
2. Plan: create or refresh the dated plan, details, and planning log artifacts.
3. Implement: execute the approved plan and update the changes log.
4. Review: validate the result and record the review outcome.
5. Discover: required before completion, pause, escalation, or handoff to produce Suggested Next Work.

## Inputs

* `task=...`: primary task description or inferred intent.
* `continue={1|1,2|all}`: resume from prior Discover suggestions and restart from the earliest affected phase; accept a single number, multiple numbers, or `all`.
* `suggest`: run Discover directly to refresh next-work suggestions.

## Success criteria

* The same dated `.copilot-tracking/` artifact set is carried forward across phases and resumed in place.
* Research, planning, implementation, review, and Discover gates run in order and stop on blocking findings.
* The umbrella skill delegates detailed phase work to `/task-researcher`, `/task-planner`, `/task-implementor`, and `/task-reviewer`.
* The final response includes phase status, iteration count, artifact paths, validation status, review outcome, and Suggested Next Work.
* When review outcome is Complete, include a commit message in a markdown code block following `.github/instructions/hve-core/commit-message.instructions.md`, excluding `.copilot-tracking` files.
* Still run Discover before any user-facing finish, pause, escalation, or handoff.

## Constraints

* Keep the umbrella skill as the sequencing and quality-gate layer, not as a full duplicate of every granular phase playbook.
* Use the existing RPI subagents and validators when they are available: Researcher Subagent, Plan Validator, Phase Implementor, RPI Validator, and Implementation Validator.
* If a required dispatch or validation gate is unavailable, stop and report that limitation instead of guessing.
* Retry failed subagent calls with a more specific prompt, and run an additional research subagent when missing context is blocking.
* Fall back to direct tool usage only after subagent retries fail, and only for the smallest safe scope needed to preserve the current quality gate.
* Fallback may cover supporting investigation or bounded execution, but unavailable required validation gates remain stop-and-report blockers.

## Quality gates

* Treat task difficulty as dynamic: Simple, Medium, Medium-hard, or Challenging, and escalate to the document-backed path when findings increase the scope or risk.
* Critical and major validation findings block advancement until fixed and revalidated.
* Minor findings may remain only when they are explicitly documented as non-blocking.

## Stop rules

* Stop if research evidence is missing before planning begins.
* Stop if Plan Validator reports blocking findings.
* Stop if implementation is blocked by a dependency or validation failure.
* Stop if review validation fails or the evidence trail is incomplete.
* Stop if the dated artifact set cannot be discovered or resumed for the current task.

## Handoff

Use the granular phase skills for the detailed execution path: `/task-researcher`, `/task-planner`, `/task-implementor`, and `/task-reviewer`.

## Final response contract

Return a compact summary that includes:

* phase status and iteration count,
* the dated artifact paths used or updated,
* validation status and any blocking findings,
* the current review outcome, and
* Suggested Next Work from Discover.

> Brought to you by microsoft/hve-core

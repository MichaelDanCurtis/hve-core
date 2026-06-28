<!-- markdownlint-disable MD013 -->
# Interview progress stepper design

## Purpose

The guided interview view renders a conversational Q&A flow plus a growing draft. That fits the doc-builders, but a large group of interview-domain agents run a structured, multi-step program whose progress the view does not show: the phase-gated planners (ADR with Frame, Decide, Govern; the six-phase SSSC planner; the Security, RAI, and Accessibility planners) and the coaches (the Design Thinking coach and learning tutor, the experiment designer, the agile coach, the UX designer). A learner in a nine-method design-thinking curriculum, or a user mid-way through a six-phase supply-chain assessment, sees the current question and the draft but no sense of where they are in the program or what is ahead.

The interview progress stepper closes that. A phased agent declares its program as a named list of steps with a current position, and the interview view renders a horizontal stepper above the conversation. It serves every phased interview agent with one surface.

## State

A single new field on `SessionState`:

`interviewSteps: { label?: string; names: string[]; current: number } | null`

* `names`: the ordered step names (for example `["Frame", "Decide", "Govern"]`, or the nine design-thinking methods).
* `current`: the zero-based index of the active step.
* `label`: an optional program name shown as a lead-in (for example `Design Thinking` or `SSSC`).
* `null` when no program has been declared.

## Beat and tool

One new beat and one new MCP tool (the tool count goes from 32 to 33).

`set_steps(steps, current, label?)` emits a `steps.set` beat that sets `interviewSteps`. `steps` is a non-empty string array; `current` is clamped into `[0, steps.length - 1]` so an out-of-range index never produces a stepper with no active step. To advance, the agent re-calls `set_steps` with a higher `current`; an adaptive coach that does not know the whole path upfront re-declares `names` (adding or reordering steps) on each call, since every call replaces the field wholesale.

`interview.start` resets `interviewSteps` to `null`, so a stale program from a previous interview never leaks into a new one (the same hygiene `interview.start` already applies to other interview state).

## View-model

`toViewModel` projects `interviewSteps` with each step's status derived from `current`, exactly as the RPI rail stepper derives its step statuses today:

`interviewSteps: { label?: string; steps: { name: string; status: "done" | "active" | "pending" }[] } | null`

A step at an index less than `current` is `done`, the step at `current` is `active`, and a step after `current` is `pending`. The projection is pure: it reads `interviewSteps` and maps the names to status objects, leaving state untouched. When `interviewSteps` is `null` the projection is `null`.

## Client

`renderInterview` renders a horizontal stepper into a new `#iv-steps` strip placed between the docType header and the decision-flow slot, shown only when `v.interviewSteps` is non-null (the strip is hidden and emptied when it is null, so a doc-builder with no program sees no stepper). Each step is a small pill: a glyph (a check for `done`, an accent dot for `active`, a muted dot for `pending`) followed by the step name, with the optional `label` rendered as a muted lead-in before the pills. The active step is visually emphasized. Every interpolated value (the label, each step name, the status class) goes through the existing `esc()` helper. The strip wraps on a narrow pane rather than overflowing.

## Agent contract

`agents/cockpit-instructions.md` gains a line in the guided-interview section: a phased interview agent (a phase-gated planner or a coach running a curriculum or method sequence) should call `set_steps(steps, current, label?)` when it begins the program and again as it advances, so the user sees the whole roadmap and the current position above the conversation.

## Testing

* state: `steps.set` sets `interviewSteps`; `current` is clamped (a too-large index lands on the last step, a negative index on the first); `interview.start` resets it to `null`.
* view-model: `toViewModel` derives done/active/pending from `current` (a three-step program at `current` 1 gives done/active/pending); `null` when no program.
* tool: a round trip drives `set_steps` over the in-memory transport and asserts `bridge.state.interviewSteps`; the tool count goes 32 to 33.
* client: the interview view shows `#iv-steps` with one pill per step and the right status class on each, the active pill emphasized, the strip hidden when `interviewSteps` is null, and every field escaped.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `interviewSteps` state field and its `steps.set` beat, the clamping, the `interview.start` reset, the `set_steps` tool, the view-model projection, the `#iv-steps` stepper in `renderInterview`, the agent-contract line, and the tests above.

Deferred / non-goals:

* A clickable stepper that jumps the program to a step: navigation is the agent's job (the cockpit captures intent, the agent advances), and the existing decision-flow revisit already covers going back to a past question.
* Per-step sub-progress (for example a comprehension-check score within a step): the step name can carry a short suffix, but a richer per-step state is a separate decision.
* Reusing the stepper in non-interview views: the phased programs are all interview-domain; review and backlog have their own progress surfaces (the reviewer pipeline strip, the kanban columns), so the stepper stays scoped to the interview view.
* Inferring steps from anything: the agent declares them explicitly.

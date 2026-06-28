<!-- markdownlint-disable MD013 -->
# Review-panel improvements design

## Purpose

The findings panel is the cockpit surface for all 13 review-category agents (code review, PR review, security, accessibility, RAI). A live walkthrough of the panel found it solid for the single-shot severity-graded reviewers, but three gaps for the rest:

1. The orchestrator reviewers (Code Review Full, Security, Accessibility, RAI) run a multi-step subagent pipeline (profile the repo, assess N skills, adversarially verify findings, generate a report). The panel shows only the end findings, so during a long scan the user sees an empty panel with no sense of progress.
2. Each finding shows its `file:line` as inert text, though the surface was meant to offer file links.
3. PR Walkthrough produces a narrative orientation (design forks, implicit bets, architectural shape), not severity-graded findings, so the findings panel is the wrong surface for it.

This design closes all three with no new MCP tools and no state or view-model change for the progress feature.

## 1. Orchestrator pipeline progress (reuse subagents)

The cockpit already has a subagent primitive: `subagent_start(name, role)` and `subagent_stop(name, result)` set `state.subagents`, which `toViewModel` already projects into `v.subagents` for every domain (the RPI view renders it as the "Live subagents" cards). The findings view simply does not render it yet.

The change: `renderFindings(v)` renders a compact "live reviewers" strip from `v.subagents`, in a new `#rev-pipeline` container inside `#findings-view`, positioned above the findings list. The strip is shown only when `v.subagents.length > 0` and is hidden (and emptied) otherwise, so a single-shot reviewer that never starts a subagent sees no empty strip. Each row reuses the existing subagent visual (the avatar initials, name, role, and status tag) at a compact size.

No new tool, beat, or state field. The orchestrator reviewers narrate their pipeline through the subagent tools they already own: as each runs Codebase Profiler, then per-skill Skill Assessors, then Finding Deep Verifier, then Report Generator, those appear as live rows above the accumulating findings. When the pipeline finishes and the agent stops its subagents, the strip empties and only the findings remain.

The agent contract (`agents/cockpit-instructions.md`) gains one line under the reviews section: an orchestrator reviewer should call `subagent_start`/`subagent_stop` for its pipeline so the findings panel shows progress during a long scan.

## 2. File location becomes a copy affordance

Inside the sandboxed cockpit iframe there is no bridge to the host editor, so a true "open in editor" link is not available. The honest, useful action is copy-to-clipboard.

`.finding-loc` becomes a real `<button class="finding-loc" data-loc="path:line">` (so it is keyboard-focusable and screen-reader-announced as a button), styled with a pointer cursor and a `title` of "Copy location". A delegated click handler in the existing document click listener reads `data-loc`, writes it to the clipboard via `navigator.clipboard.writeText` (guarded in a try/catch so a clipboard-permission failure is silent), and briefly swaps the button label to "copied" before restoring it. The `path:line` value and the visible label both go through `esc()`. The button carries no decision/steer semantics, so it does not collide with the existing click branches.

## 3. PR Walkthrough uses show_screen, not findings

PR Walkthrough (#18) is narrative, not a list of severity-graded findings. The fix is a narration-contract clarification, not code: `agents/cockpit-instructions.md` notes that a narrative reviewer (for example PR Walkthrough) should render its orientation with `show_screen` (rendered markdown in the sandboxed pane), reserving `review_start` + `add_finding` and the findings panel for severity-graded findings. This keeps each surface matched to the shape of its content.

## Architecture and isolation

All three changes are confined to the presentation layer plus one doc:

* `public/client.js`: `renderFindings` renders the `#rev-pipeline` strip; the document click listener gains a `finding-loc` copy branch. No other render path changes.
* `public/index.html`: a `#rev-pipeline` container in `#findings-view` and its CSS; `.finding-loc` restyled as a button.
* `agents/cockpit-instructions.md`: the orchestrator-progress line and the narrative-reviewer (show_screen) line.

No MCP tools are added (count stays 30). No state, beat, reducer, or view-model change: `v.subagents` is already projected, so the progress strip is pure rendering. This keeps the change small, independently testable, and free of cross-layer coupling.

## Testing

Happy-dom client tests (mirroring the existing `findings-client.test.ts` boot harness):

* The findings view renders one `#rev-pipeline` row per `v.subagents` entry when subagents are present, and the strip is hidden/empty when `v.subagents` is empty.
* `.finding-loc` is a `<button>` carrying `data-loc="path:line"` for a finding that has a file and line, and is absent when the finding has no file.
* The copy click branch is wired (clicking a `finding-loc` button invokes the clipboard write); since happy-dom may not implement the clipboard, the test stubs `navigator.clipboard.writeText` and asserts it was called with `path:line`.

`tsc --noEmit`, the full vitest suite, and markdown lint (from the repo root) must be green.

## Scope

In scope: the three changes above and their tests.

Deferred / non-goals:

* A real "open in editor" jump from a finding (needs a host editor bridge the sandboxed pane does not have).
* Showing the orchestrator's subagent pipeline and the findings in two simultaneous panes (the cockpit shows one domain view at a time; the strip-above-findings composition is the chosen single-view answer).
* Any change to how findings themselves are modeled, grouped, or severity-ordered (that surface already works).
* Auto-detecting that a reviewer is narrative vs severity-graded (the agent picks the right surface per the contract; the cockpit does not infer it).

<!-- markdownlint-disable MD013 -->
# HVE Cockpit reviewers findings panel design

## Purpose

The second loop view: a read-only findings panel for the reviewers and auditors archetype (code review, PR review, security, accessibility). It proves the cockpit is general, a second composition beside RPI, and it lands the new list and findings primitive named in [navigator-design.md](navigator-design.md) and the [representation map](representation-map.md). It is reached from the Navigator's "Review code" tile and renders inside the existing loop-view shell, with the breadcrumb back to the Navigator.

## The composition-aware loop view

Today the cockpit's loop view is the RPI build loop. This change makes the loop view render different compositions by domain: `session.begin` starts the RPI build loop (domain `rpi`), and a new `review.start` starts the review loop (domain `review`). The client renders the RPI stepper for `rpi` and the findings panel for `review`, branching on a `domain` field carried on session state and the view-model. RPI stays the first composition; this is the second. The Navigator, the home and loop routing, and the breadcrumb are unchanged.

## The findings primitive, read-only v1

A reviewer agent narrates two new beats:

* `review.start { target }`: what is under review (a branch, a pull request, a path). Sets the domain to `review`, records the target, and clears any prior findings.
* `finding.add { severity, title, file?, line?, detail? }`: appends one finding.

Severity is one of `critical`, `high`, `medium`, `low`, `info`. A reviewer maps its own labels onto these (for example an HVE reviewer's Important to `high`, Minor to `low`).

The panel renders the findings grouped by severity, critical first, each row showing a severity tag, the title, and a `file:line` label, with the detail revealed on expand. A header shows the review target and the counts by severity. There are no outbound actions in v1: the panel is read-only. Accept, dismiss, and jump-to-file are a deferred follow-up.

## State and protocol

* `SessionState` gains `domain: "rpi" | "review" | null` (default null), `reviewTarget: string | null`, and `findings: Finding[]` where `Finding` is `{ severity, title, file?, line?, detail? }`.
* `applyBeat` handles `review.start` (set domain `review`, set `reviewTarget`, reset `findings` to empty) and `finding.add` (append to `findings`). `session.begin` also sets `domain: "rpi"` so the build loop is the RPI composition.
* The view-model projects `domain`, `reviewTarget`, the severity counts, and the findings grouped and ordered by severity, so the client can route the composition and paint the panel without its own logic.
* Two MCP tools, `review_start` and `add_finding`, let a reviewer agent narrate. They follow the existing tool registration pattern in `src/mcp.ts` and `src/handlers.ts`.

## Loop-view routing

The client's loop render branches on `v.domain`: `review` paints the findings panel (a new `#findings` section inside the loop markup), anything else paints the existing RPI loop. The findings panel reuses the loop-view chrome (the breadcrumb back to the Navigator, the status). Every finding field is escaped with the client's existing `esc` helper, exactly like the rest of the painter.

## Scope

In scope for v1:

* The `review.start` and `finding.add` beats, the `domain` and `findings` state, the grouped findings view-model, the domain-routed loop view, and the read-only panel (severity groups, `file:line` label, expandable detail, the target and counts header).
* The `review_start` and `add_finding` MCP tools so a reviewer agent narrates.
* The Navigator's "Review code" tile already launches the review intent (the agent runs the review and narrates these beats); no Navigator change is needed.

Deferred to later plans:

* The actionable version: accept and dismiss per finding and jump-to-file, sending intent back to the agent.
* Pagination or virtualization for very large finding lists.
* Generating findings from a reviewer's structured output format rather than narrated beats.

## Non-goals

* No outbound actions in v1 (read-only).
* No change to the RPI composition, the Navigator, or the secure defaults (token gate, iframe sandbox).
* The cockpit renders the findings the agent narrates; it does not run the review itself.

## Security

Findings are agent-narrated text. Every field (severity, title, file, line, detail) is escaped through the client's existing `esc` helper before it reaches the DOM, the same boundary the rest of the painter uses. The `file:line` is a plain label in v1, not a live link, so there is no host navigation surface to secure yet.

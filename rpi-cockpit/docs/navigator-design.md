<!-- markdownlint-disable MD013 -->
# HVE Cockpit Navigator design

## Purpose

The Navigator is the front door of the HVE Cockpit, the graphical way into HVE Core. It exists to answer the question a newcomer cannot answer today: what can this do, where am I, and what comes next. It answers that graphically, beside the text interface rather than in place of it. The Navigator is a pop-up overlay inside the cockpit, not a separate home screen. The cockpit's standing surface is the active loop view, and the Navigator opens over it on demand.

This spec covers the Navigator (the pop-up picker), the loop views it opens into, the transitions between them, and the host-neutral rendering model that lets all of it run in Claude Code, VS Code (Copilot), and Codex. It builds on [ROADMAP.md](../ROADMAP.md) and the archetype-to-primitive mapping in [docs/representation-map.md](representation-map.md). RPI is the first loop view; the Navigator is the picker that opens over it.

## Principles

These constraints are load-bearing and shape every decision below.

| Principle | What it means |
|---|---|
| Graphical, not a text box | The text interface already exists and is excellent. The Navigator earns its place by being the picture: clickable, glanceable elements (capability cards, status, a domain map), never a prompt field standing in for the chat the user already has. |
| Captures intent, never launches | A click expresses intent. The host agent performs the launch over the directive and talk-back channel the cockpit already has. The cockpit reflects what the agent does; it never orchestrates agents itself. |
| Discoverability first | The reason the Navigator exists is introduction. Orient and launch come after. |
| Host-neutral core | The Navigator and the loop views are one web cockpit. The host supplies the pane. Inline rendering in the chat is a per-host enhancement layered on top, never a dependency. |

## The surfaces

The cockpit is one shell. Its standing surface is the active loop view; the Navigator is a pop-up that opens over it.

| Surface | What it is | Role |
|---|---|---|
| Loop views | One graphical composition per workflow archetype, filling the pane | Run whatever loop you are in: RPI, a review, a document interview, a data-science build, a backlog board |
| The Navigator pop-up | A modal overlay layered over the loop view | Introduce what HVE Core can do and route your intent into a workflow |
| In-chat workflow card | A native choice card in the chat (the `present_workflows` tool) | The same picker offered inline, so you can choose a workflow without leaving the text interface |

The Navigator pop-up and the in-chat card are two surfaces for the same act, picking a workflow. The pop-up opens from the help button, on first run, or when the agent runs `open_navigator` (a `/Nav` command); the in-chat card is offered by the agent in the chat. Either one launches the workflow; the cockpit then shows the running loop and the pop-up closes. Transitions run both ways: you start a loop by picking a workflow, or the agent hands off into the next loop (a document builder finishing into a backlog manager) and the cockpit surfaces that handoff instead of leaving it silent.

## The Navigator pop-up

The Navigator is a modal overlay inside the cockpit. It merges the first-run welcome and the workflow picker into one surface, so the introduction and the way to act on it live together. It opens in three ways: automatically on first run (per project), from the persistent help button in the pane chrome, and when the agent calls `open_navigator` in response to a `/Nav` command. It is built from these parts:

1. Intro line: a brief, plain-language statement of what HVE Core can do and how to reopen the pop-up. This is the welcome, folded into the picker.
2. Workflow grid: a clean grid of workflow tiles, the heart of the pop-up.
3. Dismiss: a "Got it" button that closes the pop-up. The first-run auto-open is remembered per project, so it does not return uninvited, and the help button reopens it any time.

The cockpit's standing surface behind the pop-up is the active loop view, or, before any loop runs, a minimal home with an orient line. The pop-up never replaces the loop; it floats over it and closes on launch. The help button is the persistent way back in, and it will grow into a fuller help function in a later version.

### Workflow tiles

Six tiles, mapped to the workflow archetypes in the representation map and relabeled into goal language:

| Tile | Archetype it fronts |
|---|---|
| Build code | RPI build loop |
| Review code | Reviewers and auditors |
| Plan and backlog | Backlog orchestration |
| Write docs and specs | Guided document builders |
| Analyze data | Generators (data science) |
| Coach and learn | Coaches and tutors |

The seventh archetype, meta and utility (memory, prompt-builder, issue-triage, and similar), is plumbing rather than a front-door workflow, so it is not a tile. Those agents are reachable as a drill-in.

Each tile is calm at rest: an icon, the name, and a short resting hint of two or three words. Hovering a tile reveals a plain-language description of what that workflow does. That hover description is the entire ongoing discoverability mechanism, so the grid stays uncluttered. Clicking a tile expresses intent, which the host agent turns into a launch, and closes the pop-up. Individual agents live inside their workflow as a drill-in, not in the picker.

## The loop view

Picking a workflow (from the pop-up or the in-chat card) opens that workflow's GUI in the pane. The RPI loop view is the first one, and it is the cockpit already built.

| Part | Content |
|---|---|
| Chrome | A breadcrumb back to the Navigator home (for example `HVE Cockpit` to `Build code`), a persistent help button that reopens the Navigator pop-up, and a status indicator. |
| Body | The workflow's composition of primitives. For RPI: the phase stepper (research, plan, implement, review, discover), live subagents, the validation gate, decision cards, and the steer panel. |

The other five tiles get their own loop views over time, in the proof order from the representation map (reviewers, then the interview, then the backlog board). Until a tile has a rich loop view, it still launches and runs in text, with the pop-up as its front door.

## The rendering ladder

The cockpit is one web app, but a given beat can be shown at different richness depending on what the host supports. The cockpit picks the highest rung the host offers and falls back gracefully.

| Rung | What it renders | Mechanism | Status |
|---|---|---|---|
| 1. Inline choice | The decision and question primitives, and the workflow picker: a bounded set of options plus a freeform answer | An MCP elicitation, rendered as each host's native choice UI | Confirmed in VS Code (the native choice card) and Claude Code (AskUserQuestion) |
| 2. Rich pane | The Navigator pop-up, the loop views, screens | The web cockpit in a host pane | Confirmed in Claude Code (Preview pane) and VS Code (Simple Browser at `127.0.0.1:4399`) |
| 3. Inline rich widget | The Navigator shown live inside the chat transcript | Free on Claude Code; VS Code via the extension's `chatOutputRenderers` iframe; editor-agnostic once MCP Apps matures | Confirmed on Claude Code; emerging in VS Code; a nice-to-have, not load-bearing |

The decision and question primitive is realized as an MCP elicitation. Its schema is limited to primitive and enum types (a bounded choice plus a freeform field), which is exactly right for a decision and is also what keeps rung one cleanly separate from the rich canvas of rung two. The same elicitation mechanism backs the in-chat workflow card. The Navigator pop-up and loop views are never elicitations; they are pane content.

### Host matrix

| Host | Rung 1 (inline choice) | Rung 2 (rich pane) | Rung 3 (inline rich widget) |
|---|---|---|---|
| Claude Code | AskUserQuestion (native) | Preview pane (confirmed) | Free (the inline widget) |
| VS Code (Copilot) | Elicitation choice card (confirmed) | Webview or Simple Browser (confirmed) | Extension `chatOutputRenderers` iframe, or MCP Apps later |
| Codex | Inline prompt; degrades toward text for many options | Browser pop-out | MCP Apps later |

## Click to launch: the control flow

1. The user picks a workflow, from the Navigator pop-up or the in-chat card (or answers an elicitation).
2. The cockpit emits the intent over the existing talk-back channel (a directive, or the elicitation result), and the pop-up closes.
3. The host agent picks up the intent and runs the corresponding HVE Core workflow.
4. The agent narrates beats, which drive the loop view.
5. The cockpit reflects the running loop. It never launches the workflow itself.

The active loop or domain is held as session state so the cockpit can orient on it and the breadcrumb knows what is running. A navigator-open flag is held as session state too, so a `/Nav` command can pop the Navigator over the running loop.

## Protocol additions for v1

The Navigator needs a small amount on top of the existing RPI-specific protocol:

1. Generalize the beats from the RPI phase enum toward the archetype-agnostic primitives in the representation map (timeline, decision, list, question, screen, app frame, context), with RPI as the first composition.
2. Add a capability catalog: the workflows, their descriptions, and the intent each one emits when clicked. For v1 this is a small static configuration covering the six workflows. A later phase can generate it from HVE Core's agent and prompt manifest.
3. Add an active loop or domain to session state, for orient and for transitions.
4. Realize the decision and question primitive as an MCP elicitation.
5. Add a navigator-open flag to session state and an `open_navigator` tool, so a `/Nav` command can pop the Navigator over the running loop. The pop-up also opens client-side from the help button and on first run.
6. Offer the picker inline through a `present_workflows` tool that renders a native choice card in the chat, the second launch surface.

## Scope

In scope for v1:

* The Navigator pop-up: the merged first-run welcome and the workflow grid with hover descriptions, opened from the help button, on first run, and via `open_navigator` (a `/Nav` command).
* The in-chat workflow card (`present_workflows`) as a second launch surface.
* Pane chrome with a persistent help button, and a minimal home with an orient line behind the pop-up.
* Click to express intent, routed to the host agent for launch, closing the pop-up.
* The decision and question primitive as an MCP elicitation, rendered natively per host.
* The RPI loop view as the one wired loop, reached through the picker, with a breadcrumb back.
* Host-neutral pane rendering in Claude Code and VS Code.
* The capability catalog (static, six workflows), the active loop or domain state, and the navigator-open state.

Deferred to later phases:

* The other loop views, in proof order: reviewers and auditors, then the document interview, then the backlog board.
* The inline rich widget tier (rung three) in VS Code and via MCP Apps.
* The app frame primitive (a trusted localhost iframe of the app under development beside the cockpit).
* Generating the capability catalog from HVE Core's manifest.
* Growing the help button into a fuller help function.

## Non-goals

* The Navigator does not launch or orchestrate agents. It captures intent only.
* The Navigator does not replace the text interface. It is a graphical surface, not a second prompt box.
* No new agent capabilities. The agents ship in HVE Core; the cockpit renders and steers them.

## To confirm in the VS Code spike

Two of the three rungs are already validated in VS Code (the elicitation choice card and the cockpit in the Simple Browser). The spike confirms the rest:

* The `chatOutputRenderers` iframe path for the rung-three inline widget, and its current stability.
* The exact native rendering of an elicitation with an enum plus a freeform field across host versions.

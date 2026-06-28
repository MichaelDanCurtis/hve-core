<!-- markdownlint-disable MD013 -->
# HVE Cockpit Roadmap

## Mission

Agentic frameworks are powerful and nearly impossible to read. HVE Core ships roughly 65 agents, 71 prompts, 70 instructions, and 13 skill packs, and a new user's honest first reaction is "what is this supposed to do, and where do I start?" The HVE Cockpit answers that question, graphically.

The Cockpit is the graphical home for HVE Core. It makes the framework legible (you can see what it can do and what it is doing now), steerable (you can nudge it), and inviting (it reads like a product, not a manual). It does not replace the text interface you already use. It adds a graphical layer beside it, because the things that matter most for getting started (what exists, where you are, what comes next) are far clearer as a picture than as prose.

The single near-term goal is a genuinely high-quality interface over the agents HVE Core already has, not new agent capabilities. The agent is the engine; the Cockpit is the cockpit. RPI was the first loop we proved; the product is the cockpit around all of them.

## The shape: a shell, a Navigator, and loop views

The Cockpit is one shell that hosts two kinds of surface.

| Surface | What it is | Role |
|---|---|---|
| The Navigator | The home and primary surface | Introduces what HVE Core can do, shows the loop or domain you are in, and routes your intent |
| Loop views | One graphical composition per workflow archetype | Runs whatever loop you are in: RPI, a review, a document interview, a data-science build, a backlog board |

You begin in the Navigator, enter a loop view to do the work, and return to the Navigator between tasks. Transitions between loops are first-class and run in both directions: you start one ("I need to do some data science"), or the agent hands off into the next (a document builder finishing into a backlog manager). The Cockpit makes that handoff visible instead of silent.

## The Navigator (the heart of the product)

The Navigator is the answer to "I installed a large agentic framework and I cannot tell what it does." It has three jobs, in priority order.

| Job | What it does |
|---|---|
| Introduce | A graphical, browsable map of what HVE Core can do: its agents, loops, and domains, each clickable and explained. This is the onboarding and discovery surface, and it is the reason the Navigator exists. |
| Orient | Shows where you are right now: the active loop or domain, what is running, and what just happened. |
| Launch | Lets you click an agent, a loop, or a domain to express intent. The Cockpit captures the intent; the host agent performs the launch. |

One constraint is firm: the Navigator is graphical, never a blank box you type into. The text interface already exists and is excellent, so duplicating it as a prompt field adds nothing. The Cockpit earns its place by being the picture, so the Navigator is built from clickable, glanceable visual elements (capability cards, a domain map, live status), not a search bar standing in for the chat the user already has.

The launch boundary keeps the Cockpit honest to its charter: the Navigator surfaces capabilities and captures intent, and the host agent (Claude Code, Copilot, Codex) performs the actual launch over the directive and talk-back channel the Cockpit already has. The Cockpit never orchestrates agents itself.

## The bet: one protocol, one web cockpit, many host panes

The durable product is not any single renderer. It is the beat protocol and view-model: the agent emits small structured beats (step changes, subagent activity, validations, decisions, screens, and the active loop or domain); a pure reducer folds them into session state; and the view-model produces exactly what a surface needs to paint. The Navigator and the loop views are both renderings of that one view-model.

MCP is the data and control wire (beats in, intent and decisions out); it does not draw the UI. So the question that drives this project is not "where does MCP run" but "what can each host render?"

| Surface | Type | Primary renderer | Server? |
|---|---|---|---|
| VS Code (Copilot) | GUI editor | Web cockpit in a webview pane | host-managed |
| Claude Code | Desktop / CLI | Web cockpit in the Preview pane | host-managed |
| Codex / terminal | CLI | Inline snapshot, or browser pop-out | local, opt-in |

The host owns the server. A spike confirmed the web cockpit renders fully and interactively in both a VS Code webview and the Claude Code Preview pane, with the host launching and managing the local server (Claude Preview assigns the port through the `PORT` environment variable, exactly as a VS Code extension would). So this is not infrastructure you run, it is infrastructure the host runs. One web cockpit, rendered in many host panes; an inline terminal snapshot and a standalone browser pop-out remain fallbacks where no pane exists.

## Representation

The Cockpit has to represent the whole HVE Core surface, not one loop. That surface collapses into a handful of workflow archetypes that share a small set of archetype-agnostic primitives (timeline, decision, list, question, screen, app frame, context), worked out in [docs/representation-map.md](docs/representation-map.md). Each loop view is one composition of those primitives, with RPI as the first.

The Navigator adds one layer above that map: a catalog of what HVE Core can do (for the Introduce job) and a current loop or domain indicator (for Orient and for transitions). Generalizing the protocol toward the primitives, and adding that catalog and domain state, is the v1 protocol work below. The representation map will be extended to cover them.

## Current state (v0)

Shipped on the design branch:

| Piece | What it provides |
|---|---|
| Protocol core | Beat schemas (`events.ts`), a pure reducer (`state.ts`), and the view-model (`render.ts`); MCP tools for every beat, including `present_options`, `offer_approaches`, `check_directives`, and `show_screen`. |
| Browser-cockpit renderer | The standalone web dashboard: a structured RPI loop view, blocking decisions, a steer panel, an agent-authored sandboxed screen pane; hardened with per-session token auth, loopback-only bind, and a finite decision timeout. |
| Host-pane rendering | Embed mode (the host-assigned `PORT` plus an opt-in loopback trust that drops the token for a trusted pane) and a committed preview launcher and launch config, so the web cockpit loads in a VS Code webview or the Claude Code Preview pane with no manual steps. |
| Host-agnostic talk-back | Directives and decisions are also written to JSONL files, so steering works without a live MCP connection. |
| Cross-host launch | An idempotent `init` command writes the correct MCP config and narration into Claude Code, Codex, and VS Code. |
| Agent instrumentation | The HVE Core RPI agents narrate to the Cockpit when its tools are present. |

In short, we have the protocol, one loop view (RPI), and proof that the web cockpit renders live in a host pane. The product ahead is the Navigator and the other loop views.

## Horizons

### Now (v1): the Navigator's first cut, on generalized primitives

* Generalize the beat protocol from the RPI phase enum to the archetype-agnostic primitives in [docs/representation-map.md](docs/representation-map.md), and add the active loop or domain as session state, so any HVE Core workflow can drive a loop view and the Navigator can show where you are. RPI stays the first composition.
* Build the first Navigator: a graphical home that introduces what HVE Core can do (a clickable capability map of agents, loops, and domains), shows the active loop or domain, and routes a click as intent to the host agent. Graphical, not a text box.
* The embed-mode substrate is already in place, so the Cockpit loads in a host pane with no manual steps.

This horizon is done when a new user can open the Cockpit, understand at a glance what HVE Core can do, click to start a loop, and watch RPI run, all without reading documentation.

### Next: prove many agents, one cockpit, and make it great

* Build the second and third loop views in the proof order from the representation map: reviewers and auditors (a findings panel), then guided document builders (an interview), then backlog orchestration (a kanban). Each reuses the primitives and slots into the shell, demonstrating that the cockpit is general, not RPI-only.
* Invest in UX quality across surfaces: a polished Fluent or Liquid-Glass language, motion that makes state changes feel alive, a calm glanceable presence, accessibility to WCAG 2.2, and responsive layout from a wide panel to a narrow inline widget.

### Later: the parking lot

New capabilities live here, explicitly deferred until the UX is excellent. Two are starred for early promotion because they are too good to wait on:

* Live team-orchestration view (starred): an orchestrator and its subagents as a board you watch and intervene in, with the ability to pause, swap, or spawn an agent mid-run.
* 3D codebase map (starred): a spatial map of the codebase the agent visibly moves through as it researches and edits.

The rest, parked: a session replay or time-machine scrubber, voice steering, drag-to-focus (point the agent at a file or line), rewind-and-branch from a past checkpoint, an AG-UI or A2A protocol layer so any agent framework can drive the Cockpit, and remote or mobile viewing.

## Non-goals

* No new agent capabilities during the v1 and Next phases. The agent ships in HVE Core; the Cockpit only renders and steers it.
* The Cockpit captures intent but never launches or orchestrates agents itself. The host agent performs the launch.
* The Cockpit complements the text interface, it never replaces it. The Navigator is a graphical surface, not a second prompt box.
* No hosted or cloud service. The Cockpit is local and ephemeral, and it dies with the session.
* The host owns auth and identity. The Cockpit never becomes an identity provider or a long-lived backend.
* Not a model host. It works with whatever model the host already runs.

## Relationship to HVE Core

The Cockpit is a separate companion project that consumes HVE Core's agents, while HVE Core stays deliberately artifacts-only. The Cockpit is a host-managed runtime (a local web server the host launches and renders in its pane), which is exactly the runtime HVE Core's charter excludes, so it stays here. Only the thinnest fallback, an inline terminal snapshot the agent paints through a rendering tool, is artifact-shaped enough to consider upstream later.

## Naming

The product is the HVE Cockpit. The working directory is still `rpi-cockpit/` and the package rename is a deferred mechanical task, tracked separately so it does not block the design work.

## How to influence this roadmap

This is an early, opinionated roadmap and will move with what we learn building the Navigator and the loop views. The ordering above is a bet, not a contract: the "Later" items (especially the two starred ones) can jump forward the moment the UX foundation is solid enough to carry them.

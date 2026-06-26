<!-- markdownlint-disable MD013 -->
# RPI Cockpit Roadmap

## Mission

The RPI Cockpit is a host-agnostic visual companion for agentic coding: a beautiful, inviting window into the agent you already have. It makes an agent's work legible (you can see what it is doing), steerable (you can nudge it), and collaborative (it asks the right question at the right moment), and it renders wherever the agent already lives, whether inline in Claude Code, in a VS Code panel, or as a full browser dashboard.

The single near-term goal is a genuinely high-quality user interface for the experience we already have, not new agent capabilities. The agent is the engine; the Cockpit is the cockpit.

## The bet: one protocol, many renderers (server-less first)

The durable product is not the web server. It is the beat protocol and view-model: the agent emits small structured "beats" (`phase.enter`, `subagent.start`, `validate`, `present_options`, `screen.show`, and so on); a pure reducer folds them into session state; and `toViewModel(state)` produces exactly what a UI needs to paint. Rendering is a pluggable concern.

MCP is the data and control wire (beats in, decisions out); it does not draw the UI. So the question that drives this project is not "where does MCP run" but "what can each host render?" That maps cleanly to renderers:

| Surface             | Type       | Primary renderer                       | Server?       |
|---------------------|------------|----------------------------------------|---------------|
| VS Code (Copilot)   | GUI editor | Webview panel                          | none          |
| Claude Code         | CLI / TUI  | Rich inline widgets (SVG/HTML)         | none          |
| Codex / Copilot CLI | CLI        | Browser cockpit pop-out (escape hatch) | local, opt-in |

Server-less first means rendering natively where the host is capable (VS Code webview, Claude Code inline). The standalone browser cockpit (a local Node server plus WebSocket) is kept only as the escape hatch for terminals that cannot render richly. It is never the foundation.

## Current state (v0)

Shipped on `design/rpi-cockpit`:

| Piece                    | What it provides                                                                                                                                                                                         |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Protocol core            | Beat schemas (`events.ts`), a pure reducer (`state.ts`), and the view-model (`render.ts`); MCP tools for every beat, including `present_options`, `offer_approaches`, `check_directives`, and `show_screen`. |
| Browser-cockpit renderer | The standalone web dashboard: structured RPI loop view, blocking decisions, a steer panel, an agent-authored sandboxed screen pane; hardened with per-session token auth, loopback-only bind, and a finite decision timeout. |
| Host-agnostic talk-back  | Directives and decisions are also written to JSONL files, so steering works without a live MCP connection.                                                                                                |
| Cross-host launch        | An idempotent `init` command writes the correct MCP config and narration into Claude Code, Codex, and VS Code.                                                                                            |
| Agent instrumentation    | The HVE Core RPI agents narrate to the Cockpit when its tools are present.                                                                                                                                |

In short, we have the protocol and one heavy renderer. The roadmap is mostly about the light renderers and their polish.

## Horizons

### Now (v1): render natively and server-less in the primary surfaces

Prove the bet by rendering the existing experience with no server, reusing `toViewModel` unchanged:

* A VS Code webview renderer, a panel in the HVE Core extension, with the agent and UI communicating over the extension's `postMessage` rather than HTTP or WS.
* A Claude Code inline renderer, with the view-model emitted as inline SVG or HTML widgets the host paints in the conversation (the mechanism already demonstrated for diagrams) and click-through back to the agent.

This horizon is done when the same session looks good and stays interactive in both VS Code and Claude Code with zero localhost server.

### Next: make it a genuinely great UX

With native rendering in place, invest in quality across every renderer:

* A polished Fluent or Liquid-Glass visual language, consistent across surfaces.
* Motion and micro-interactions that make state changes feel alive rather than noisy.
* A calm, glanceable presence, a status surface you read at a glance rather than a wall of logs.
* Accessibility to WCAG 2.2 (HVE Core already treats a11y as first-class).
* Responsive, adaptive layout, so the same view-model degrades gracefully from a wide VS Code panel to a narrow inline widget.

### Later: the parking lot

New capabilities live here, explicitly deferred until the UX is excellent. Two are starred for early promotion because they are too good to wait on:

* Live team-orchestration view (starred): the RPI orchestrator and its subagents as a board you watch and intervene in, with the ability to pause, swap, or spawn an agent mid-run.
* 3D codebase map (starred): a spatial map of the codebase the agent visibly moves through as it researches and edits.

The rest, parked: a session replay or time-machine scrubber, voice steering, drag-to-focus (point the agent at a file or line), rewind-and-branch from a past checkpoint, an AG-UI or A2A protocol layer so any agent framework can drive the Cockpit, and remote or mobile viewing.

## Non-goals

* No new agent capabilities during the v1 and Next phases. The agent ships in HVE Core; the Cockpit only renders and steers it.
* No hosted or cloud service. The Cockpit is local and ephemeral, and it dies with the session.
* The host owns auth and identity. The Cockpit never becomes an identity provider or a long-lived backend.
* Not a model host. It works with whatever model the host already runs.

## Relationship to HVE Core

The Cockpit is a separate companion project that consumes HVE Core's agents, while HVE Core stays deliberately artifacts-only. Notably, the server-less renderers emit content the host renders (that is, artifacts rather than runtime), so the host-inline and webview renderers could later be proposed back into HVE Core without breaking its no-runtime charter. The standalone server cockpit stays here, in the companion project.

## How to influence this roadmap

This is an early, opinionated roadmap and will move with what we learn building the v1 renderers. The ordering above is a bet, not a contract: the "Later" items (especially the two starred ones) can jump forward the moment the UX foundation is solid enough to carry them.

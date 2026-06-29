<!-- markdownlint-disable MD013 -->
# gh-aw flow surface: deep-thinking exploration (pre-brainstorm)

Status: EXPLORATION, not an approved design. This is the overnight thinking for the GitHub Agentic Workflows (gh-aw, agent #58) cockpit surface, the last open Meta-Utility. We brainstorm and decide together in the morning; nothing here is committed to. The user's ask: a GUI with the look and feel of LangFlow / n8n (a node canvas).

## 1. What gh-aw actually is (grounded in this repo)

A gh-aw workflow is a single markdown file under `.github/workflows/*.md`: YAML frontmatter plus a prose body. `gh aw compile` turns it into a full GitHub Actions `*.lock.yml` (about 1600 lines) that guards activation, starts MCP servers, and runs one AI agent with the prose body as its prompt. The anatomy of one workflow:

* `on:` - the trigger (issue events, PR events, push, slash command) plus `roles:` / `skip-bots:` activation guards and an optional approval `reaction:`.
* `engine:` (copilot | claude | codex), `timeout-minutes:`, `imports:` (agent instruction files inlined into the prompt), `checkout:` (none or sparse paths).
* `permissions:` - minimal read scopes.
* The prose body - the agent's procedure and constraints in natural language.
* `safe-outputs:` - the ONLY GitHub writes the agent may perform, each rate-limited and allow/block-listed: `add-comment`, `add-labels`, `remove-labels`, `create-issue`, `create-pull-request`, `submit-pull-request-review`, `create-pull-request-review-comment`, `update-pull-request`, `noop`.

The agent #58 is a dispatcher over four operations: create, update/debug, upgrade, and report. CLI: `gh aw compile`, `gh aw logs`, `gh aw audit <run-id>`, `gh aw fix --write`.

## 2. The central realization: one workflow is not a graph; the orchestration is

A SINGLE workflow has no internal control-flow graph. It is a trigger, a set of guards, one agent prompt, and a whitelist of write operations. The branching you would draw (classify, then decide, then label) lives as PROSE in the body, not as machine-readable nodes. So a per-workflow node view is really "the shape of the prompt", which the agent narrates, not something inherent in the artifact.

The genuine graph is the ORCHESTRATION across workflows, wired by labels and events. This repo runs five workflows that hand off to each other: issue-triage applies `agent-ready` -> issue-implement triggers on `agent-ready`, opens a PR -> pr-review triggers on the PR, applies `review-passed` / `needs-revision` -> human merges -> doc-update-check triggers on push to main. The edges are derivable: a workflow's `safe-outputs.add-labels` / `create-issue` / `create-pull-request` are outputs; another workflow's `on:` is an input; an output label that matches an input trigger is an edge.

Strong validation: `docs/architecture/agentic-workflows.md` already draws BOTH levels by hand - a `stateDiagram-v2` of the label-driven handoffs (the pipeline) and per-workflow `flowchart TD`s of each agent's procedure. The cockpit surface can render what the repo currently hand-draws in mermaid, but live and agent-narrated.

## 3. The big fork to settle first: narration canvas vs authoring tool

LangFlow and n8n are AUTHORING tools: the user drags nodes and wires a flow, and it runs. The cockpit is the opposite by charter: the agent narrates its work, the cockpit renders, and the user STEERS via the directive queue (intent the agent performs); the cockpit never authors or controls. So "a LangFlow/n8n GUI" forces a choice:

* Option N - the n8n LOOK on a NARRATION canvas (charter-consistent). The gh-aw agent narrates the orchestration graph and its create/debug/upgrade work onto a node canvas; the user can steer ("trigger on PRs too", "add a create-issue output", "this run failed at the activation guard, loosen the role filter") via the existing directive channel, and the agent makes the edit and recompiles. Visually it is a node graph; behaviorally it is the cockpit we have been building. Achievable, and it is the only option that fits the surface's purpose.
* Option A - a genuine AUTHORING tool: the user builds gh-aw workflows by dragging nodes (trigger, guards, agent, each safe-output), editing config in inspectors, and the canvas round-trips to the `.md` frontmatter + prose and previews the compiled lock. This is a real workflow builder, a different and much larger artifact (two-way binding, validation, compile preview, drag-to-wire), and a departure from the narration charter. It is arguably its own app rather than a cockpit surface.

Recommendation to discuss: Option N (n8n look, narration + steer). It gives the visual we want, stays true to the cockpit, and is the natural home for what agent #58 narrates. We can leave a door open toward authoring later, but building a full editor first is the "exceptionally hard" path the user already flagged.

## 4. The surface concept (Option N): a two-level node canvas

Mirror the repo's own two diagrams.

Level 1 - Orchestration (the centerpiece). Workflows as nodes on a pannable, zoomable canvas; label/event handoffs as edges. A workflow node (an n8n-style card) shows: name, trigger glyph (issue / PR / push / slash), engine, and its safe-output chips. Edges are labeled with the handoff (`agent-ready ->`, `opens PR ->`, `review-passed ->`) and animate when a run fires along them. The agent narrates create (drop a new node, wire its edges), debug (pulse the node + edge for a failing run, mark the guard/output that blocked), and upgrade (badge nodes with version diffs).

Level 2 - Anatomy (drill-in). Click a workflow node to open its inner flow: Trigger -> Activation guards -> Agent (the prompt) -> Safe-outputs / MCP, as a small left-to-right pipeline of typed nodes (the "form as a flow" view). Inspecting a node shows its config (the trigger events, the role filter, the safe-output limits, the prompt excerpt).

Nodes carry a type (trigger | guard | agent | safe-output | mcp | workflow) and a status (designing | compiled | running | passed | failed | stale-lock). Edges carry a label and a kind (label | event | output). This is the richest state shape we have modelled: a graph, not a list.

## 5. The n8n / LangFlow look, dependency-free

We are unbundled vanilla JS with no graph library (React Flow, litegraph). We have precedent: the 3D codemap already does a dependency-free spatial canvas with a CSS-transform camera (pan / zoom / glide). A 2D node graph is within reach with the same ethos:

* Nodes: absolutely-positioned rounded cards with a typed header bar and small input/output port dots (the n8n handle look).
* Edges: a single SVG layer under the nodes drawing bezier curves between ports, with arrowheads; a class flips to "active" to animate a firing handoff (dash-offset).
* Canvas: a world `<div>` with a CSS `transform: translate() scale()` camera (reuse the codemap camera math) for pan and zoom; a faint dot grid background; an optional minimap.
* Palette + inspector: a left node palette (read-only in Option N: it is a legend of node types) and a right inspector panel showing the selected node's config. In Option A these become draggable sources and editable forms.
* Auto-layout: the orchestration graph is a small label-DAG (about 5-15 nodes). A simple longest-path layering (columns by topological depth) plus within-column ordering is enough; no layout library. The anatomy view is linear (one column). The agent can also supply positions if it wants.

## 6. Why this is hard (the honest list)

1. First graph surface: needs node positioning, edge routing, pan/zoom, selection, hover - all the things a list/table/grid never needed.
2. Auto-layout without a library (layered DAG). Tractable at this scale but real work, and easy to make ugly.
3. Matching the n8n feel (ports, bezier edges, arrowheads, grid, minimap, smooth camera) dependency-free is craft.
4. Richest data model yet: a typed node/edge graph with per-node status and a live "current operation" (create / debug / upgrade), narrated by beats.
5. Two levels (orchestration + anatomy) and the navigation between them.
6. If we ever go to Option A (authoring), add two-way binding, validation, drag-to-wire, and compile-to-markdown preview - a separate, much larger build.

## 7. Scope and phasing (recommendation)

Decompose. Do not try to build everything at once.

* Phase 1 (the valuable core): the Orchestration canvas (workflows + label/event edges) as a narrated, steerable n8n-look view with pan/zoom, node cards, labeled bezier edges, an inspector, and per-node run status. This alone visualizes the emergent agentic pipeline, which nothing else in the cockpit shows, and it is what `docs/architecture/agentic-workflows.md` hand-draws today.
* Phase 2: the Anatomy drill-in (single-workflow trigger -> guards -> agent -> safe-outputs) and the create/debug/upgrade narration (new node, failing-run pulse, version-diff badges).
* Phase 3 (optional, maybe never): authoring / round-trip to `.md`.

Each phase is its own spec -> plan -> SDD cycle, like every surface so far.

## 8. How it connects to what we have

* The 3D codemap proves dependency-free spatial canvas + camera; reuse the camera math for pan/zoom.
* The gallery proves we can render many framed things; not needed here but the iframe lock-file preview (showing the compiled `.lock.yml`) could reuse `show_screen`.
* The narration + directive model (Steer) is exactly how the user would nudge a workflow's trigger/outputs without the cockpit authoring it.
* The surface pattern is the same spine every cockpit view uses: a new `ghaw` (or `flow`) domain, beats to add nodes/edges/status, a pure view-model, a `#ghaw-view`, MCP tools the agent narrates with.

## 9. Decision points for the morning (questions to sleep on)

1. Narration canvas (Option N) or genuine authoring tool (Option A)? This sets everything else.
2. Lead with the Orchestration graph (workflows wired by labels), the Anatomy graph (one workflow's trigger -> agent -> outputs), or both with drill-in?
3. How literal to the n8n look: full ports + bezier edges + minimap + palette, or a cleaner cockpit-native node graph that merely evokes it?
4. Is the centerpiece the live run (watch a real gh-aw pipeline fire across nodes) or the structure (the shape of the workflows and their handoffs), or both?
5. Phase 1 scope: just the orchestration canvas first, or orchestration + anatomy together?

<!-- markdownlint-disable MD013 -->
# 3D codebase map design

## Purpose

This is the second starred item from the parking lot: a spatial map of the codebase that the agent visibly moves through as it researches and edits. It turns "the agent is working somewhere in a large repo" into a picture you can watch: files laid out in space, a camera that travels to whatever the agent is touching, and a visible trail of what has been read and changed. It is the most experimental view, so this spec deliberately scopes a realistic first cut rather than a game engine.

This spec covers the codemap view: the rendering approach and why, a new `codemap` domain, the beats that set the map and move the focus, the layout and camera, and the update strategy that keeps the camera smooth. It follows the loop-view shape of the other views and the agent-driven, declarative beat style used throughout.

## Rendering approach: CSS 3D, not WebGL

The cockpit client is unbundled vanilla JavaScript served statically, and the product is local-first and offline (no external CDN, no hosted assets). A WebGL stack (Three.js) would mean vendoring a large dependency and introducing a bundling step, against both constraints. So the first cut uses CSS 3D: a `perspective` container, a `transform-style: preserve-3d` world, and nodes positioned with `translate3d`. This is genuinely three-dimensional (real perspective, depth, and a moving camera), has zero dependencies, fits the vanilla-JS client, and renders to the pane where a screenshot can verify it. A heavier WebGL version can come later if this proves its worth; the protocol below does not change if the renderer is swapped.

## What it represents

The agent supplies the relevant slice of the codebase for the task (not the whole repo), so the map stays legible and bounded. Each node is a file or directory; the agent moves the focus as it works, and nodes accumulate read and edited states.

| Concept | In the map |
| --- | --- |
| Files and directories | Nodes positioned in 3D space, grouped by their directory |
| The agent's location | The focused node, brought to the front and center by the camera |
| What has been touched | Nodes marked read or edited, a visible trail of the work |

The node set is bounded by design (a recommended ceiling of around forty nodes); the agent sends the slice that matters for the current task. If the agent needs a different slice, it sends a new map.

## Layout and camera

The layout is deterministic from the node data, so the same map always looks the same and re-renders are stable (no random jitter that jumps between frames). Files are grouped by their top-level directory; each group is a cluster placed around a ring on the horizontal plane, and within a cluster the files sit in a small grid, with depth from how deep the path is. The world has a slight tilt so the depth reads.

The camera is the world container's transform. When the focus changes, the world translates so the focused node moves to the front and center, with a transition, so the camera appears to travel through the codebase to where the agent is. The focused node scales up and highlights; nearer nodes are larger and clearer through natural perspective, farther ones recede.

## The update strategy (smooth camera)

This view cannot use the full-innerHTML-replace pattern the other views use, because rebuilding the scene on every beat would reset the camera transition and make it jump. So the client builds the node elements once, when the map is set, and on a focus or touch beat it only updates the camera transform and the node state classes on the existing elements. The client tracks the rendered node ids and rebuilds only when the node set actually changes. This is the one view with stateful client rendering, and it is necessary for the camera to glide rather than snap.

## Protocol additions

Three beats, agent-driven and declarative.

| Beat | Fields | Effect |
| --- | --- | --- |
| `codemap.set` | `nodes` (each: id, path, kind file or dir, optional group) | Switches the domain to `codemap`, sets the node set, resets focus and touches |
| `codemap.focus` | `id` | Moves the camera to that node and highlights it; a no-op if the id is unknown |
| `codemap.touch` | `id`, `kind` (read or edit) | Marks a node read or edited (the trail); a no-op if the id is unknown |

The MCP surface adds `codemap_set`, `codemap_focus`, and `codemap_touch`. Like the other view starts, `codemap.set` is self-sufficient: it sets `view: "loop"` and `domain: "codemap"`.

## State and view-model

Session state gains `codemap` in the domain union, a `codemapNodes` array of `{ id, path, kind, group? }`, a `codemapFocus: string | null`, and a `codemapTouches` map of node id to the strongest touch (edit outranks read). The reducers follow the existing idioms. The view-model projects the nodes (with their computed group), the focus id, and the touch state per node, ready for the client to lay out.

## Rendering

The client adds a `#codemap-view` section routed when `domain` is `codemap`, hiding the other views. Inside it a `perspective` container holds a `preserve-3d` world of node cards. `renderCodemap` builds the cards on a new node set and otherwise updates the camera transform and the focused, read, and edited classes on the existing cards. A small legend explains the states. Labels stay upright (only the world tilts) so filenames are readable. A `prefers-reduced-motion` reduction makes the camera move instantly rather than gliding.

## Scope

In scope:

* CSS-3D rendering with a perspective world, deterministic cluster layout, and a camera that eases to the focused node.
* The `codemap` domain, the node/focus/touch state, and the view-model projection.
* The three beats and their MCP tools.
* Read and edited node states and a legend.
* The build-once, update-in-place client strategy for a smooth camera, plus reduced-motion.
* Tests for the reducers, the view-model, the MCP tools, and the client rendering, routing, focus highlight, and touch states.

Deferred:

* A WebGL renderer. CSS 3D is the first cut.
* User-controlled camera (orbit, pan, zoom by the user). The camera follows the agent for now.
* Auto-deriving the node set from the repo. The agent supplies the relevant slice.
* Edges or call-graph links between nodes. The first cut is spatial, not a graph.
* Very large maps. The node set is bounded; huge repos are a later concern.

## Non-goals

* Not a file explorer or an editor. It is a watch surface for where the agent is working.
* Not a literal repository renderer. It shows the slice the agent declares as relevant, not the whole tree.
* No new agent capabilities. The agent decides what to map and where it is; the cockpit renders it.

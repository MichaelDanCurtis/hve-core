<!-- markdownlint-disable MD013 -->
# Backlog hierarchy design

## Purpose

The cockpit's kanban board renders backlog items as flat cards in state columns. That fits the three backlog managers (GitHub, ADO, Jira) doing triage and sprint execution. But two of the five backlog-category agents, the PRD-to-WIT planners (AzDO #42, Jira #43), produce a work-item *hierarchy*, Epic to Feature to Story to Task, and that tree is their entire output. On a flat board the Epic, Feature, Story, and Task scatter across columns as unrelated cards; the parent/child structure the planner is proposing is lost.

This design adds an optional parent to a backlog item and renders the hierarchy on the board: a child nests under its parent when both are in the same column, and shows a parent reference line when the parent lives in a different column. State columns stay authoritative, so the change serves both the planners (a proposed tree, typically all in one column, nests fully) and the managers (a live board, where parent and child sit in different states, keeps lineage visible).

## Data model

`BacklogItem` (in `state.ts`) gains an optional `parent?: string`, the id of the parent item. The `item.add` beat (`events.ts`) and the `add_item` MCP tool (`mcp.ts`) gain `parent?` as an optional string, passed through to the beat. `item.move` is unchanged: moving a card changes its column, never its parentage. No new MCP tool; the tool count stays 30.

## The view-model does the hierarchy math

The hierarchy projection is pure and testable, so it lives in `toViewModel` (`render.ts`), not the client. `toViewModel` already groups items by column. For each column it now emits an *ordered* list where each item carries two derived fields:

* `depth`: the number of consecutive ancestors present in the *same column*. Walk the item's parent chain; for each step where the parent is also in this column, increment depth and continue from that parent; stop at the first ancestor not in the column. A root (no parent, or parent not in this column) has `depth 0`.
* `parentRef`: set only when the item's immediate parent is NOT in this column. It is the parent item's title, resolved globally across all board items; if the parent id is not on the board at all, `parentRef` falls back to the raw parent id so lineage is never silently dropped. When the parent IS in the same column, `parentRef` is absent (the nesting shows the relationship).

The ordering is depth-first by same-column parentage: emit each column root in the board's existing insertion order, and immediately after each root emit its same-column descendants depth-first. So a parent always immediately precedes its same-column children, and the indentation reads top to bottom. Cross-column children appear at their column root (in insertion order) with a `parentRef`.

Worked example. Items: Epic E (Planned), Feature F parent E (Planned), Story S parent F (Planned). One column "Planned" emits `[E depth 0, F depth 1, S depth 2]`. Now move S to "Done": "Planned" emits `[E depth 0, F depth 1]`, "Done" emits `[S depth 0, parentRef "F's title"]`.

The view-model board item type becomes `{ id, title, kind?, tier?, depth, parentRef? }` (the existing fields plus the two derived ones; the raw `parent` is consumed by the projection and need not be exposed).

## Client rendering

`renderBoard` (`client.js`) renders each column's ordered item list flatly: each card gets a left indent proportional to `depth` (for example `style="margin-left: {depth * 16}px"`), and a card whose `parentRef` is set shows a muted line `↳ under {parentRef}` above or below the title. Every interpolated field, including `parentRef`, goes through the existing `esc()` helper. The existing id/title/kind/tier rendering is unchanged. Indent depth is naturally bounded by the hierarchy (Epic/Feature/Story/Task is four levels); no artificial clamp is needed, but the `margin-left` approach degrades gracefully if a deeper chain ever appears.

## Agent contract

`agents/cockpit-instructions.md` gains: `add_item` takes an optional `parent` (the parent item's id), and a note that the PRD-to-WIT planners should pass `parent` so the proposed Epic to Feature to Story to Task hierarchy renders on the board, typically by adding all items to a single planning column so the tree nests fully.

## Testing

* state (`tests/state.test.ts`): `item.add` with `parent` stores it on the item; without `parent` the field is absent/undefined.
* view-model (`tests/render.test.ts`): a three-item chain in one column projects depths 0/1/2 in parent-first order; moving the leaf to another column gives the leaf `depth 0` + a `parentRef` of the parent's title in the new column and removes it from the first; an item whose parent id is not on the board gets `parentRef` equal to the raw id; a child whose parent is in the same column has no `parentRef`.
* client (`tests/backlog-client.test.ts`): an indented card carries the depth-proportional `margin-left`; a cross-column child renders the `↳ under {parentRef}` line; a root card has neither.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the optional `parent` through beat, state, tool, and contract; the `depth`/`parentRef` view-model projection and ordering; the indent + reference-line rendering; the tests above.

Deferred / non-goals:

* Swimlane rows (epic lanes by state columns) and a separate tree-only view: rejected during design in favour of indent-plus-reference, which keeps the state columns authoritative and adds no second representation.
* Drag-to-reparent or any board mutation from the pane: the cockpit captures intent and the agent performs; reparenting is not a cockpit action.
* Collapsing/expanding a subtree, WIP limits, and per-item detail popovers: not needed to make the hierarchy legible.
* Auto-inferring parentage from tier (T1/T2/T3): the agent supplies `parent` explicitly; the cockpit does not guess structure from the tier chip.

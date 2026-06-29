<!-- markdownlint-disable MD013 -->
# Memory view design

## Purpose

The Memory agent (#57) persists conversation and session memory for continuity, and is the handoff target other agents (the ADO / GitHub / Jira Backlog Managers, the RPI Agent) hand state to so it survives across runs. Today the cockpit serves it only through the context badges: the active standards/skills/collection strip says nothing about what the agent actually recalled or wrote. The knowledge the agent is carrying, and where it came from, has no home.

This design adds a dedicated `memory` loop view. The centerpiece is the memory store: entries grouped by category, each tagged with what happened to it this session (recalled, added, or updated). A secondary handoff strip shows which agent handed what to Memory and what Memory did with it. The user chose entries-plus-handoffs with the entries grouped by category.

## A new `memory` domain

`memory` becomes a new loop-view domain, peer to `rpi`, `review`, `interview`, `backlog`, `team`, `codemap`, `dataprofile`, `gallery`, and `promptlab`. Opening it switches the cockpit to the memory view, exactly as `review.start` / `backlog.start` switch to theirs.

## State

Three new `SessionState` fields:

* `memoryTitle: string | null` (the board heading, for example a collection name; null when no memory view is active).
* `memoryEntries: MemoryEntry[]`, where `MemoryEntry = { id: string; title?: string; content: string; category: string; tag: MemoryTag }` and `MemoryTag = "recalled" | "added" | "updated"`.
* `memoryHandoffs: MemoryHandoff[]`, where `MemoryHandoff = { id: string; from: string; summary: string; action: HandoffAction }` and `HandoffAction = "stored" | "merged" | "recalled"`.

`category` is a free string the agent supplies (a memory type like user/feedback/project/reference, or a source); the view groups by it in first-seen order, the same way the gallery groups by `group`. Both collections upsert by `id` in place (preserve order on update, append a new id), the rule `item.add` / `add_case` use.

## Beats and tools

Three new beats and three new MCP tools, following the `promptlab_start` / `add_case` shape. The MCP tool count goes from 38 to 41.

| Tool | Beat | Effect |
| --- | --- | --- |
| `memory_open(title?)` | `memory.open` | Switch the view to `memory`, set `memoryTitle` (from `title`, default null), and clear both `memoryEntries` and `memoryHandoffs` (a fresh session view). |
| `add_memory(id, content, category, tag?, title?)` | `memory.add` | Append a `MemoryEntry`, or update the existing one with the same `id` in place. `tag` defaults to `"recalled"` when omitted. |
| `add_handoff(id, from, summary, action?)` | `handoff.add` | Append a `MemoryHandoff`, or update the existing one with the same `id` in place. `action` defaults to `"stored"` when omitted. |

`add_memory`'s `tag` is a zod enum `["recalled","added","updated"]` and `add_handoff`'s `action` is a zod enum `["stored","merged","recalled"]` at the tool boundary, so an out-of-enum value is rejected rather than rendered. The tool descriptions disambiguate a memory entry from a kanban item / dataset column / prompt case, and a handoff `from` as the handing-off agent's name.

## View-model

`toViewModel` projects:

```text
memory: {
  title: string | null;
  counts: { recalled: number; added: number; updated: number; total: number };
  entries: { id: string; title: string | null; content: string; category: string; tag: string }[];
  handoffs: { id: string; from: string; summary: string; action: string }[];
}
```

`counts` is derived purely by counting entry tags (the recalled/added/updated summary); `entries` and `handoffs` are pass-throughs of the state arrays with `title` null-coalesced. Grouping by `category` happens in the client renderer (first-seen order), not in the projection. The projection stays pure.

## The view

A new `#memory-view`, a sibling of the other loop views, shown when `v.domain === "memory"` and hidden otherwise (the same mutually-exclusive routing the other domains use). It fills `#loop` and renders:

* A header line: `{title}` (or "Memory") with a derived count strip of tag chips (recalled / added / updated, each colored to its tag, shown only when nonzero).
* The centerpiece, the entries grouped by `category`: a small category heading per group, then one row per `MemoryEntry` showing its title (or the start of its content), a color-coded tag pill (recalled cyan / added green / updated amber), and a one-line content preview. Clicking a row expands it inline to show the full content. An empty store (no entries) shows an empty-state row.
* A secondary handoff strip (beside the entries on a wide viewport, stacked below on a narrow one): one card per `MemoryHandoff` showing `from`, the `summary`, and an action pill (stored / merged / recalled). When there are no handoffs it shows an empty-state, consistent with the entries empty-state (rather than hiding the panel).

Every interpolated field goes through the existing `esc()` helper. The expand/collapse is local view state (a delegated click toggling an `open` class), consistent with how the other client interactions are wired; the open state is keyed by the entry `id` and reconciled against the current entries each render (the pattern the promptlab case rows use).

## Agent contract

`agents/cockpit-instructions.md` gains a memory section: the Memory agent calls `memory_open(title?)` when it activates (optionally naming the collection); `add_memory(id, content, category, tag?, title?)` per fact it recalls (`tag: recalled`) or writes (`tag: added` / `updated`), grouping by `category`; and `add_handoff(id, from, summary, action?)` when another agent hands state to it (`from` the agent name, `action` what memory did). The context badges (`set_context`) remain the agent's active-standards strip and are orthogonal to this store.

## Testing

* state: `memory.open` sets the title and clears both arrays; `memory.add` appends, defaults `tag` to `recalled`, and a same-id add updates in place (order preserved); `handoff.add` appends and upserts by id and defaults `action` to `stored`.
* view-model: `toViewModel` exposes `memory.title`, the derived `counts`, and the `entries`/`handoffs` arrays with every field; null title and empty arrays when no memory view started.
* tools: a round trip drives `memory_open` + `add_memory` + `add_handoff` over the in-memory transport and asserts `bridge.state.memoryEntries` / `memoryHandoffs`; the tool-count assertion goes 38 to 41; `add_memory` rejects a `tag` outside the enum and `add_handoff` rejects an `action` outside the enum.
* client: the `memory` domain shows `#memory-view` and hides the others; entries render grouped by category; the tag pill carries the right class; clicking an entry expands its full content; the handoff strip shows one card per handoff with the action pill; the count chips reflect the tag counts; fields are escaped. The client test follows the existing happy-dom render-harness pattern.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `memory` domain, the three state fields and their three beats, the three MCP tools with tag/action validation, the view-model projection with the derived counts, the `#memory-view` (header counts + category-grouped entries + handoff strip) and its routing, the agent contract, and the tests above.

Deferred / non-goals:

* Editing or deleting memory from the pane: the cockpit narrates the agent's store, it does not mutate it (the charter boundary).
* Cross-session diff or a full history timeline (what changed since last run): the view shows the current session's recalled/written set plus a tag, not a longitudinal diff.
* Semantic search or filtering over entries: the agent supplies a meaningful category grouping and order.
* Inferring `tag`/`action` in the cockpit: the agent supplies them; the cockpit does not classify memory activity itself.

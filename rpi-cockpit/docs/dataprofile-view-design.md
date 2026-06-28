<!-- markdownlint-disable MD013 -->
# Dataset profile view design

## Purpose

The data-science agents mostly reuse existing cockpit surfaces: the Streamlit dashboard generator drives `set_app_frame`, its tester pairs the app frame with the findings panel, the eval-dataset creator uses the interview, and the notebook generator previews through `show_screen`. The one artifact with no good home is the dataset profile (data dictionary) the DS Gen Data Spec agent (#45) produces. Today it would be crammed into `show_screen` as hand-rendered HTML.

A dataset profile is inherently tabular: a header about the dataset and a row per column with its type and quality statistics. That is exactly the kind of structured content the cockpit renders natively elsewhere (findings grouped by severity, the kanban board, the team grid). This design adds a dedicated `dataprofile` loop view so the profile renders as a real table, the foundation a data scientist reads before building a notebook or dashboard.

## A new `dataprofile` domain

`dataprofile` becomes a new loop-view domain, peer to `rpi`, `review`, `interview`, `backlog`, `team`, and `codemap`. Opening it switches the cockpit to the profile view, exactly as `review.start` / `backlog.start` switch to their views.

## State

Two new `SessionState` fields:

* `profileDataset: { name: string; rows?: number; cols?: number; source?: string } | null` (the dataset header; null when no profile is active).
* `profileColumns: ProfileColumn[]`, where `ProfileColumn = { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk" }`.

`stat` is a free-form representative-value string the agent fills, so one field serves every column type (for example `"0-4820"` for a numeric range, `"mean 126.2"`, or `"top: US 42%"` for a category). `quality` is an optional data-quality traffic light (for high-null, constant, or skewed columns); when absent the column shows no quality indicator.

## Beats and tools

Two new beats and two new MCP tools, following the `backlog_start` / `add_item` shape exactly. The MCP tool count goes from 30 to 32.

| Tool | Beat | Effect |
| --- | --- | --- |
| `dataset_profile(name, rows?, columns?, source?)` | `profile.start` | Switch the view to `dataprofile`, set `profileDataset`, and clear `profileColumns` (a fresh profile). |
| `add_column(name, dtype, nullPct?, distinct?, stat?, quality?)` | `column.add` | Append a `ProfileColumn`, or update the existing one with the same `name` in place (the same upsert-by-id rule `item.add` uses). |

`add_column`'s `quality` is constrained to `"ok" | "warn" | "risk"` at the tool boundary (a zod enum), so an unknown value is rejected rather than rendered. The tool's description disambiguates "column" as a dataset field, distinct from a kanban board column.

## View-model

`toViewModel` projects `dataProfile: { dataset: { name; rows?; cols?; source? } | null; columns: { name; dtype; nullPct?; distinct?; stat?; quality? }[] }`, a direct pass-through of the two state fields (no derivation). The projection stays pure.

## The view

A new `#dataprofile-view`, a sibling of the other loop views, shown when `v.domain === "dataprofile"` and hidden otherwise (the same mutually-exclusive routing the other domains use). It renders:

* A header line: `{name}` with a muted suffix `{rows} rows x {cols} cols - {source}` (each part shown only when present).
* A table with a header row (Column, Type, Null %, Distinct, Stat, and a final quality column) and one body row per `ProfileColumn`: the column name, its dtype, the null percentage (formatted with a `%`), the distinct count, the stat string, and a quality dot colored green/amber/red for `ok`/`warn`/`risk` (absent when `quality` is unset).

Every interpolated field goes through the existing `esc()` helper. The table degrades gracefully: an empty profile (no columns yet) shows the header and an empty-state row.

## Agent contract

`agents/cockpit-instructions.md` gains a data-science section: the Data Spec agent drives `dataset_profile` then an `add_column` per field; and a mapping note for the rest of the category (the Streamlit dashboard agent uses `set_app_frame`; its tester pairs `set_app_frame` with `review_start` + `add_finding`; the notebook generator previews with `show_screen`; the eval-dataset creator uses the interview Q&A).

## Testing

* state: `profile.start` sets the dataset and clears columns; `column.add` appends, and a second `column.add` with the same name updates in place.
* view-model: `toViewModel` exposes `dataProfile.dataset` and the `columns` array with every field; null dataset when no profile started.
* tools: a round trip drives `dataset_profile` + `add_column` over the in-memory transport and asserts `bridge.state.profileDataset` / `profileColumns`; the tool count assertion goes 30 to 32; `add_column` rejects a `quality` outside the enum.
* client: the `dataprofile` domain shows `#dataprofile-view` and hides the others; one table row per column; the quality dot carries the right class for `ok`/`warn`/`risk` and is absent when unset; fields are escaped.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `dataprofile` domain, the two state fields and their beats, the two MCP tools, the view-model projection, the `#dataprofile-view` and its routing, the agent contract, and the tests above.

Deferred / non-goals:

* Sorting, filtering, or paging the column table (the cockpit is read-only narration; the agent emits the columns in a meaningful order).
* Per-column sparklines or histograms (the `stat` string carries the representative value; a chart is a larger surface and a separate decision).
* A notebook-cell renderer for the EDA notebook agent (#46): explicitly out of scope; `show_screen` serves it for now.
* Inferring `quality` from `nullPct`/`distinct` in the cockpit: the agent supplies `quality`; the cockpit does not compute data-quality judgments.

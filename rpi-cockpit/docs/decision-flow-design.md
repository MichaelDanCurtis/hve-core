<!-- markdownlint-disable MD013 -->
# Decision flow design

## Purpose

Agentic question-and-answer today is a one-way street: an agent asks one question, you answer, it asks the next, and you cannot go back. The answer you gave to question one might change once you see question four, but by then it is locked. This is the single most common frustration with guided flows like the doc-builders and Superpowers brainstorming.

The decision flow fixes that. It is one cockpit primitive that turns the agent's sequence of questions and decisions into a navigable, revisitable transcript. Answering still happens in the inline chat, where the rich descriptions and context already live (the cockpit is graphical, never a box you type into). The cockpit's contribution is to show the whole chain at once and let you click any past decision to go back to it. It replaces both the standalone decision card and the guided interview's single-question box, in every loop view.

## How the questioning actually works (and why a rewind)

In the doc-builders (PRD, BRD, ADR), in Superpowers brainstorming, and in any `present_options` / `ask_question` flow, the questions are dynamic, not a fixed form. The agent asks a question, reads the answer, and derives the next question from it. There is no static list of questions sitting in advance; it is a chain where each link depends on the previous one.

That is why going back has to be a rewind. Changing decision one does not just make decisions two and three stale, it can make them the wrong questions entirely (with a different first answer, the agent might not even ask the second). So the cockpit cannot compute a dependency graph and re-ask only the affected questions. Instead, revisiting a decision rewinds the flow to that point, you re-answer it in chat, and the agent re-derives whatever comes next. The cockpit captures the intent and visualizes the rollback; the agent performs the rewind.

## The model: answer in chat, navigate in the cockpit

| Concern | Where it lives |
| --- | --- |
| Answering a question (typing, picking) | The inline chat, via the host's native elicitation (for example AskUserQuestion in Claude Code), where the full prompt and option descriptions render |
| Seeing the whole decision chain | The cockpit decision-flow list: every decision, its answer, and its status, at a glance |
| Going back to revise a past decision | A revisit control in the cockpit that expresses intent; the agent re-asks |

The cockpit's pending entry is read-only by default (it shows the question and the options for legibility, and points you to the chat). The in-pane input stays only as a fallback for a host that has no native chat elicitation, so no host is stranded. This keeps the existing "both surfaces, first wins" robustness while making the chat the primary answer surface.

## State

A single `decisions` array replaces the current single `pendingDecision` and `pendingQuestion` slots. Each entry records:

| Field | Meaning |
| --- | --- |
| `id` | Stable id for the decision, assigned by the bridge when first asked |
| `prompt` | The question text |
| `kind` | `choice` (a bounded pick) or `text` (a free-text answer) |
| `options` | For `choice`: the offered options (id, title, optional detail, recommended) |
| `answer` | The chosen option id (for `choice`) or the text (for `text`), once answered |
| `status` | `pending`, `answered`, or `superseded` |

The "current question" is simply the entry whose status is `pending`. At most one entry is `pending` at a time. The legacy view-model fields that exposed a single decision and a single pending question are derived from this array for backward compatibility during the transition, then removed.

## Protocol

The two existing blocking tools change from holding one slot to maintaining the flow array. Both gain an optional `id`.

| Tool | New behavior |
| --- | --- |
| `present_options(prompt, options, id?)` | If `id` names an existing entry, re-open it in place (status back to `pending`, clear its answer); otherwise append a new `choice` entry with a fresh id. Block until answered, then mark the entry `answered` with the chosen id |
| `ask_question(prompt, id?)` | Same, for a `text` entry |

Resolving an answer (from the chat elicitation, or the in-pane fallback) marks the pending entry `answered` and stores the answer. The blocking and first-answer-wins race that exists today is unchanged; only the bookkeeping moves from a single slot to the array.

One new inbound intent drives the rewind, alongside the existing steer, decide, answer, navigate, navigator, and intervene frames:

* `{ type: "revise", id }` is sent when the user clicks a past decision's revisit control. The bridge sets that entry back to `pending` (clearing its answer), sets every entry after it to `superseded`, and enqueues a directive the agent drains through `check_directives`: re-ask that decision and reconsider what follows. The cockpit never re-runs the agent itself; it rolls the flow back visually and expresses the intent.

## The decision-flow view (the hybrid list)

The flow renders as a vertical, scrolling list in the active loop view's primary work area, replacing the standalone decision card and the interview's question box. It is cross-domain: it appears wherever the agent is running a sequence of decisions, prominently in the RPI build loop (the center column) and in the guided doc-builder interview, and in any other loop view a decision fires in.

Each row shows:

* A status glyph: answered (check), pending (the active accent), or superseded (muted, "under review").
* The prompt.
* For a `choice`: the offered options as read-only chips, with the chosen one highlighted. For a `text`: the answer text.
* A revisit control on answered rows.

The `pending` row is accented and reads "answer in chat". Superseded rows keep their previous answer visible, greyed, so you can see what the chain was while the agent re-walks it. Because the list scrolls, a twenty-question interview stays legible where a horizontal stepper would not.

## Revisit (the rewind), end to end

1. You click revisit on an answered decision. The client sends `{ type: "revise", id }`.
2. The bridge sets that entry to `pending`, sets the entries after it to `superseded`, and enqueues the revise directive.
3. The cockpit re-renders immediately: the revised decision is active again, the downstream rows go grey "under review".
4. The agent drains the directive, re-asks that decision (calling `present_options` or `ask_question` with the same `id`), and you re-answer in chat.
5. The agent continues, re-asking the downstream decisions (which may be the same or different). Each re-answer clears that row's superseded state back to answered. Any decision the new chain no longer asks simply stays superseded.

## Agent contract

`rpi-cockpit/agents/cockpit-instructions.md` gains short guidance under the decision and question section: drive the flow by calling `present_options` / `ask_question` as you ask each thing; when `check_directives` returns a revise directive for a decision, re-ask that decision by its id and reconsider the questions that follow, since an earlier answer may change them.

## Scope

In scope:

* The `decisions` array in session state and the reducers that append, answer, re-open, and supersede entries.
* The reworked `present_options` and `ask_question` (optional `id`, flow bookkeeping) and the `revise` inbound frame plus its bridge handler and directive.
* The view-model projection of the flow, and the hybrid decision-flow list rendered in the active loop view, replacing the old decision card and interview question box.
* The read-only-by-default pending entry with an in-pane fallback only where the host lacks native elicitation.
* The agent-contract addition.
* Tests for the reducers (append, answer, re-open by id, supersede-on-revise), the view-model projection, the tools, the revise frame, and the client rendering and revisit click.

Deferred:

* A branching or tree visualization of alternate chains. The flow is a single linear list; a revise rolls it back rather than forking a visible branch.
* Diffing old answers against new ones after a revise.
* Previewing the downstream impact of a revise before committing to it.
* Editing an answer in place in the cockpit without going through the chat.

## Non-goals

* The cockpit does not answer questions and does not rewind the agent itself. It shows the flow and expresses intent; the agent asks and re-asks. This is the same launch boundary the rest of the cockpit holds.
* The decision flow does not replace the chat as the place you type. It is legibility and navigation, not a second input surface.
* No new agent capabilities. The questioning ships in the agents; the cockpit renders and steers it.

<!-- markdownlint-disable MD013 -->
# Agent graphic verification matrix

A row per HVE Core agent (all 65), with the cockpit surface it drives, the shape of its output, and a verdict on whether the graphic renders that agent correctly. The cockpit renders by SURFACE (domain view), not per agent, so agents that share a surface render identically; the verdicts below are grounded in live verification of every distinct surface (see "Surfaces verified live" at the end) plus an assessment of whether each agent's output shape fits its surface.

Verdict key:

* OK: the agent's output renders correctly on a surface verified live.
* SERVED: no dedicated view, but a generic surface (show_screen, app-frame, context badges) carries it correctly.
* FLAG: the agent's output shape does not fit its mapped surface well (a real gap).
* NONE: no cockpit surface today.

## Summary

* 65 agents. OK: 56. SERVED: 5. FLAG: 3. NONE: 1.
* Every distinct surface was driven live this session and renders correctly: the RPI build loop, the reviewers findings panel (with the orchestrator pipeline strip), the guided interview (with the program stepper and sub-progress), the backlog kanban (with parent/child hierarchy), the team roster, the 3D codemap, the dataset-profile table, the screen pane, the app-frame, and the context badges.
* The only genuine gaps are the three FLAG rows and the one NONE row, listed under "Flagged" below. None block normal use; each is a candidate follow-up.

## build-loop (RPI view)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 1 | RPI Agent | rpi | phase rail + subagents + validations + steer | OK |
| 2 | Task Researcher | rpi (+ codemap in research) | phases, artifacts, research notes | OK |
| 3 | Task Planner | rpi | plan artifacts, phase progress | OK |
| 4 | Task Implementor | rpi | subagents, change records, validations | OK |
| 5 | Task Reviewer | rpi | validation gate, subagents | OK |
| 6 | Task Challenger | rpi | the decision flow (What/Why/How questions) | OK |
| 7 | Phase Implementor | rpi | a subagent row + validations | OK |
| 8 | Plan Validator | rpi | severity-graded findings | FLAG |
| 9 | Implementation Validator | rpi | severity-graded findings | FLAG |
| 10 | RPI Validator | rpi | severity-graded findings | FLAG |
| 11 | Researcher Subagent | rpi + codemap | a subagent row; codemap nodes during research | OK |
| 12 | Network ISA-95 Planner | rpi | phased planning, artifacts | OK |

FLAG (8, 9, 10): the three validators produce severity-graded findings, but the RPI validation gate renders each check as a single status pill (ok/running/fail), so the per-finding severity and detail have no home inside the build loop. Switching to `add_finding` would surface them, but that leaves the RPI domain for the review domain. Candidate follow-up: let a failed validation-gate check expand into its findings inline, or let a validator narrate findings that show within the RPI loop.

## review (findings panel)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 13 | Code Review Full | review (+ pipeline strip) | findings + subagent pipeline | OK |
| 14 | Code Review Functional | review | severity findings with file:line | OK |
| 15 | Code Review Standards | review | severity findings | OK |
| 16 | Code Review Accessibility | review | severity findings | OK |
| 17 | PR Review | review | severity findings | OK |
| 18 | PR Walkthrough | review (should be screen) | narrative orientation, not findings | FLAG |
| 19 | Dependency Reviewer | review | severity findings | OK |
| 20 | Security Reviewer | review (+ pipeline strip) | findings + subagent pipeline | OK |
| 21 | Accessibility Reviewer | review (+ pipeline strip) | findings + subagent pipeline | OK |
| 22 | RAI Reviewer | review (+ pipeline strip) | findings + subagent pipeline | OK |
| 23 | Codebase Profiler | review (pipeline strip row) | a subagent row | OK |
| 24 | Finding Deep Verifier | review (pipeline strip row) | a subagent row | OK |
| 25 | Report Generator | review (pipeline strip row) | a subagent row | OK |

FLAG (18): PR Walkthrough produces a narrative orientation (design forks, implicit bets, architectural shape), not severity-graded findings, so the findings panel is the wrong shape. The narration contract already directs narrative reviewers to use `show_screen`; this row is OK once the agent follows that guidance (it is a contract-adherence flag, not a missing surface).

## doc-builder (interview view; quality reviewers -> review)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 26 | PRD Builder | interview | guided Q&A + growing draft | OK |
| 27 | BRD Builder | interview | guided Q&A + growing draft | OK |
| 28 | ADR Creator | interview (+ stepper) | Frame/Decide/Govern stepper + Q&A + draft | OK |
| 29 | Product Manager Advisor | interview | guided Q&A | OK |
| 30 | System Architecture Reviewer | interview | Q&A + draft | OK |
| 31 | Meeting Analyst | interview | extracted requirements draft | OK |
| 32 | Security Planner | interview (+ stepper) | phased program + Q&A | OK |
| 33 | SSSC Planner | interview (+ stepper) | six-phase stepper + Q&A | OK |
| 34 | RAI Planner | interview (+ stepper) | phased program + Q&A | OK |
| 35 | Accessibility Planner | interview (+ stepper) | phased program + Q&A | OK |
| 36 | BRD Quality Reviewer | review | severity findings | OK |
| 37 | PRD Quality Reviewer | review | severity findings | OK |
| 38 | RAI Skill Assessor | review | structured findings | OK |

## backlog (kanban view)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 39 | GitHub Backlog Manager | backlog | columns + items + action line | OK |
| 40 | ADO Backlog Manager | backlog | columns + items + action line | OK |
| 41 | Jira Backlog Manager | backlog | columns + items + action line | OK |
| 42 | AzDO PRD to WIT | backlog (hierarchy) | Epic/Feature/Story/Task tree | OK |
| 43 | Jira PRD to WIT | backlog (hierarchy) | Epic/Feature/Story/Task tree | OK |

42 and 43 were the original hierarchy gap, now closed by the parent/child board (indent + cross-column reference).

## data-science (mixed surfaces)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 44 | Evaluation Dataset Creator | interview | interview-driven curation | OK |
| 45 | DS Gen Data Spec | dataprofile | dataset profile table | OK |
| 46 | DS Gen Jupyter Notebook | screen | a rendered notebook preview | SERVED |
| 47 | DS Gen Streamlit Dashboard | app-frame | the live dashboard embedded | OK |
| 48 | DS Test Streamlit Dashboard | app-frame + review | the live app plus test findings | OK |

## coach (interview view)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 49 | DT Coach | interview (+ stepper) | the 9-method program + Q&A | OK |
| 50 | DT Learning Tutor | interview (+ stepper + sub-progress) | curriculum + comprehension-check progress | OK |
| 51 | Agile Coach | interview | Q&A producing user stories | OK |
| 52 | Experiment Designer | interview (+ stepper) | hypothesis/vetting/planning phases | OK |
| 53 | UX UI Designer | interview | JTBD/journey Q&A + draft | OK |

## orchestrator (team view; pptx -> screen)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 54 | Documentation | team | subagent roster by status | OK |
| 55 | Prompt Builder | team | subagent roster (Tester/Evaluator/Updater) | OK |
| 56 | PowerPoint Builder | screen | a rendered slide-deck preview | SERVED |

## meta-utility (mixed)

| # | Agent | Surface | Output shape | Verdict |
| --- | --- | --- | --- | --- |
| 57 | Memory | context badges | the active context strip | SERVED |
| 58 | GitHub Agentic Workflows Agent | none-yet | workflow create/debug/upgrade status | NONE |
| 59 | Issue Triage Agent | backlog | a single triaged item | OK |
| 60 | Prompt Tester | context badges | context-only | SERVED |
| 61 | Prompt Evaluator | review | severity findings | OK |
| 62 | Prompt Updater | context badges | context-only | SERVED |
| 63 | PowerPoint Subagent | screen | slide-build preview | SERVED |
| 64 | Accessibility Framework Assessor | review | structured findings | OK |
| 65 | Skill Assessor | review | structured findings | OK |

## Flagged (the only gaps)

* FLAG 8 / 9 / 10 (Plan, Implementation, RPI Validators): severity-graded findings flattened to a binary validation-gate pill inside the RPI loop. Candidate follow-up: expand a failed gate check into its findings inline.
* FLAG 18 (PR Walkthrough): narrative, not findings; resolved by the contract directing it to `show_screen` (verify the agent follows it).
* NONE 58 (GitHub Agentic Workflows Agent): a gh-aw dispatcher with no dedicated surface; best served by `show_screen` for a workflow summary. Not worth a dedicated view for one agent.

## Surfaces verified live (this session)

Each distinct surface was driven by a real MCP producer into the live pane and screenshotted: the RPI build loop (phase rail done/active/pending, live subagents, the validation gate across ok/running/fail, the steer menu, the screen pane, the AG-UI activity stream, the context badges); the reviewers findings panel with the orchestrator pipeline strip and copyable/open-able file:line; the guided interview with the program stepper, per-step sub-progress, and the responsive side-by-side layout; the backlog kanban with the parent/child hierarchy; the team roster grouped by status with pause/swap/spawn controls; the 3D codemap with focus and read/edit trails; the dataset-profile table with quality dots; the app-frame embedding a live loopback app beside the findings panel.

# Agent Inventory

This is the canonical inventory of every agent definition in the repo, built for the per-agent cockpit testing walkthrough. Each agent is numbered globally (#1..#65) so a tester can say "let's test #14" and know exactly which agent and cockpit surface to exercise. Every row records the agent's purpose, whether it runs its own loop, whether it is invoked directly or dispatched by a parent, and which cockpit graphic should light up when it runs.

All sources live under `.github/agents/**/*.agent.md`; there are no `plugins/**/agents/**/*.agent.md` definitions in this repo. Loop, category, core-vs-subagent, and cockpit-view values are derived from each file's YAML frontmatter (`name`, `description`, `agents`, `handoffs`, `disable-model-invocation`, `model`) cross-referenced across the full set, with only a light skim of bodies to judge "is this a loop".

## Summary

* Total agents: 65 (65 in `.github/agents`, 0 in `plugins`).
* Per category:
  * build-loop: 12
  * review: 13
  * doc-builder: 13
  * backlog: 5
  * data-science: 5
  * coach: 4
  * orchestrator: 3
  * meta-utility: 10
* Core vs subagent:
  * core: 38
  * subagent: 16
  * both: 11
* Loop status:
  * yes (runs its own multi-step/phased loop): 30
  * part-of (a step inside another agent's loop): 16
  * no (single-shot): 19

Notes on the counts: "both" agents are counted once in core-vs-subagent (they appear in another agent's `agents:` list AND are user-invocable / top-level). Category counts sum to 65. The cockpit-view column maps category to the surface the cockpit lights up; see the final notes for the few agents where that mapping is judgment-dependent.

## build-loop

These are the RPI (research, plan, implement, review, discover) agents and the per-phase workers that run inside them. The cockpit `rpi` view (phase rail, subagent rows, artifacts, validation) is the target surface.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | RPI Agent | Autonomous orchestrator running Research to Plan to Implement to Review to Discover with specialized subagents | yes | core | rpi | (none) | `.github/agents/hve-core/rpi-agent.agent.md` |
| 2 | Task Researcher | Task research specialist for comprehensive project analysis | yes | both (RPI step; dispatched-by handoff from DT Coach, Product Manager Advisor, UX UI Designer) | rpi | (none) | `.github/agents/hve-core/task-researcher.agent.md` |
| 3 | Task Planner | Implementation planner that creates actionable, step-by-step plans | yes | both (handoff target of Task Researcher, System Architecture Reviewer, ADR Creator) | rpi | (none) | `.github/agents/hve-core/task-planner.agent.md` |
| 4 | Task Implementor | Executes implementation plans with progressive tracking and change records | yes | both (handoff target of Task Planner, Task Reviewer, Task Challenger) | rpi | (none) | `.github/agents/hve-core/task-implementor.agent.md` |
| 5 | Task Reviewer | Reviews completed implementation work for accuracy, completeness, and convention compliance | yes | both (handoff target of Task Implementor) | rpi | (none) | `.github/agents/hve-core/task-reviewer.agent.md` |
| 6 | Task Challenger | Adversarial questioning agent that interrogates implementations with What/Why/How questions | yes | core | rpi | (none) | `.github/agents/hve-core/task-challenger.agent.md` |
| 7 | Phase Implementor | Executes a single implementation phase from a plan with full codebase access and change tracking | part-of | subagent (RPI Agent, Task Implementor, Documentation) | rpi | MAI-Code-1-Flash / Claude Sonnet 4.6 / GPT-5.4 mini (copilot) | `.github/agents/hve-core/subagents/phase-implementor.agent.md` |
| 8 | Plan Validator | Validates implementation plans against research documents with severity-graded findings | part-of | subagent (Task Planner) | rpi | MAI-Code-1-Flash / Claude Sonnet 4.6 (copilot) | `.github/agents/hve-core/subagents/plan-validator.agent.md` |
| 9 | Implementation Validator | Validates implementation quality against architectural requirements and code standards | part-of | subagent (Task Reviewer) | rpi | MAI-Code-1-Flash / Claude Sonnet 4.6 (copilot) | `.github/agents/hve-core/subagents/implementation-validator.agent.md` |
| 10 | RPI Validator | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a phase | part-of | subagent (Task Reviewer) | rpi | MAI-Code-1-Flash / Claude Sonnet 4.6 (copilot) | `.github/agents/hve-core/subagents/rpi-validator.agent.md` |
| 11 | Researcher Subagent | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools | part-of | subagent (RPI Agent, Task Researcher, Task Planner, Task Implementor, Task Reviewer, Documentation, Prompt Builder, PowerPoint Builder, ADR Creator, BRD Builder, PRD Builder, RAI Planner, Security Planner, SSSC Planner, Accessibility Planner, Network ISA-95 Planner) | rpi | MAI-Code-1-Flash / Claude Haiku 4.5 / GPT-5.4 mini (copilot) | `.github/agents/hve-core/subagents/researcher-subagent.agent.md` |
| 12 | Network ISA-95 Planner | ISA-95-aligned network planning for secure edge Kubernetes to Azure connectivity and remediation roadmaps | yes | core | rpi | (none) | `.github/agents/project-planning/network-isa95-planner.agent.md` |

## review

Code review, PR review, security, accessibility, and RAI auditors. The cockpit `review` view (findings grouped by severity with file links) is the target surface; reviewer orchestrators also drive the team/subagent rows.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 13 | Code Review Full | Orchestrator that runs functional, standards, and accessibility code reviews via subagents and merges the report | yes | core | review | (none) | `.github/agents/coding-standards/code-review-full.agent.md` |
| 14 | Code Review Functional | Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps | no | both (Code Review Full) | review | (none) | `.github/agents/coding-standards/code-review-functional.agent.md` |
| 15 | Code Review Standards | Skills-based code reviewer applying project-defined coding standards to local changes and PRs | no | both (Code Review Full) | review | (none) | `.github/agents/coding-standards/code-review-standards.agent.md` |
| 16 | Code Review Accessibility | Pre-PR branch diff reviewer for accessibility conformance across web, mobile, and document UI surfaces | no | both (Code Review Full) | review | (none) | `.github/agents/coding-standards/code-review-accessibility.agent.md` |
| 17 | PR Review | Pull Request review assistant for code quality, security, and convention compliance | no | core | review | (none) | `.github/agents/hve-core/pr-review.agent.md` |
| 18 | PR Walkthrough | Narrative PR orientation surfacing design forks, implicit bets, and architectural shape for reviewer judgment | no | core | review | (none) | `.github/agents/hve-core/pr-walkthrough.agent.md` |
| 19 | Dependency Reviewer | Reviews dependency changes for licensing, maintenance status, necessity, and SHA pinning compliance | no | core | review | (none) | `.github/agents/dependency-reviewer.agent.md` |
| 20 | Security Reviewer | Security skill assessment orchestrator for codebase profiling and vulnerability reporting | yes | core | review | (none) | `.github/agents/security/security-reviewer.agent.md` |
| 21 | Accessibility Reviewer | Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting | yes | core | review | (none) | `.github/agents/accessibility/accessibility-reviewer.agent.md` |
| 22 | RAI Reviewer | Responsible AI standards assessment orchestrator for codebase profiling and RAI findings reporting | yes | core | review | (none) | `.github/agents/rai-planning/rai-reviewer.agent.md` |
| 23 | Codebase Profiler | Scans the repository to build a technology profile and select applicable security skills | part-of | subagent (Security Reviewer, Accessibility Reviewer, RAI Reviewer) | review | Claude Haiku 4.5 / GPT-5.4 mini (copilot) | `.github/agents/security/subagents/codebase-profiler.agent.md` |
| 24 | Finding Deep Verifier | Deep adversarial verification of FAIL and PARTIAL findings for a single security skill | part-of | subagent (Security Reviewer, Accessibility Reviewer, RAI Reviewer) | review | (none) | `.github/agents/security/subagents/finding-deep-verifier.agent.md` |
| 25 | Report Generator | Collates verified security or accessibility findings and generates a comprehensive report | part-of | subagent (Security Reviewer, Accessibility Reviewer, RAI Reviewer) | review | Claude Haiku 4.5 / GPT-5.4 mini (copilot) | `.github/agents/security/subagents/report-generator.agent.md` |

## doc-builder

PRD/BRD/ADR builders, security/RAI/accessibility/SSSC planners, PM advisor, and their quality-reviewer and assessor subagents. The cockpit `interview` view (guided Q&A with growing draft) is the primary target; the planners also write artifacts and hand off backlogs.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 26 | PRD Builder | Product Requirements Document builder with guided Q&A and reference integration | yes | both (handoff target of Meeting Analyst, Product Manager Advisor) | interview | (none) | `.github/agents/project-planning/prd-builder.agent.md` |
| 27 | BRD Builder | Business Requirements Document builder with guided Q&A and reference integration | yes | both (handoff target of Product Manager Advisor) | interview | (none) | `.github/agents/project-planning/brd-builder.agent.md` |
| 28 | ADR Creator | Phase-gated creator producing standards-aligned Architecture Decision Records (Frame, Decide, Govern) | yes | both (handoff target of System Architecture Reviewer) | interview | (none) | `.github/agents/project-planning/adr-creation.agent.md` |
| 29 | Product Manager Advisor | Product management advisor for requirements discovery, validation, and issue creation | yes | core | interview | (none) | `.github/agents/project-planning/product-manager-advisor.agent.md` |
| 30 | System Architecture Reviewer | System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment | no | core | interview | (none) | `.github/agents/project-planning/system-architecture-reviewer.agent.md` |
| 31 | Meeting Analyst | Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp | no | core | interview | (none) | `.github/agents/project-planning/meeting-analyst.agent.md` |
| 32 | Security Planner | Phase-based security planner producing security models, standards mappings, and backlog handoffs | yes | core | interview | (none) | `.github/agents/security/security-planner.agent.md` |
| 33 | SSSC Planner | Six-phase repository supply chain security assessment (OpenSSF Scorecard, SLSA, Sigstore, SBOM) | yes | core | interview | (none) | `.github/agents/security/sssc-planner.agent.md` |
| 34 | RAI Planner | Responsible AI assessment planner against NIST AI RMF 1.0, producing RAI security model and backlog handoff | yes | core | interview | (none) | `.github/agents/rai-planning/rai-planner.agent.md` |
| 35 | Accessibility Planner | Phase-based accessibility planner for WCAG 2.2, ARIA APG, Section 508, EN 301 549 with backlog handoff | yes | core | interview | (none) | `.github/agents/accessibility/accessibility-planner.agent.md` |
| 36 | BRD Quality Reviewer | Read-only BRD quality reviewer emitting BRD_STANDARD_FINDINGS_V1 and BRD_QUALITY_REPORT_V1 payloads | part-of | subagent (BRD Builder) | review | (none) | `.github/agents/project-planning/subagents/brd-quality-reviewer.agent.md` |
| 37 | PRD Quality Reviewer | Read-only PRD quality reviewer emitting PRD_STANDARD_FINDINGS_V1 and PRD_QUALITY_REPORT_V1 payloads | part-of | subagent (PRD Builder) | review | (none) | `.github/agents/project-planning/subagents/prd-quality-reviewer.agent.md` |
| 38 | RAI Skill Assessor | Assesses a single Responsible AI framework from the rai-standards skill against the codebase | part-of | subagent (RAI Reviewer) | review | (none) | `.github/agents/rai-planning/subagents/rai-skill-assessor.agent.md` |

## backlog

GitHub/ADO/Jira backlog managers and the PRD-to-work-item planners. The cockpit `backlog` view (kanban board with ordered columns and a current-action line) is the target surface.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 39 | GitHub Backlog Manager | GitHub backlog orchestrator for triage, discovery, sprint planning, and execution | yes | both (handoff target of Memory) | backlog | (none) | `.github/agents/github/github-backlog-manager.agent.md` |
| 40 | ADO Backlog Manager | Azure DevOps backlog orchestrator for triage, discovery, sprint planning, PRD-to-WIT, and execution | yes | core | backlog | (none) | `.github/agents/ado/ado-backlog-manager.agent.md` |
| 41 | Jira Backlog Manager | Jira backlog orchestrator for discovery, triage, execution, and single-issue actions | yes | core | backlog | (none) | `.github/agents/jira/jira-backlog-manager.agent.md` |
| 42 | AzDO PRD to WIT | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies | no | both (handoff target of ADO Backlog Manager) | backlog | (none) | `.github/agents/ado/ado-prd-to-wit.agent.md` |
| 43 | Jira PRD to WIT | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira | no | core | backlog | (none) | `.github/agents/jira/jira-prd-to-wit.agent.md` |

## data-science

Dataset, data-spec, notebook, dashboard generators and the dashboard tester. These produce or preview generated artifacts, so the cockpit `screen` (generator/preview pane) is the target surface.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 44 | Evaluation Dataset Creator | Creates evaluation datasets and documentation for AI agent testing via interview-driven data curation | yes | core | interview | (none) | `.github/agents/data-science/eval-dataset-creator.agent.md` |
| 45 | DS Gen Data Spec | Generate data dictionaries, machine-readable data profiles, and summaries for downstream EDA | no | core | screen | (none) | `.github/agents/data-science/gen-data-spec.agent.md` |
| 46 | DS Gen Jupyter Notebook | Create exploratory data analysis (EDA) Jupyter notebooks from data sources and data dictionaries | no | core | screen | (none) | `.github/agents/data-science/gen-jupyter-notebook.agent.md` |
| 47 | DS Gen Streamlit Dashboard | Develop a multi-page Streamlit dashboard | yes | core | screen | (none) | `.github/agents/data-science/gen-streamlit-dashboard.agent.md` |
| 48 | DS Test Streamlit Dashboard | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting | yes | core | screen | (none) | `.github/agents/data-science/test-streamlit-dashboard.agent.md` |

## coach

Design-thinking, agile, UX, and experiment-design coaches. These run guided, conversational sessions; the cockpit `interview` view is the closest target surface.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 49 | DT Coach | Design Thinking coach guiding teams through the 9-method HVE framework (Think/Speak/Empower) | yes | both (handoff target of DT Learning Tutor) | interview | (none) | `.github/agents/design-thinking/dt-coach.agent.md` |
| 50 | DT Learning Tutor | Design Thinking learning tutor with structured curriculum, comprehension checks, and adaptive pacing | yes | core | interview | (none) | `.github/agents/design-thinking/dt-learning-tutor.agent.md` |
| 51 | Agile Coach | Creates and refines goal-oriented user stories with clear acceptance criteria for any tracking tool | no | core | interview | (none) | `.github/agents/project-planning/agile-coach.agent.md` |
| 52 | Experiment Designer | Coach for designing a Minimum Viable Experiment (MVE) with hypothesis formation, vetting, and planning | yes | core | interview | (none) | `.github/agents/experimental/experiment-designer.agent.md` |
| 53 | UX UI Designer | UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements | no | both (handoff target of Product Manager Advisor) | interview | (none) | `.github/agents/project-planning/ux-ui-designer.agent.md` |

## orchestrator

Agents whose main job is to run other agents, persist session state, or build/validate other prompts and agents. These drive the cockpit `team` view (agent roster with status and actions).

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 54 | Documentation | Orchestrates documentation audit, drift, authoring, and validation through the documentation skill | yes | core | team | (none) | `.github/agents/hve-core/documentation.agent.md` |
| 55 | Prompt Builder | Prompt engineering assistant for creating and validating prompts, agents, and instructions | yes | core | team | (none) | `.github/agents/hve-core/prompt-builder.agent.md` |
| 56 | PowerPoint Builder | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx | yes | core | screen | (none) | `.github/agents/experimental/pptx.agent.md` |

## meta-utility

Single-purpose plumbing: memory/session, issue triage, prompt-pipeline subagents, the agentic-workflows dispatcher, and the assessor/generator subagents shared by reviewers. Most light up `context-only` badges or feed a parent's view rather than owning a dedicated cockpit graphic.

| # | Agent | Purpose | Loop? | Core/Subagent (parent) | Cockpit view | Model | File |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 57 | Memory | Conversation memory persistence for session continuity | no | both (handoff target of ADO/GitHub/Jira Backlog Managers, RPI Agent) | context-only | (none) | `.github/agents/hve-core/memory.agent.md` |
| 58 | GitHub Agentic Workflows Agent | GitHub Agentic Workflows (gh-aw) dispatcher: create, debug, upgrade AI-powered workflows with prompt routing (no `name:` in frontmatter; title from body H1) | no | core | none-yet | (none) | `.github/agents/agentic-workflows.agent.md` |
| 59 | Issue Triage Agent | Automated single-issue triage for classifying, labeling, quality-checking, and decomposing GitHub issues | no | core | backlog | (none) | `.github/agents/issue-triage.agent.md` |
| 60 | Prompt Tester | Tests prompt files by following them literally in a sandbox, without interpreting beyond face value | part-of | subagent (Prompt Builder) | context-only | (none) | `.github/agents/hve-core/subagents/prompt-tester.agent.md` |
| 61 | Prompt Evaluator | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings | part-of | subagent (Prompt Builder) | review | MAI-Code-1-Flash / Claude Sonnet 4.6 (copilot) | `.github/agents/hve-core/subagents/prompt-evaluator.agent.md` |
| 62 | Prompt Updater | Creates and modifies prompts, instructions, agents, and skills following prompt engineering conventions | part-of | subagent (Prompt Builder) | context-only | MAI-Code-1-Flash / Claude Sonnet 4.6 / Claude Haiku 4.5 / GPT-5.4 mini (copilot) | `.github/agents/hve-core/subagents/prompt-updater.agent.md` |
| 63 | PowerPoint Subagent | Executes PowerPoint skill operations: content extraction, YAML creation, deck building, visual validation | part-of | subagent (PowerPoint Builder) | screen | (none) | `.github/agents/experimental/subagents/pptx-subagent.agent.md` |
| 64 | Accessibility Framework Assessor | Assesses accessibility framework scopes through the consolidated Accessibility skill | part-of | subagent (Accessibility Reviewer) | review | (none) | `.github/agents/accessibility/subagents/accessibility-framework-assessor.agent.md` |
| 65 | Skill Assessor | Assesses a single security skill against the codebase and returns structured findings | part-of | subagent (Security Reviewer) | review | (none) | `.github/agents/security/subagents/skill-assessor.agent.md` |

## Notes / uncertainties

These agents need extra scrutiny during the per-agent cockpit walkthrough because their category, loop, core-status, or cockpit view was a judgment call:

* #58 GitHub Agentic Workflows Agent has no `name:` field in frontmatter (only `description` and `disable-model-invocation`); the display name is taken from its body H1. Its body says it is a "dispatcher agent" that routes to prompts, but those targets are prompt files, not agents in `agents:`, so it is filed under meta-utility with `none-yet` rather than orchestrator. Confirm at test time whether it should light any surface.
* #59 Issue Triage Agent is single-issue and GitHub-oriented; placed in meta-utility but mapped to the `backlog` view since triage is a backlog activity. Could equally be considered backlog category. Verify which view actually fits when it runs.
* #44 Evaluation Dataset Creator is in the data-science category but is interview-driven (its argument-hint and description describe guided curation), so its cockpit view is `interview`, not `screen` like the other data-science generators. Double-check the surface.
* #56 PowerPoint Builder is filed under orchestrator (it dispatches Researcher Subagent and PowerPoint Subagent) but its real output is a generated deck, so its cockpit view is `screen` rather than `team`. Confirm whether the team board or the screen pane is more useful when it runs.
* #36/#37 BRD and PRD Quality Reviewers and #38 RAI Skill Assessor are doc-builder-category subagents whose actual behavior is reviewing/assessing, so their cockpit view is `review` even though their parents are doc-builders. Verify the findings surface lights up for them.
* #30 System Architecture Reviewer and #31 Meeting Analyst are in doc-builder but are arguably review (architecture) and meta-utility (transcript extraction) respectively; both were placed by their primary downstream handoff (ADR/PRD creation). Re-evaluate if their cockpit behavior suggests a different bucket.
* Loop vs no for the pre-PR diff reviewers (#14, #15, #16) and PR Review (#17) was marked `no` (single-shot diff pass); if any of them iterate over multiple files or phases in practice, reclassify to `yes`. Code Review Full (#13) is `yes` because it orchestrates the three as subagents.
* Only 9 agents declare a `model:` field (all are subagents in the RPI and security/reviewer pipelines); every other agent leaves model to the host. Rows show "(none)" where no model is declared rather than guessing.

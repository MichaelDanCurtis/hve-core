# Project Planning

Create architecture decision records, requirements documents, and diagrams - all through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and conduct STRIDE-based security model analysis with automated backlog generation. Includes Jira backlog management workflows for discovery, triage, PRD-to-issue conversion, and execution.

## Channel distribution

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json` entry) ship the PreRelease description text only. The `.vsix` extension package ships either Stable or PreRelease text depending on which channel was packaged. `descriptions.prerelease` is required for any collection that ships a plugin.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name | Description |
|------|-------------|
| **implementation-validator** | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings |
| **jira-backlog-manager** | Orchestrator agent for Jira backlog management workflows including discovery, triage, execution, and single-issue actions |
| **jira-prd-to-wit** | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira |
| **phase-implementor** | Executes a single implementation phase from a plan with full codebase access and change tracking |
| **plan-validator** | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings |
| **researcher-subagent** | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools |
| **rpi-agent** | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them |
| **rpi-validator** | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase |

### Prompts

| Name | Description |
|------|-------------|
| **jira-discover-issues** | Discover Jira issues through user-centric queries, artifact-driven analysis, or JQL-based exploration and produce planning files for review |
| **jira-execute-backlog** | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file |
| **jira-prd-to-wit** | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira |
| **jira-triage-issues** | Triage Jira issues with bounded JQL, field recommendations, duplicate detection, and optional execution of confirmed updates |

### Instructions

| Name | Description |
|------|-------------|
| **jira/jira-backlog-discovery** | Discovery protocol for Jira backlog management with user-centric, artifact-driven, and JQL-based issue discovery |
| **jira/jira-backlog-planning** | Reference specification for Jira backlog management tooling, planning files, search conventions, similarity assessment, and state persistence |
| **jira/jira-backlog-triage** | Triage workflow for Jira backlog management with field recommendations, duplicate detection, and controlled execution |
| **jira/jira-backlog-update** | Execution workflow for Jira backlog management that consumes planning handoffs and applies sequential Jira operations |
| **jira/jira-wit-planning** | Reference specification for Jira PRD work item planning files, hierarchy mapping, field validation, and handoff contracts |
| **shared/disclaimer-language** | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment |
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/story-quality** | Shared story quality conventions for work item creation and evaluation across agents and workflows |

### Skills

| Name | Description |
|------|-------------|
| **gitlab** | Manage GitLab merge requests and pipelines with a Python CLI |
| **jira** | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. |

<!-- END AUTO-GENERATED ARTIFACTS -->

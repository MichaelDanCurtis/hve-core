# HVE Core Workflow

HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

## Channel distribution

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json` entry) ship the PreRelease description text only. The `.vsix` extension package ships either Stable or PreRelease text depending on which channel was packaged. `descriptions.prerelease` is required for any collection that ships a plugin.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name | Description |
|------|-------------|
| **implementation-validator** | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings |
| **memory** | Conversation memory persistence for session continuity |
| **phase-implementor** | Executes a single implementation phase from a plan with full codebase access and change tracking |
| **plan-validator** | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings |
| **prompt-builder** | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files |
| **prompt-evaluator** | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance |
| **prompt-tester** | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value |
| **prompt-updater** | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research |
| **researcher-subagent** | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools |
| **rpi-agent** | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them |
| **rpi-validator** | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase |
| **task-implementor** | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records |
| **task-planner** | Implementation planner for creating actionable implementation plans |
| **task-researcher** | Task research specialist for comprehensive project analysis |
| **task-reviewer** | Reviews completed implementation work for accuracy, completeness, and convention compliance |

### Instructions

| Name | Description |
|------|-------------|
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name | Description |
|------|-------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

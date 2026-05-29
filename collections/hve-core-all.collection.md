# HVE Core All

HVE Core provides the complete collection of AI chat agents, prompts, instructions, and skills for VS Code with GitHub Copilot. This edition includes every artifact across all domains: development workflows, architecture, Azure DevOps, GitHub and Jira backlog workflows, data science, design thinking, security, and more.

Use this edition when you want access to everything without choosing a focused collection.

> [!CAUTION]
> This collection includes security, responsible AI, and supply chain security agents and prompts that are **assistive tools only**.
> They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review.
> All AI-generated security and compliance artifacts **must** be reviewed and validated by qualified professionals before use.
> AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Channel distribution

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json` entry) ship the PreRelease description text only. The `.vsix` extension package ships either Stable or PreRelease text depending on which channel was packaged. `descriptions.prerelease` is required for any collection that ships a plugin.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name | Description |
|------|-------------|
| **ado-backlog-manager** | Orchestrator agent for Azure DevOps backlog management workflows including triage, discovery, sprint planning, PRD-to-work-item conversion, and execution |
| **ado-prd-to-wit** | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies |
| **codebase-profiler** | Scans the repository to build a technology profile and identify which security skills apply to the codebase |
| **dt-coach** | Design Thinking coach guiding teams through the 9-method HVE framework with Think/Speak/Empower philosophy |
| **dt-learning-tutor** | Design Thinking learning tutor providing structured curriculum, comprehension checks, and adaptive pacing |
| **experiment-designer** | Conversational coach that guides users through designing a Minimum Viable Experiment (MVE) with structured hypothesis formation, vetting, and experiment planning |
| **finding-deep-verifier** | Deep adversarial verification of FAIL and PARTIAL findings for a single security skill |
| **github-backlog-manager** | Orchestrator agent for GitHub backlog management workflows including triage, discovery, sprint planning, and execution |
| **implementation-validator** | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings |
| **jira-backlog-manager** | Orchestrator agent for Jira backlog management workflows including discovery, triage, execution, and single-issue actions |
| **jira-prd-to-wit** | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira |
| **memory** | Conversation memory persistence for session continuity |
| **phase-implementor** | Executes a single implementation phase from a plan with full codebase access and change tracking |
| **plan-validator** | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings |
| **pptx** | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx |
| **pptx-subagent** | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation |
| **prompt-builder** | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files |
| **prompt-evaluator** | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance |
| **prompt-tester** | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value |
| **prompt-updater** | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research |
| **report-generator** | Collates verified security skill assessment findings and generates a comprehensive vulnerability report written to .copilot-tracking/security/ |
| **researcher-subagent** | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools |
| **rpi-agent** | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them |
| **rpi-validator** | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase |
| **skill-assessor** | Assesses a single security knowledge skill against the codebase, reading vulnerability references and returning structured findings |
| **task-implementor** | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records |
| **task-planner** | Implementation planner for creating actionable implementation plans |
| **task-researcher** | Task research specialist for comprehensive project analysis |
| **task-reviewer** | Reviews completed implementation work for accuracy, completeness, and convention compliance |

### Prompts

| Name | Description |
|------|-------------|
| **ado-add-work-item** | Create a single Azure DevOps work item with conversational field collection and parent validation |
| **ado-create-pull-request** | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages. |
| **ado-discover-work-items** | Discover Azure DevOps work items through user-centric queries, artifact-driven analysis, or search-based exploration |
| **ado-get-build-info** | Retrieve Azure DevOps build information for a Pull Request or specific Build Number. |
| **ado-get-my-work-items** | Retrieve user's current Azure DevOps work items and organize them into planning file definitions |
| **ado-process-my-work-items-for-task-planning** | Process retrieved work items for task planning and generate task-planning-logs.md handoff file |
| **ado-sprint-plan** | Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps |
| **ado-triage-work-items** | Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado-update-wit-items** | Prompt to update work items based on planning files |
| **cspell-config** | Creates or updates the project cspell configuration with project-specific words and ignores |
| **dt-canonical-deck** | Unified canonical deck workflow for opt-in offer, snapshot generation/refresh, and optional customer-card PowerPoint build |
| **dt-figma-export** | Export Design Thinking artifacts to a collaborative FigJam board or Figma Design file using the official Figma MCP server |
| **dt-handoff-implementation-space** | Compiles DT Methods 7-9 outputs into an RPI-ready handoff artifact targeting Task Researcher |
| **dt-handoff-problem-space** | Problem Space exit handoff - compiles DT Methods 1-3 outputs into an RPI-ready artifact targeting Task Researcher |
| **dt-handoff-solution-space** | Solution Space exit handoff - compiles DT Methods 4-6 outputs into an RPI-ready artifact targeting Task Researcher |
| **dt-method-04-convergence** | Theme discovery for Design Thinking Method 4c through philosophy-based clustering |
| **dt-method-04-ideation** | Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation |
| **dt-method-05-concepts** | Concept articulation for Design Thinking Method 5b from brainstorming themes |
| **dt-method-05-evaluation** | Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c |
| **dt-method-06-building** | Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b |
| **dt-method-06-planning** | Concept analysis and prototype approach design for Design Thinking Method 6a |
| **dt-method-06-testing** | Hypothesis-driven testing and constraint validation for Design Thinking Method 6c |
| **dt-method-next** | Assess DT project state and recommend next method with sequencing validation |
| **dt-resume-coaching** | Resume a Design Thinking coaching session - reads coaching state and re-establishes context |
| **dt-start-project** | Start a new Design Thinking coaching project with state initialization and first coaching interaction |
| **github-add-issue** | Create a GitHub issue using discovered repository templates and conversational field collection |
| **github-discover-issues** | Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review |
| **github-execute-backlog** | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file |
| **github-sprint-plan** | Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog |
| **github-suggest** | Resume GitHub backlog management workflow after session restore |
| **github-triage-issues** | Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection |
| **jira-discover-issues** | Discover Jira issues through user-centric queries, artifact-driven analysis, or JQL-based exploration and produce planning files for review |
| **jira-execute-backlog** | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file |
| **jira-prd-to-wit** | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira |
| **jira-triage-issues** | Triage Jira issues with bounded JQL, field recommendations, duplicate detection, and optional execution of confirmed updates |

### Instructions

| Name | Description |
|------|-------------|
| **ado/ado-backlog-sprint** | Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection |
| **ado/ado-backlog-triage** | Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado/ado-create-pull-request** | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking. |
| **ado/ado-get-build-info** | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name. |
| **ado/ado-interaction-templates** | Work item description and comment templates for consistent Azure DevOps content formatting |
| **ado/ado-update-wit-items** | Work item creation and update protocol using MCP ADO tools with handoff tracking |
| **ado/ado-wit-discovery** | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output |
| **ado/ado-wit-planning** | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols |
| **design-thinking/dt-canonical-deck** | Opt-in canonical deck and customer-card workflow for DT coaching |
| **design-thinking/dt-coaching-identity** | Required instructions when working with or doing any Design Thinking (DT); Contains instructions for the Design Thinking coach identity, philosophy, and user interaction and communication requirements for consistent coaching behavior. |
| **design-thinking/dt-coaching-state** | Coaching state schema for Design Thinking session persistence, method progress tracking, and session recovery |
| **design-thinking/dt-curriculum-01-scoping** | DT Curriculum Module 1: Scope Conversations - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-02-research** | DT Curriculum Module 2: Design Research - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-03-synthesis** | DT Curriculum Module 3: Synthesis - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-04-brainstorming** | DT Curriculum Module 4: Brainstorming - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-05-concepts** | DT Curriculum Module 5: User Concepts - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-06-prototypes** | DT Curriculum Module 6: Low-Fidelity Prototypes - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-07-testing** | DT Curriculum Module 7: High-Fidelity Prototypes - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-08-iteration** | DT Curriculum Module 8: User Testing - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-09-handoff** | DT Curriculum Module 9: Iteration at Scale - concepts, techniques, checks, and exercises |
| **design-thinking/dt-curriculum-scenario-manufacturing** | Manufacturing reference scenario for DT learning - factory floor improvement project used across all 9 curriculum modules |
| **design-thinking/dt-image-prompt-generation** | M365 Copilot image prompt generation techniques for Design Thinking Method 5 concept visualization with lo-fi enforcement |
| **design-thinking/dt-industry-energy** | Energy industry context for DT coaching - vocabulary, constraints, empathy tools, and reference scenarios |
| **design-thinking/dt-industry-healthcare** | Healthcare industry context for DT coaching - vocabulary, constraints, empathy tools, and reference scenarios |
| **design-thinking/dt-industry-manufacturing** | Manufacturing industry context for DT coaching - vocabulary, constraints, empathy tools, and reference scenarios |
| **design-thinking/dt-method-01-deep** | Deep expertise for Method 1: Scope Conversations, covering advanced stakeholder analysis, power dynamics, and scope negotiation |
| **design-thinking/dt-method-01-scope** | Method 1 Scope Conversations coaching knowledge for Design Thinking: frozen vs fluid assessment, stakeholder discovery, constraint patterns, and conversation navigation |
| **design-thinking/dt-method-02-deep** | Deep expertise for Method 2: Design Research, covering advanced interview techniques, ethnographic observation, and evidence triangulation |
| **design-thinking/dt-method-02-research** | Method 2 Design Research coaching knowledge: interview techniques, research planning, environmental observation, and insight extraction patterns |
| **design-thinking/dt-method-03-deep** | Deep expertise for Method 3: Input Synthesis - advanced affinity analysis, insight frameworks, and problem statement articulation |
| **design-thinking/dt-method-03-synthesis** | Method 3 Input Synthesis coaching knowledge: pattern recognition, theme development, synthesis validation, and Problem-to-Solution Space transition readiness |
| **design-thinking/dt-method-04-brainstorming** | Design Thinking Method 4: AI-assisted brainstorming with divergent ideation and convergent clustering for solution space entry |
| **design-thinking/dt-method-04-deep** | Deep expertise for Method 4: Brainstorming - advanced facilitation techniques, creative block recovery, and convergence frameworks |
| **design-thinking/dt-method-05-concepts** | Design Thinking Method 5: User Concepts coaching with concept articulation, three-lens evaluation, and stakeholder alignment for Solution Space development |
| **design-thinking/dt-method-05-deep** | Deep expertise for Method 5: User Concepts, covering advanced D/F/V analysis, image prompt crafting, concept stress-testing, and portfolio management |
| **design-thinking/dt-method-06-deep** | Deep expertise for Method 6: Low-Fidelity Prototypes; advanced paper prototyping, service blueprinting, and experience prototyping |
| **design-thinking/dt-method-06-lofi-prototypes** | Design Thinking Method 6: Lo-fi prototyping techniques, scrappy enforcement, feedback planning, and constraint discovery for Solution Space exit |
| **design-thinking/dt-method-07-deep** | Deep expertise for Method 7: High-Fidelity Prototypes; fidelity translation, architecture, and specification writing |
| **design-thinking/dt-method-07-hifi-prototypes** | Design Thinking Method 7: High-Fidelity Prototypes; technical translation, functional prototypes, and specifications |
| **design-thinking/dt-method-08-deep** | Deep expertise for Method 8: Test and Validate - advanced test design, small-sample analysis, iteration triggers, and bias mitigation |
| **design-thinking/dt-method-08-testing** | Design Thinking Method 8: User Testing - evidence-based evaluation, test protocols, and non-linear iteration support |
| **design-thinking/dt-method-09-deep** | Deep expertise for Method 9: Iteration at Scale - change management, scaling, and adoption measurement |
| **design-thinking/dt-method-09-iteration** | Design Thinking Method 9: Iteration at Scale - systematic refinement, scaling patterns, and organizational deployment |
| **design-thinking/dt-method-sequencing** | Method transition rules, nine-method sequence, space boundaries, and non-linear iteration support for Design Thinking coaching |
| **design-thinking/dt-quality-constraints** | Quality constraints, fidelity rules, and output standards for Design Thinking coaching across all nine methods |
| **design-thinking/dt-rpi-handoff-contract** | DT-to-RPI handoff contract defining exit points, artifact schemas, and per-agent input requirements for lateral transitions from Design Thinking to RPI workflow |
| **design-thinking/dt-rpi-implement-context** | DT-aware Task Implementor context: fidelity constraints, stakeholder validation, and iteration support |
| **design-thinking/dt-rpi-planning-context** | DT-aware Task Planner context: fidelity constraints, iteration support, and confidence-informed planning for DT artifacts |
| **design-thinking/dt-rpi-research-context** | DT-aware Task Researcher context: frames research around DT methods, stakeholder needs, and empathy-driven inquiry |
| **design-thinking/dt-rpi-review-context** | DT-aware Task Reviewer context: quality criteria for Design Thinking artifacts |
| **design-thinking/dt-subagent-handoff** | DT subagent handoff workflow: readiness assessment, artifact compilation, and handoff validation via subagent dispatch |
| **experimental/experiment-designer** | MVE domain knowledge and coaching conventions for the Experiment Designer agent |
| **experimental/pptx** | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill |
| **github/community-interaction** | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts |
| **github/github-backlog-discovery** | Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery |
| **github/github-backlog-planning** | Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence |
| **github/github-backlog-triage** | Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection |
| **github/github-backlog-update** | Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations |
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
| **customer-card-render** | Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline |
| **gh-code-scanning** | Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI |
| **gitlab** | Manage GitLab merge requests and pipelines with a Python CLI |
| **hve-core-installer** | Decision-driven installer for HVE-Core with 6 clone-based installation methods, extension quick-install, environment detection, and agent customization workflows |
| **jira** | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. |
| **powerpoint** | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling |
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **tts-voiceover** | Text-to-speech voice-over generation from YAML speaker notes using Azure Speech SDK with SSML pronunciation control |
| **video-to-gif** | Video-to-GIF conversion skill with FFmpeg two-pass optimization |
| **vscode-playwright** | VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation |

<!-- END AUTO-GENERATED ARTIFACTS -->

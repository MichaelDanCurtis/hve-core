# Security

Security review, planning, incident response, risk assessment, vulnerability analysis, supply chain security, and responsible AI assessment for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Channel distribution

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json` entry) ship the PreRelease description text only. The `.vsix` extension package ships either Stable or PreRelease text depending on which channel was packaged. `descriptions.prerelease` is required for any collection that ships a plugin.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name | Description |
|------|-------------|
| **codebase-profiler** | Scans the repository to build a technology profile and identify which security skills apply to the codebase |
| **finding-deep-verifier** | Deep adversarial verification of FAIL and PARTIAL findings for a single security skill |
| **report-generator** | Collates verified security skill assessment findings and generates a comprehensive vulnerability report written to .copilot-tracking/security/ |
| **researcher-subagent** | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools |
| **skill-assessor** | Assesses a single security knowledge skill against the codebase, reading vulnerability references and returning structured findings |

### Instructions

| Name | Description |
|------|-------------|
| **shared/disclaimer-language** | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment |
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name | Description |
|------|-------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

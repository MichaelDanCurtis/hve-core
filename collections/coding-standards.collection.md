# Coding Standards

Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns, plus agents that review branch diffs before opening pull requests.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Description                                                                 |
|-------------------------|-----------------------------------------------------------------------------|
| **researcher-subagent** | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools |

### Instructions

| Name                                       | Description                                                                                                                                                                                                                                                 |
|--------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/bash/bash**             | Bash script authoring conventions                                                                                                                                                                                                                           |
| **coding-standards/bicep/bicep**           | Bicep infrastructure-as-code authoring conventions                                                                                                                                                                                                          |
| **coding-standards/csharp/csharp**         | C# (CSharp) code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/csharp/csharp-tests**   | C# (CSharp) test code authoring conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/pester**     | Instructions for Pester testing conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/powershell** | PowerShell scripting conventions                                                                                                                                                                                                                            |
| **coding-standards/python-script**         | Python scripting conventions                                                                                                                                                                                                                                |
| **coding-standards/python-tests**          | Python test code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/rust/rust**             | Rust code authoring conventions                                                                                                                                                                                                                             |
| **coding-standards/rust/rust-tests**       | Rust test code authoring conventions                                                                                                                                                                                                                        |
| **coding-standards/terraform/terraform**   | Terraform infrastructure-as-code authoring conventions                                                                                                                                                                                                      |
| **coding-standards/uv-projects**           | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| **shared/hve-core-location**               | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**               | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference**          | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **telemetry-foundations** | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |

<!-- END AUTO-GENERATED ARTIFACTS -->

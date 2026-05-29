# Coding Standards

Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns, plus agents that review branch diffs before opening pull requests.

## Channel distribution

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json` entry) ship the PreRelease description text only. The `.vsix` extension package ships either Stable or PreRelease text depending on which channel was packaged. `descriptions.prerelease` is required for any collection that ships a plugin.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Instructions

| Name | Description |
|------|-------------|
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name | Description |
|------|-------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

---
title: Collection Scripts
description: PowerShell tooling for validating the canonical collection manifest and generated collection outputs
---

PowerShell tooling for validating `collections/core-manifest.yml`, generating
collection package manifests, and sharing collection helpers used by validation
and plugin generation.

## Scripts

| Script                           | npm Command                         | Description                                                  |
|----------------------------------|-------------------------------------|--------------------------------------------------------------|
| Validate-CoreManifest.ps1        | `npm run lint:collections-metadata` | Validate the canonical collection manifest source            |
| Validate-Collections.ps1         | `npm run lint:collections-metadata` | Validate generated collection manifests                      |
| Modules/CoreManifestHelpers.psm1 | (library)                           | Core manifest parsing, normalization, and generation helpers |
| Modules/CollectionHelpers.psm1   | (library)                           | YAML parsing, frontmatter, and collection helpers            |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)

## Adding a New Collection

1. Add the collection metadata to `collections/core-manifest.yml` under
   `collections:`. Include the generated manifest path, display name,
   description, tags, and item count.
2. Assign artifacts to the collection in the canonical artifact maps such as
   `agents:`, `prompts:`, `instructions:`, and `skills:`.
3. Run `npm run lint:collections-metadata` to check the core manifest and
   generated manifests.
4. Run `npm run plugin:generate` to generate collection and plugin outputs.
5. Commit the core manifest changes and the generated outputs required by the
   repository workflow.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->

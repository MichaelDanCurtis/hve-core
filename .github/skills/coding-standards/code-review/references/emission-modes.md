---
title: Code Review Emission Modes
description: Capability-gated emission modes and the persisted emission record contract.
ms.date: 2026-06-20
---

## Purpose

The review should emit results in the most capable native format available. When a direct poster is unavailable, fall back to the canonical findings report so the review still completes and persists its value.

## Emission modes

1. Native PR or MR comments
   - Use line comments or review comments when a capable poster is detected.
   - Prefer GitLab `mr-comment` support when that capability is present.
   - Use Azure DevOps templates when the repository context supports ADO comment formatting.
   - Use GitHub review comments when a GitHub poster is available.

2. Canonical findings report
   - Use the canonical report when no native poster is available.
   - Persist the report to the review folder and summarize the result in the conversation.

## Gating rules

- Detect the available poster capability before emission.
- Only emit in a native format when the target and capability are both available.
- Keep the review output deterministic by preferring one mode over another based on the detected environment.

## Emission record

Persist an emission record with the chosen mode, target, status, and a short summary of what was emitted. A lightweight record should include:

- `mode` — native or canonical,
- `target` — PR, MR, ADO, or review artifact,
- `status` — completed or skipped,
- `summary` — a brief description of the emission outcome.

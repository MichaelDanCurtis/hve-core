---
title: Code Review Cross-Skill Forks
description: Cross-skill fork catalog and collection-aware gating for board-item extensions.
ms.date: 2026-06-20
---

## Purpose

Some review board items warrant a specialist follow-up. The review loop should surface those forks only when the required collection or capability is available in the current environment.

## Fork catalog

| Board item area | Suggested extension | Gating signal |
| --- | --- | --- |
| Authentication, authorization, secrets, or trust boundaries | Security review skill or security collection | Security capability available |
| Keyboard, focus, semantics, or assistive-technology concerns | Accessibility skill or accessibility collection | Accessibility capability available |
| GitLab-specific review comments or MR workflows | GitLab skill | GitLab poster capability available |
| Azure DevOps-specific review comments or work item linking | ADO instructions and templates | ADO review context available |
| Repository workflow or PR hygiene concerns | GitHub or GitLab review capability | Matching repository capability available |

## Gating behavior

- Detect the available collection, skill, or capability before surfacing a fork.
- Keep the main review flow intact when no specialist fork is available.
- Present the fork as an optional extension to the current board item rather than as a mandatory extra lane.

## Selection rule

Cross-skill forks should only be offered when they add clear review value. If a fork is unavailable, the board item should remain reviewable through the core code-review workflow.

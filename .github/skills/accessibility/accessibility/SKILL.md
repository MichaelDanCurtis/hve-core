---
name: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, and the Accessibility Planner playbook."
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-17"
---

# Accessibility — Skill Entry

This skill is the canonical accessibility reference contract for HVE Core. Agents and instructions invoke this skill by name and rely on it to own framework reference resolution, phase guidance resolution, and the scanner CLI entrypoint.

## Framework references

* [WCAG 2.2](references/frameworks/wcag-22.md)
* [ARIA Authoring Practices Guide](references/frameworks/aria-apg.md)
* [Cognitive Accessibility Guidance](references/frameworks/coga.md)
* [Section 508](references/frameworks/section-508.md)
* [EN 301 549](references/frameworks/en-301-549.md)

## Phase references

* [Capture and exploration](references/phases/capture-coaching.md)
* [Framework selection](references/phases/framework-selection.md)
* [Impact assessment](references/phases/impact-assessment.md)
* [Review and backlog handoff](references/phases/backlog-handoff.md)

## Tooling

* Scanner CLI entrypoint: [scripts/scan.py](scripts/scan.py)

## Usage notes

* Treat this skill as the default accessibility entrypoint for planning and review workflows.
* Resolve framework and phase guidance through this skill instead of duplicating its internal reference paths in agents or instructions.
* Use the scanner CLI when you need normalized findings from an accessibility scan.

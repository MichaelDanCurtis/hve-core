---
name: brd-author
description: 'BRD authoring operating guide for Discover, Define, and Govern phases with hard exit gates and artifact contracts - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-05-08"
---

# BRD Author Skill

## Overview

This skill defines how to produce and evolve a Business Requirements Document (BRD) across the project lifecycle. It provides a phase-based operating contract with explicit hard exit gates, artifact outputs, status semantics, and lineage rules.

Use this skill with:

* [Requirements Definition](references/requirements-definition.md)
* [Traceability Naming](references/traceability-naming.md)
* [BRD Quality Formats](references/brd-quality-formats.md)

## Lifecycle

| Phase    | Primary objective                                                    | Entry condition                                  | Exit condition                                                 |
|----------|----------------------------------------------------------------------|--------------------------------------------------|----------------------------------------------------------------|
| Discover | Establish business context, stakeholder scope, and problem framing   | Request or initiative is in intake               | Discover hard gate passes and artifacts are complete           |
| Define   | Produce complete, testable, and traceable requirements content       | Discover artifacts are approved for elaboration  | Define hard gate passes with quality evidence                  |
| Govern   | Finalize, approve, and supersede BRD versions under lineage controls | Define package is approved for governance review | Govern hard gate passes and publication artifacts are recorded |

## Discover {#discover}

### Activities

* Capture business context, drivers, constraints, and expected outcomes.
* Identify stakeholders, decision owners, and review participants.
* Define scope boundaries, assumptions, and dependency surfaces.
* Draft initial requirement candidates and map early traceability placeholders.

### Hard exit gate

Discover exits only when:

* Scope is bounded and stakeholder ownership is explicit.
* Core assumptions and constraints are documented and reviewable.
* Seed artifacts needed for Define are present and internally consistent.

### Output artifacts

* Discover summary and scope statement.
* Stakeholder inventory with role and ownership mapping.
* Initial assumption and constraint register.
* Seed requirement and traceability scaffold for Define.

## Define {#define}

### Activities

* Author full BRD content using canonical templates and naming rules.
* Refine business goals and requirement sets with clear acceptance intent.
* Build and verify traceability links across requirements and acceptance criteria.
* Perform quality assessment using the BRD quality reporting contract.

### Hard exit gate

Define exits only when:

* Requirement content is complete, unambiguous, and testable.
* Traceability links satisfy the active ID schema and naming policy.
* Quality findings are generated and reviewed against the defined rubric.

### Output artifacts

* Full BRD draft package with structured sections.
* Traceability matrix aligned to naming and ID conventions.
* BRD quality findings and consolidated quality report payloads.
* Define gate decision record with reviewer notes.

## Govern {#govern}

### Activities

* Prepare final BRD for approval with version metadata and lineage fields.
* Resolve or disposition remaining quality findings.
* Publish approved BRD outputs and downstream handoff payloads.
* Maintain supersession chain when issuing replacement BRD versions.

### Hard exit gate

Govern exits only when:

* Approval status and required reviewers are recorded.
* Version and lineage metadata are valid and complete.
* Handoff artifacts are published for downstream consumers.

### Output artifacts

* Approved BRD release artifact.
* BRD-to-PRD handoff payload.
* Governance decision log with approval evidence.
* Supersession linkage record for replaced BRD versions.

## Status taxonomy

Use the following status values for BRD lifecycle tracking:

* `draft`: Actively authored or revised.
* `in-review`: Under formal review and gate validation.
* `approved`: Accepted for governed use.
* `superseded`: Replaced by a newer approved BRD.

## Quality rubric pointer

Apply the BRD quality rubric and payload contracts from [BRD Quality Formats](references/brd-quality-formats.md) together with requirement-definition guidance in [Requirements Definition](references/requirements-definition.md#quality-dimensions-and-rubrics). Treat rubric results as gate evidence for Define and Govern decisions.

## Supersession lineage rules

* A BRD can supersede one or more earlier BRDs when scope is merged.
* A BRD can be superseded by only one approved successor version.
* Every supersession event records `supersedes` and `superseded_by` links.
* Supersession does not delete historical artifacts; it preserves auditability.

## References

The skill bundles the following reference documents under `references/`. Load a section body only when its phase activity requires it; each body links to its own sub-references (standards pointers, scoring sheets, and worked examples).

Domain section bodies:

* [requirements-definition.md](references/requirements-definition.md) - Requirement categories (FR / AC / NFR / CON / BR), canonical statement form, acceptance-criteria formats, and the three Define-phase quality dimensions.
* [stakeholder-analysis.md](references/stakeholder-analysis.md) - Mendelow Power/Interest grid, RACI accountability variants, and the BABOK cite-only pointer.
* [process-modeling.md](references/process-modeling.md) - BPMN / DMN / UML notation selection and the Mermaid-first diagram format selector.
* [prioritization-schemes.md](references/prioritization-schemes.md) - MoSCoW / RICE / WSJF / Kano selector and how-to-choose guidance.
* [traceability-naming.md](references/traceability-naming.md) - Five-tier identifier schema (FR / AC / NFR / CON / BR) and traceability matrix conventions.
* [brd-quality-formats.md](references/brd-quality-formats.md) - Producer and consumer map for the three versioned data contracts.

Rubrics and standards:

* [quality-rubric.md](references/quality-rubric.md) - Operational status taxonomy (`RISK` / `CAUTION` / `COVERED` / `NOT_APPLICABLE`) and the Define → Govern gate decision rule.
* [requirements-quality-rubric.md](references/requirements-quality-rubric.md) - Combined per-requirement, per-NFR-category, and per-business-goal scoring sheets the assessor emits.
* [handoff-payload-schema.md](references/handoff-payload-schema.md) - BRD-author view of the BRD-to-PRD handoff payload.
* [standards-excerpts.md](references/standards-excerpts.md) - Cite-only registry of third-party standards (ISO, IIBA, PMI, ISTQB) referenced by name.

## Templates

Templates under `templates/` are selected by the BRD frontmatter overlay's `diagram_format` field and the canonical BRD shape.

* [brd-full.md](templates/brd-full.md) - Master BRD template covering every section from Executive Summary through Sign-Off.
* [brd-frontmatter-overlay.md](templates/brd-frontmatter-overlay.md) - Schema for BRD YAML frontmatter, including `diagram_format`, lineage, and requirement-prefix overrides.
* [diagram-mermaid.md](templates/diagram-mermaid.md) - Mermaid flowchart fragment; the default diagram format.
* [diagram-ascii.md](templates/diagram-ascii.md) - ASCII process-diagram fragment for low-fidelity Discover-phase sketches.
* [diagram-figma.md](templates/diagram-figma.md) - Figma low-fidelity prototype fragment.

## Data Contracts

Three versioned payload contracts govern BRD quality assessment and downstream handoff. Each `schema_version` is a fixed identifier; consumers fail fast on any other value, so the constants MUST NOT change.

| Contract           | `schema_version`           | Reference                                                             |
|--------------------|----------------------------|-----------------------------------------------------------------------|
| Standard findings  | `BRD_STANDARD_FINDINGS_V1` | [brd-standard-findings-v1.md](references/brd-standard-findings-v1.md) |
| Quality report     | `BRD_QUALITY_REPORT_V1`    | [brd-quality-report-v1.md](references/brd-quality-report-v1.md)       |
| BRD-to-PRD handoff | `BRD_TO_PRD_HANDOFF_V1`    | [brd-to-prd-handoff-v1.md](references/brd-to-prd-handoff-v1.md)       |

## Mandatory Load Directives

The BRD Builder agent enforces a phase → section load contract. Each phase MUST load its section of this skill before executing phase work, and MUST append the section anchor to `state.phaseSkillsLoaded`:

| Phase    | Section anchor | Required `phaseSkillsLoaded` entry |
|----------|----------------|------------------------------------|
| Discover | `#discover`    | `brd-author#discover`              |
| Define   | `#define`      | `brd-author#define`                |
| Govern   | `#govern`      | `brd-author#govern`                |

The agent loads sections via `read_file` against this skill file and records the entry in `state.phaseSkillsLoaded` before any phase work executes. Re-entering a previously loaded phase does not require reloading; the agent checks `phaseSkillsLoaded` first.

## Source Attribution

The bundled reference bodies cite third-party standards and frameworks by name and clause only; no upstream prose is redistributed, and paraphrased summaries are original Microsoft content under CC BY 4.0. The cite-only registry in [standards-excerpts.md](references/standards-excerpts.md) is the single place new citations are added. Standards referenced by name include ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, IIBA BABOK v3, PMI Business Analysis for Practitioners, the ISTQB Glossary, OMG BPMN / DMN / UML, the Cucumber Gherkin pattern (BSD 3-Clause), and the MoSCoW / RICE / WSJF / Kano prioritization schemes, each the property of its respective rights holder.

## License

This skill is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.

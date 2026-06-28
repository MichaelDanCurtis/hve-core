<!-- markdownlint-disable MD013 -->
# Fluent and motion polish design

## Purpose

This is the "make it great" capstone from the roadmap's Next horizon: a polished Fluent design language, motion that makes state changes feel alive, and a calmer glanceable presence. Accessibility and responsive layout are already done in the hardening pass, so this pass is about depth, material, and motion on top of the look the cockpit already has.

The cockpit's current styling is editor-native (VS Code dark and light), which is already Fluent-adjacent: it uses Segoe UI Variable, rounded corners, an accent color, and elevation tokens. This pass refines that into a deliberate Fluent expression. It is an enhancement, not a rebuild: the information architecture, the layout, and the color identity stay exactly as they are.

## Principles

| Principle | What it means here |
| --- | --- |
| Depth and elevation | Surfaces sit at deliberate elevation levels. Chrome (top bar, rails, modal, app-frame header) reads as a layer above the content, with refined shadows and an optional subtle acrylic material. |
| Material | A restrained acrylic (a small backdrop blur plus slight translucency) on the chrome layers, behind an `@supports` guard with a solid fallback, so it degrades cleanly where `backdrop-filter` is unavailable. |
| Purposeful motion | Motion is fast, physics-eased, and tied to meaning: things that appear animate in, things you touch respond, state changes are felt. Motion never loops gratuitously and never blocks reading. |
| Calm at rest | When nothing is changing, the cockpit is still. Animation is on transitions, not on the resting state. |
| Respect the user | All motion is gated by `prefers-reduced-motion`, and the editor-native color identity and contrast (already WCAG-checked) are preserved. |

## Motion tokens

Define easing and duration tokens so motion is consistent and tunable in one place.

| Token | Value | Use |
| --- | --- | --- |
| `--ease-standard` | `cubic-bezier(0.33, 0, 0.1, 1)` | The default Fluent decelerate ease for most transitions |
| `--ease-entrance` | `cubic-bezier(0.1, 0.9, 0.2, 1)` | Entrance of a discrete element |
| `--dur-fast` | `120ms` | Hover and small state changes |
| `--dur-normal` | `200ms` | Most transitions and entrances |
| `--dur-slow` | `320ms` | Larger surfaces (overlay, side panel) |

## Motion inventory

The key constraint: the client paints most lists by replacing `innerHTML` on every state push, so an entrance keyframe on a frequently re-rendered list item (findings, board cards, subagents, steps, log) would replay on every unrelated update and flicker. So entrance animations are reserved for elements that appear and disappear at discrete moments, and the rest gets transitions that do not depend on surviving a re-render.

| Element | Motion | Why it is flicker-safe |
| --- | --- | --- |
| Navigator overlay (`#welcome`) | Backdrop fade in, modal scale-and-fade in (`--dur-slow`, `--ease-entrance`) | Shown and hidden at discrete moments via the hidden attribute; display change restarts the animation |
| Decision card (`#decision .decide`) | Slide-and-fade in (`--dur-normal`) | Appears when a decision arrives; subtle and fast so the occasional re-render replay is not jarring |
| App-frame panel (`#app-frame`) | Slide in from the side (`--dur-slow`) | Shown and hidden at discrete moments |
| Screen pane (`#screen`) | Fade in (`--dur-normal`) | Shown and hidden at discrete moments |
| Chrome (top bar, rails) | Acrylic material and elevation, static | Persistent, no entrance animation |
| Interactive elements (tiles, buttons, the crumb, chips) | Hover elevation and `:focus-visible` already present; add a fast transform and shadow transition on hover (`--dur-fast`) | Hover state, not a re-render |
| The running dot and the live connection pill | The existing pulse keeps signalling liveness | Already present |

Entrance animations are explicitly NOT added to `.finding`, `.bcard`, `.sub-card`, `.step`, the context chips, or the log stream, because those re-render frequently. Their liveness comes from the surrounding chrome and the discrete-element motion above.

## Reduced motion

A `@media (prefers-reduced-motion: reduce)` block neutralizes animation and transition durations globally (the standard near-zero-duration reset), so the cockpit is fully usable and calm for users who ask for less motion. This is mandatory, not optional.

## Scope

In scope:

* Motion tokens (easing and duration) in the theme variables.
* Fluent depth: refined elevation shadows and an optional subtle acrylic material on the chrome layers, behind an `@supports (backdrop-filter)` guard with a solid fallback.
* The discrete-element entrance animations and hover transitions in the motion inventory.
* A `prefers-reduced-motion: reduce` reset.
* Verification across every view, both themes, reduced motion, and narrow widths.

Out of scope:

* Any change to the information architecture, layout, or the navigation model.
* Any change to the color identity or to contrast already validated for WCAG.
* Entrance animations on frequently re-rendered list content (would flicker).
* A wholesale visual restyle or a switch to a different design language.

## Non-goals

* Motion for its own sake. Every animation here is tied to an appearance, a hover, or a state change.
* Replacing the editor-native aesthetic. This deepens it into Fluent; it does not abandon it.

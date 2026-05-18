---
name: responsive-adaptive-layout
description: App breaks (RenderFlex overflow, clipped/cut UI, unreadable cramped layout) on small/large phones, tablets, foldables, split-screen, OR when the OS font size / display size is increased. Use for ANY screen or design-system component, and to set the root text-scale clamp + responsive breakpoints. Best practice = Material 3 window size classes + MediaQuery.sizeOf/LayoutBuilder + clamped MediaQuery.textScaler + size×textScale golden matrix.
triggers: [responsive, adaptive layout, RenderFlex overflow, overflowed by pixels, screen size, small phone, tablet, foldable, split screen, MediaQuery.sizeOf, LayoutBuilder, breakpoint, window size class, text scale, textScaler, font size accessibility, dynamic type, large font, A overflowed, bottom overflowed]
platforms: [ios, android]
last_verified: 2026-05-17
flutter_min: "3.22.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Responsive + Adaptive Layout & Dynamic Type

## What this skill does

Stops the "ships fine on my device, RenderFlex-overflows on a small phone or
when the user bumps OS font size to Large" class. Two orthogonal axes, both
mandatory:

1. **Screen size / form factor** — small↔large phone, tablet, foldable,
   split-screen, rotation, multi-window.
2. **Text scale / display size** — the OS accessibility "Font size" /
   "Display size" sliders multiply text (and density) well past your design.

Both are invisible to a single-pump golden test at one fixed size and
`textScaler == 1.0` — which is exactly why it shipped.

## Best practice (authoritative — Flutter docs + Material 3)

### Sizing & layout
- Decide layout from **available space**, never device type or orientation:
  `MediaQuery.sizeOf(context)` / `LayoutBuilder(constraints)`. **Never**
  `OrientationBuilder` to pick a layout, **never** `isTablet()/isPhone()`,
  **never** `MediaQuery...size.width` to fill width on big screens.
- **Material 3 window size classes** as the breakpoint contract:
  Compact `< 600`, Medium `600–840`, Expanded `> 840` (dp width).
- No fixed `width:`/`height:`/`SizedBox` on content that must fit. Use
  `Flexible`/`Expanded`/`Wrap`/`ConstrainedBox`/`FractionallySizedBox`;
  scrollables (`SingleChildScrollView`/`ListView`) for column content that
  can exceed the viewport.
- `SafeArea` for notches/cutouts/system bars. Don't lock orientation.
- Big screens: don't gobble width — `GridView`/max-content-width container.
- Break big widgets into small `const` ones; preserve state across config
  changes (`PageStorageKey`).

### Text scale / dynamic type
- **Respect** `MediaQuery.textScalerOf(context)` — never hard-disable
  scaling (accessibility regression + store risk).
- **Clamp at the app root** so extreme settings can't shatter the UI while
  still honoring users who need bigger text:
  `MediaQuery.withClampedTextScaling(minScaleFactor: 1.0, maxScaleFactor: 1.3, child: ...)`
  around `MaterialApp` (1.3 is the safe default; raise as the design supports).
- Text that shares a `Row` MUST be wrapped in `Flexible`/`Expanded` with
  `overflow: TextOverflow.ellipsis` or `softWrap`. Prefer reflow over
  `FittedBox`/`AutoSizeText` shrinking (shrinking text fails accessibility).
- The design must remain usable at the max clamp — verify, don't assume.

### Testing (the part the pipeline lacked)
- Golden/widget tests over a **matrix**: sizes `{320×640 (small), 390×844
  (modern), 768×1024 (tablet)}` × textScale `{1.0, 1.3, 2.0}`.
- Assert **no `RenderFlex`/overflow** at every cell (overflow paints a
  yellow-black banner + throws in tests if you assert on it).
- INTEGRATION_SMOKE runs the worst cell (smallest device + max textScale) on
  a real emulator with zero overflow.

## Code patterns

| Need | File |
|---|---|
| M3 breakpoints + `context.windowSize` helper | [snippets/breakpoints.dart](snippets/breakpoints.dart) |
| Root text-scale clamp around MaterialApp | [snippets/root_text_scale_clamp.dart](snippets/root_text_scale_clamp.dart) |
| Adaptive scaffold (Compact/Medium/Expanded) | [snippets/adaptive_layout.dart](snippets/adaptive_layout.dart) |
| size×textScale golden matrix harness | [snippets/responsive_golden_test.dart](snippets/responsive_golden_test.dart) |

Full step-by-step → [implementation.md](implementation.md). Real failure
modes → [pitfalls.md](pitfalls.md). Gate → [checklist.md](checklist.md).

## Pipeline wiring (enforced, not advisory)

- `ux-designer`: design-system.md declares breakpoints + the supported max
  text-scale; layouts.md states each screen's reflow behavior.
- `architect`: M3 window size classes + the root clamp value are explicit
  decisions.
- `app-bootstrap`: scaffolds the root clamp, `core/responsive/`, and the
  golden-matrix harness.
- `code-reviewer`: fixed-size / orientation-layout / disabled-scaling /
  unbounded-Text-in-Row → auto-flag.
- `test-writer`: every new screen/DS component gets the size×textScale golden
  matrix; overflow asserted.
- `qa-test-guide`: device-size × OS-font-size matrix scenarios.
- `INTEGRATION_SMOKE`: extreme-cell no-overflow is execution evidence.

## Skill metadata
- Validation status: **pre-seeded** (from the "breaks on other phone / big font" gap)
- Last verified: 2026-05-17 (Flutter docs adaptive/responsive best-practices, Material 3 window size classes, MediaQuery.withClampedTextScaling)

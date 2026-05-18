# Pitfalls — responsive + dynamic type

## P1 — One golden size, textScale 1.0
The root cause. A single 390×844 @ 1.0 pump is green while the app
RenderFlex-overflows on a 320-wide phone or at OS font size "Largest". Always
test the size×textScale matrix.

## P2 — Disabling text scaling to "fix" overflow
`textScaleFactor: 1.0` / `TextScaler.noScaling` makes overflow disappear and
breaks accessibility for low-vision users (and is an App Store / Play
accessibility risk). Clamp, don't kill.

## P3 — `OrientationBuilder` / `isTablet()` for layout
Orientation ≠ available space (split-screen, foldables, multi-window). Device
type ≠ window size. Decide from `MediaQuery.sizeOf`/`LayoutBuilder`.

## P4 — Fixed sizes on must-fit content
`Container(width: 300)` / `SizedBox(height: 240)` overflows a small screen or
when text scale pushes content taller. Use flexible/constrained widgets +
scrollables.

## P5 — `Text` directly in a `Row`
A long string (or normal string at textScale 2.0) overflows the Row. Wrap in
`Flexible`/`Expanded` with `ellipsis`/`softWrap`. Reflow > shrink.

## P6 — `FittedBox`/`AutoSizeText` as the answer
Shrinking text to fit defeats the user's font-size choice (accessibility).
Acceptable only for non-essential decorative text; prefer layout that reflows.

## P7 — Clamp set once, never re-verified
`maxScaleFactor: 1.3` is a promise the design holds to 1.3×. If a later screen
breaks at 1.3, that's a bug in the screen, not a reason to lower the clamp.

## P8 — Overlays/dialogs unclamped
Dialogs/bottom sheets from a different `Navigator`/overlay can escape a
builder-level clamp. `MediaQuery.withClampedTextScaling` around `MaterialApp`
covers its overlays; verify route dialogs too.

---

### Findings log
- 2026-05-17 — pre-seeded from the reported "app breaks on other phone sizes /
  larger OS font" gap. Not yet re-validated in a fresh project.

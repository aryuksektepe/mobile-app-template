# Verification Checklist — responsive + dynamic type

## Root / foundation
- [ ] `MediaQuery.withClampedTextScaling(minScaleFactor: 1.0, maxScaleFactor: <design max>)` wraps `MaterialApp`
- [ ] Text scaling is NOT disabled anywhere (`textScaleFactor: 1.0` / `TextScaler.noScaling` absent)
- [ ] `core/responsive/breakpoints.dart` (M3 window size classes) exists; all adaptive branching uses it
- [ ] Orientation not locked; `SafeArea` used for system insets

## Per screen / component
- [ ] Layout decided from `LayoutBuilder`/`MediaQuery.sizeOf`, not `OrientationBuilder`/`isTablet()`
- [ ] No fixed `width/height/SizedBox` on must-fit content (flexible/constrained/scrollable instead)
- [ ] Every `Text` in a `Row` is `Flexible`/`Expanded` + `ellipsis`/`softWrap`
- [ ] Column content that can exceed height is inside a scrollable
- [ ] Expanded/tablet layout caps content width (no full-width gobble)

## Proven (the gate)
- [ ] size×textScale golden/overflow matrix test exists: {320×640, 390×844, 768×1024} × {1.0, 1.3, 2.0}
- [ ] No `overflowed` error asserted at every matrix cell
- [ ] Usable (not just non-overflowing) at the max clamp — visually reviewed
- [ ] INTEGRATION_SMOKE: extreme cell (smallest device + max textScale) runs on a real emulator with zero overflow
- [ ] code-reviewer found no responsive/text-scale anti-pattern (or they were fixed)
- [ ] qa-test-guide scenario covers device-size × OS-font-size matrix

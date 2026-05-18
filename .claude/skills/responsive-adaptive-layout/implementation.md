# Implementation — responsive + dynamic type

## 1. Root clamp (once, app-bootstrap)
Wrap `MaterialApp` in `MediaQuery.withClampedTextScaling(minScaleFactor: 1.0,
maxScaleFactor: 1.3, …)` (snippet). Never `textScaleFactor: 1.0` /
`MediaQuery(textScaler: TextScaler.noScaling)` — that disables accessibility.
Record the chosen max in architecture + design-system.

## 2. Breakpoint contract (once)
Add `core/responsive/breakpoints.dart` (M3 window size classes + `context
.windowSize` + `responsive<T>()`). All adaptive branching goes through it —
no ad-hoc `width > 700` magic numbers, no `isTablet()`.

## 3. Per screen
- Layout from `LayoutBuilder` constraints / `MediaQuery.sizeOf`, not
  orientation or device.
- Column content that can exceed height → inside a scrollable.
- Text in a `Row` → `Flexible`/`Expanded` + `TextOverflow.ellipsis`/`softWrap`.
- No fixed `width/height/SizedBox` on must-fit content; use
  `Flexible/Expanded/Wrap/ConstrainedBox/FractionallySizedBox`.
- `SafeArea`; don't lock orientation; cap content width on Expanded.

## 4. Prove it (the gate)
Add the size×textScale matrix golden/overflow test (snippet) for the
screen/component. Assert no `overflowed` error at every cell. Wire the worst
cell (320×640 @ textScale 2.0 / clamp max) into INTEGRATION_SMOKE's real
emulator run.

## 5. Detect existing offenders
```bash
grep -rn "OrientationBuilder\|isTablet\|isPhone\|MediaQuery.of(context).size.width *," lib/
grep -rn "SizedBox(width:\|SizedBox(height:\|Container(\s*width:\|height: [0-9]" lib/src/**/presentation/
grep -rn "textScaleFactor: 1\|TextScaler.noScaling\|textScaler: TextScaler.linear(1" lib/
grep -rn "Row(\(.\)*Text(" lib/   # Text directly in Row without Flexible/Expanded → review
```

## 6. Route
code-reviewer flags the anti-patterns; fix in IN_PROGRESS; test-writer adds
the matrix; qa-test-guide adds device/font-size scenarios; INTEGRATION_SMOKE
executes the extreme cell. The skill is the how; the gates make it stick.

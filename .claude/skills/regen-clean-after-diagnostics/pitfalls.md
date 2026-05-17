# Pitfalls — regen-clean / CI determinism

## P1 — Pushing partially-generated code
Ran diagnostics or a scoped build, committed sources but not the regenerated
`.g.dart` → CI's fresh build_runner diff trips. Always regen + commit together.

## P2 — Timestamped artifacts in the diff gate
A report stamped with `DateTime.now()` differs every run. The gate red-fails
on noise; people learn to ignore it; a real regression slips. Make it
deterministic or exclude it.

## P3 — Excluding too much
Excluding `**/*.dart` "to make it pass" guts the gate. Exclude ONLY proven
non-deterministic artifacts; deterministic codegen stays gated.

## P4 — `--no-verify` past it
Bypassing the gate ships drift. Fix the root (regenerate / make deterministic),
never skip.

## P5 — Per-commit pushes
Each push = a full CI run. Per-commit pushing drained ~2000 Actions minutes in
one session. Batch; one run per batch confirms the local full gate.

---

### Findings log
- 2026-05-16 — pre-seeded from the ADR-020..035 launch-smoke session (CI
  budget burn + recurring generated-diff false-fails).

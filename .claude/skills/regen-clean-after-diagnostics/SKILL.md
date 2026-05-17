---
name: regen-clean-after-diagnostics
description: After running diagnostics/codegen locally, committed generated files (.g.dart/.freezed.dart) drift from a fresh build_runner and the CI generated-clean gate red-fails — often on non-deterministic timestamped artifacts. Use when CI fails on a generated diff, or before pushing after running build_runner/analyzers.
triggers: [generated diff fails CI, build_runner not clean, .g.dart drift, freezed regen, generated-clean gate, non-deterministic codegen, timestamp audit report diff, git diff exit-code generated]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Regen-clean after diagnostics (CI determinism)

## What this skill does

Keeps the `analyze-test` job's `git diff --exit-code` (generated-clean) gate
green and meaningful. Two failure modes it prevents:

1. **Stale generated code.** Diagnostics / partial codegen left `.g.dart` /
   `.freezed.dart` out of sync with sources; CI runs a fresh `build_runner`
   and the diff trips.
2. **Non-deterministic generated artifacts.** Timestamped/seeded generated
   files (audit reports, dated docs) differ on every run, so the diff gate
   red-fails for noise — eroding trust in the gate (people start ignoring it).

## The discipline (also in CLAUDE.md §9)

- **Before pushing:** `dart run build_runner build --delete-conflicting-outputs`
  then `git diff --exit-code` on generated paths. If it differs, commit the
  regenerated output — never push partially-generated code.
- **Batch pushes.** Run the full local gate, push in batches; CI confirms once
  per batch. Per-commit pushes burn the Actions budget (a real incident:
  ~2000 CI minutes drained).
- **Make generated artifacts deterministic OR exclude them.** Reports etc.:
  fix the timestamp/seed (`GENERATED_AT` env, sorted keys) so identical inputs
  produce identical output; otherwise exclude them from the diff gate via
  pathspec / `.gitattributes`. Never let a non-deterministic file gate CI.

## Pattern

```bash
# pre-push, locally:
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- 'lib/**/*.g.dart' 'lib/**/*.freezed.dart' \
  || { echo "regen and commit before pushing"; exit 1; }
```

Deterministic report generation: stable sort map keys, pass a fixed
`--define GENERATED_AT=<git-commit-date>` instead of `DateTime.now()`.

## Code patterns
| Need | File |
|---|---|
| Pre-push regen-clean guard | [snippets/pre_push_regen_check.sh](snippets/pre_push_regen_check.sh) |
| Deterministic generator stamp | [snippets/deterministic_stamp.dart](snippets/deterministic_stamp.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (CI session learning, ADR-020..035 run)
- Last verified: 2026-05-16

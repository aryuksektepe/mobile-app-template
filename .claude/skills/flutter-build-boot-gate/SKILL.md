---
name: flutter-build-boot-gate
description: Compile + first-boot smoke gate. Use in phase-01 and in CI to prove the app actually builds and launches before any review/QA. Catches native/Gradle/Kotlin/desugaring/manifest + bootstrap runtime aborts that static analysis and mocked tests cannot.
triggers: [build gate, boot smoke, does it run, flutter build apk, walking skeleton, app launches, integration_test boot, INTEGRATION_SMOKE, first frame assertion, splash lock]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Flutter Build + Boot Gate — does it actually compile and launch?

## What this skill does

- Adds a **compile** step (`flutter build apk --flavor <env> --debug`, iOS `--no-codesign`) that fails CI on native/Gradle/Kotlin/core-library-desugaring/manifest defects.
- Adds an **automated boot smoke test** that drives the REAL flavored `main()` entrypoint, awaits first frame, asserts a real first screen, and fails on ANY uncaught `FlutterError` or rebuild/dispose storm during boot.
- Adds the **canonical artifact producer** `tool/run_smoke.sh` — installed once by app-bootstrap, run by `coder` EVERY phase at `INTEGRATION_SMOKE` (locally in the auto-loop AND by CI). It builds with `--dart-define=GIT_SHA=$(git rev-parse --short HEAD)`, boots on a real device, runs the non-mocked e2e, and writes a captured **proof-of-work log** at `.project/qa-runs/smoke-<phase>-<sha>-<ts>.log` containing the app-emitted `BOOT_OK …sha=…`, `FIRST_SCREEN_OK`, and a final `SMOKE_RESULT exit=0 sha=…`.
- The `verify-smoke.py` hook MECHANICALLY blocks a phase from leaving `INTEGRATION_SMOKE` unless that artifact exists, its sha matches HEAD, it is fresher than `lib/`, and all three markers are present — turning the gate from agent self-report into proof-of-work (CLAUDE.md §3, ADR-011).
- (Legacy `tool/smoke_boot.sh` remains for a quick manual `flutter run` boot check; `run_smoke.sh` is the gate's source of truth.)
- Wires into CI as the `build-and-boot` / `build-ios` / `integration-smoke` jobs (which call `run_smoke.sh`) that gate the `INTEGRATION_SMOKE` state.

## What this skill does NOT do

- Does NOT replace unit/widget/integration feature tests — it is the floor, not the ceiling.
- Does NOT exercise real backends — that is `supabase-rls-client-contract` + the `backend-integration` CI job.
- Does NOT do release signing / store upload — that is `release-manager`.

## Why this skill exists (the pitfall it closes)

A pipeline can be fully "green" — `flutter analyze` clean, mocked unit/widget tests passing, read-only review approved, ~54% line coverage — and still ship an app that **does not compile** or **aborts on first frame**. Static gates and mocked tests structurally cannot see:

- Android: missing core library desugaring, Kotlin `languageVersion` conflict, leftover `MainActivity` package-rename artifact, missing notification drawable, broken manifest merge.
- Boot: a Riverpod scoped provider missing its `dependencies` declaration → first-frame assertion → splash lock.

These only appear at compile-time or app-boot. This gate is the cheapest possible test that makes that entire class visible. **A statically-green phase that was never built or booted is NOT verified.**

## Decision tree

**Q1: One boot test or per-flavor?**
- ONE against `main_dev.dart` is the gate floor (fastest). Add staging/prod boot tests only if flavors diverge in `bootstrap()` (different DI, different remote config).

**Q2: Emulator boot in CI, or just `flutter build`?**
- BOTH. `flutter build` catches compile defects; the emulator boot test catches runtime aborts. Build-only misses the Riverpod/`bootstrap()` class entirely.

**Q3: `tester.takeException()` or `FlutterError.onError` capture?**
- `FlutterError.onError` capture (see snippet). `takeException()` only catches synchronous exceptions in the pumped widget; boot aborts often surface as framework errors during settle.

## Quick start

```bash
# 1. Compile (the cheapest defect catch)
flutter build apk --flavor dev --debug --target lib/main_dev.dart
flutter build ios --flavor dev --debug --no-codesign --target lib/main_dev.dart

# 2. The GATE: canonical artifact producer (build + boot + non-mocked e2e on a
#    real device, captured proof-of-work log). Run this every phase.
bash tool/run_smoke.sh <phase_id> dev
#    → .project/qa-runs/smoke-<phase_id>-<sha>-<ts>.log  (verify-smoke.py checks it)
```

Wire the markers (see [snippets/boot_markers.dart](snippets/boot_markers.dart)):
`emitBootOk('<flavor>')` as the LAST line of each `main_<flavor>()` / shared
`bootstrap()`, and `emitFirstScreenOk(route)` from a post-first-frame callback
on the first REAL screen. Both read `kGitSha` from `--dart-define=GIT_SHA=…`
(run_smoke.sh injects it), so the sha in the marker proves a real build+boot.

CI: the `build-and-boot` (Android) + `build-ios` + `integration-smoke`
(emulator matrix, merge-to-main) jobs in `.github/workflows/ci.yml`. They must
be green for a phase to leave `INTEGRATION_SMOKE` → `COMPLIANCE_CHECK`.

## Code patterns

| Need | File |
|---|---|
| **Gate artifact producer** (build+boot+e2e → proof-of-work log) | [snippets/run_smoke.sh](snippets/run_smoke.sh) |
| Proof-of-work markers (`emitBootOk` / `emitFirstScreenOk`, sha-bound) | [snippets/boot_markers.dart](snippets/boot_markers.dart) |
| Boot smoke test (drives real `main()`, storm guard) | [snippets/boot_smoke_test.dart](snippets/boot_smoke_test.dart) |
| Legacy quick CLI boot check (`flutter run`, BOOT_OK, ≤60s) | [snippets/smoke_boot.sh](snippets/smoke_boot.sh) |
| CI jobs (Android build+boot, iOS build) | [snippets/ci-build-boot.yml](snippets/ci-build-boot.yml) |

Full step-by-step (flavor entrypoint wiring, emulator setup, what each compile failure means) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 3:
1. Pumping `App()` directly instead of `main()` — skips `bootstrap()` where boot aborts actually happen. Drive the flavored entrypoint.
2. `pumpAndSettle` too short — splash that settles at 1500ms needs >1500ms; use ≥10s and assert a known first-screen widget, not just "no exception".
3. Build-only CI (no emulator boot) — passes compile, still ships the Riverpod scoped-provider first-frame abort.

## Verification

→ [checklist.md](checklist.md) (build per flavor, iOS no-codesign, boot test green on emulator, evidence recorded in phase `## Integration Smoke`).

## Skill metadata
- Validation status: **pre-seeded** (written from a real post-mortem; adapt, don't apply blind)
- Last verified: 2026-05-16

---
name: flutter-build-boot-gate
description: Compile + first-boot smoke gate. Use in phase-01 and in CI to prove the app actually builds and launches before any review/QA. Catches native/Gradle/Kotlin/desugaring/manifest + bootstrap runtime aborts that static analysis and mocked tests cannot.
triggers: [build gate, boot smoke, does it run, flutter build apk, walking skeleton, app launches, integration_test boot, BUILD_VERIFIED, first frame assertion, splash lock]
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
- Adds an **automated boot smoke test** that drives the REAL flavored `main()` entrypoint, awaits first frame, and fails on ANY uncaught `FlutterError` during boot.
- Wires both into CI as the `build-and-boot` / `build-ios` jobs that gate the `BUILD_VERIFIED` state.

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

# 2. Boot smoke on an emulator/simulator
flutter test integration_test/app_boot_test.dart
```

CI: the `build-and-boot` (Android) + `build-ios` jobs in `.github/workflows/ci.yml`. They must be green before any phase enters `BUILD_VERIFIED`.

## Code patterns

| Need | File |
|---|---|
| Boot smoke test (drives real `main()`) | [snippets/app_boot_test.dart](snippets/app_boot_test.dart) |
| CI jobs (Android build+boot, iOS build) | [snippets/ci-build-boot.yml](snippets/ci-build-boot.yml) |

Full step-by-step (flavor entrypoint wiring, emulator setup, what each compile failure means) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 3:
1. Pumping `App()` directly instead of `main()` — skips `bootstrap()` where boot aborts actually happen. Drive the flavored entrypoint.
2. `pumpAndSettle` too short — splash that settles at 1500ms needs >1500ms; use ≥10s and assert a known first-screen widget, not just "no exception".
3. Build-only CI (no emulator boot) — passes compile, still ships the Riverpod scoped-provider first-frame abort.

## Verification

→ [checklist.md](checklist.md) (build per flavor, iOS no-codesign, boot test green on emulator, evidence recorded in phase `## Build Verification`).

## Skill metadata
- Validation status: **pre-seeded** (written from a real post-mortem; adapt, don't apply blind)
- Last verified: 2026-05-16

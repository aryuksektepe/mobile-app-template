# Implementation — regen-clean discipline

## 1. Pre-push guard
Install `snippets/pre_push_regen_check.sh` (or wire into `.githooks/pre-push`):
runs `build_runner`, fails if generated paths differ. Forces "regenerate +
commit" before the code leaves the machine, so CI never red-fails on stale
codegen.

## 2. Classify generated files
- **Deterministic** (`.g.dart`, `.freezed.dart`, l10n): MUST be in the diff
  gate. Identical inputs → identical bytes. If they drift, you forgot to
  regenerate.
- **Non-deterministic** (timestamped audit reports, dated docs): either make
  deterministic (fixed stamp/seed, sorted keys) OR exclude from the gate via
  pathspec (`:(exclude)…`) / `.gitattributes`. The repo `ci.yml` already
  excludes `.project/qa-runs/**`, `**/*.audit.md`, `**/generated-report-*`.

## 3. Make reports deterministic
Pass a stable stamp instead of `DateTime.now()`:
```bash
dart run tool/gen_report.dart --define GENERATED_AT="$(git log -1 --format=%cI)"
```
Sort all map/JSON keys before writing. Same inputs → same file.

## 4. CI economy
Batch pushes; one CI run per batch confirms the locally-passed full gate.
Don't push per commit (Actions-minute incident: ~2000 minutes drained). This
lives in CLAUDE.md §9 "CI economy & determinism".

## 5. When the gate legitimately differs
A real source change that alters generated output: regenerate, commit the
generated delta in the SAME commit as the source. Never `--no-verify` past it.

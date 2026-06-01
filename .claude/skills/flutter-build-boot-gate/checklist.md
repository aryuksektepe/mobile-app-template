# Verification Checklist — Flutter Build + Boot Gate

Run before claiming a phase can enter `INTEGRATION_SMOKE`.

## Compile
- [ ] `flutter build apk --flavor dev --debug --target lib/main_dev.dart` exits 0
- [ ] `flutter build apk --flavor staging --debug` exits 0 (if staging flavor exists)
- [ ] `flutter build apk --flavor prod --debug` exits 0 (if prod flavor exists)
- [ ] `flutter build ios --flavor dev --debug --no-codesign` exits 0 (unless Android-only project — log the skip)

## Boot — the GATE (proof-of-work, every phase)
- [ ] `tool/run_smoke.sh` installed (canonical artifact producer; CI calls the same script)
- [ ] `integration_test/boot_smoke_test.dart` exists and drives the REAL flavored `main()` (not `App()` directly)
- [ ] Markers wired (`boot_markers.dart`): `emitBootOk('<flavor>')` as the LAST line of each `main_<flavor>()`/`bootstrap()`, `emitFirstScreenOk(route)` from a post-first-frame callback on the first REAL screen
- [ ] `bash tool/run_smoke.sh <phase_id> dev` exits 0 and produces `.project/qa-runs/smoke-<phase>-<sha>-<ts>.log`
- [ ] That log contains `BOOT_OK …sha=<HEAD>` + `FIRST_SCREEN_OK` + `SMOKE_RESULT exit=0 sha=<HEAD>`
- [ ] Boot test asserts NO uncaught `FlutterError` via `FlutterError.onError` capture
- [ ] Boot test asserts a known first-screen widget renders (not just "no exception"); a settled splash that never navigates FAILS
- [ ] Boot test asserts no rebuild/dispose storm (bounded build count) where a debug counter exists
- [ ] (Optional quick check during dev: `tool/smoke_boot.sh <flavor>` — a fast `flutter run` boot probe, NOT the gate)

## Evidence (this is what the `verify-smoke.py` hook enforces)
- [ ] Phase archive `## Integration Smoke` references the produced `.project/qa-runs/smoke-*.log` artifact (NOT a hand-written "BOOT_OK ✓")
- [ ] The referenced log's sha == current HEAD and it is fresher than `lib/`
- [ ] If the phase touches a backend: the non-mocked e2e (HTTP trace + DB row) is recorded (see `supabase-rls-client-contract`)

## CI (OPTIONAL — manual-only by default, ADR-013)
- [ ] GitHub CI (`build-and-boot` / `build-ios` / `integration-smoke`) runs the SAME `run_smoke.sh` — but is `workflow_dispatch` only; the LOCAL artifact + hook is the binding gate, not cloud CI
- [ ] Run cloud CI by hand (Actions → Run workflow) only when you want a batch confirmation (e.g. pre-release)

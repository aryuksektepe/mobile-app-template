# Verification Checklist — Flutter Build + Boot Gate

Run before claiming a phase can enter `INTEGRATION_SMOKE`.

## Compile
- [ ] `flutter build apk --flavor dev --debug --target lib/main_dev.dart` exits 0
- [ ] `flutter build apk --flavor staging --debug` exits 0 (if staging flavor exists)
- [ ] `flutter build apk --flavor prod --debug` exits 0 (if prod flavor exists)
- [ ] `flutter build ios --flavor dev --debug --no-codesign` exits 0 (unless Android-only project — log the skip)

## Boot
- [ ] `integration_test/boot_smoke_test.dart` exists and drives the REAL flavored `main()` (not `App()` directly)
- [ ] `tool/smoke_boot.sh` installed; each `main_<flavor>()`/`bootstrap()` emits `debugPrint('BOOT_OK flavor=…')` as its last line
- [ ] `tool/smoke_boot.sh <flavor>` sees `BOOT_OK` within timeout
- [ ] Boot test asserts NO uncaught `FlutterError` via `FlutterError.onError` capture
- [ ] Boot test asserts a known first-screen widget renders (not just "no exception"); a settled splash that never navigates FAILS
- [ ] Boot test asserts no rebuild/dispose storm (bounded build count) where a debug counter exists
- [ ] Boot passes on an emulator/simulator (locally AND in `build-and-boot` + `integration-smoke` CI jobs)

## CI
- [ ] `.github/workflows/ci.yml` has `build-and-boot` + `build-ios` jobs
- [ ] Those jobs are green on the phase branch
- [ ] `analyze-test` (static) is also green — but is NOT accepted as a substitute

## Evidence
- [ ] Build log tail (exit 0 line per flavor) recorded in phase `## Integration Smoke`
- [ ] Boot-test PASS line recorded in phase `## Integration Smoke`
- [ ] If the phase touches a backend: the non-mocked `backend-integration` result is also recorded (see `supabase-rls-client-contract`)

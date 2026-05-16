# Verification Checklist — Flutter Build + Boot Gate

Run before claiming a phase can enter `BUILD_VERIFIED`.

## Compile
- [ ] `flutter build apk --flavor dev --debug --target lib/main_dev.dart` exits 0
- [ ] `flutter build apk --flavor staging --debug` exits 0 (if staging flavor exists)
- [ ] `flutter build apk --flavor prod --debug` exits 0 (if prod flavor exists)
- [ ] `flutter build ios --flavor dev --debug --no-codesign` exits 0 (unless Android-only project — log the skip)

## Boot
- [ ] `integration_test/app_boot_test.dart` exists and drives the REAL flavored `main()` (not `App()` directly)
- [ ] Boot test asserts NO uncaught `FlutterError` via `FlutterError.onError` capture
- [ ] Boot test asserts a known first-screen widget renders (not just "no exception")
- [ ] Boot test passes on an emulator/simulator (locally AND in the `build-and-boot` CI job)

## CI
- [ ] `.github/workflows/ci.yml` has `build-and-boot` + `build-ios` jobs
- [ ] Those jobs are green on the phase branch
- [ ] `analyze-test` (static) is also green — but is NOT accepted as a substitute

## Evidence
- [ ] Build log tail (exit 0 line per flavor) recorded in phase `## Build Verification`
- [ ] Boot-test PASS line recorded in phase `## Build Verification`
- [ ] If the phase touches a backend: the non-mocked `backend-integration` result is also recorded (see `supabase-rls-client-contract`)

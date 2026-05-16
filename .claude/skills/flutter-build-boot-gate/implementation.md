# Implementation — Flutter Build + Boot Gate

## Step 1 — Add the boot smoke test

Copy `snippets/app_boot_test.dart` to `integration_test/app_boot_test.dart`.
Adapt two things:

1. `import 'package:<APP_PACKAGE>/main_dev.dart' as app;` → real package name
   (from `pubspec.yaml` `name:`) and the dev flavor entrypoint.
2. The first-screen assertion → whatever `lib/src/core/router/app_router.dart`
   renders at `/` (SplashScreen, AuthLandingScreen, HomeScreen, …).

Why the real entrypoint and not `App()`: `main_dev.dart` calls `bootstrap()`,
which initialises Sentry/Crashlytics, error handlers, and the root
`ProviderScope`. Boot aborts (e.g. a Riverpod scoped provider declared without
its `dependencies`) happen INSIDE that path. Pumping `App()` directly skips it
and the gate would pass on a broken app.

## Step 2 — Compile each flavor

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --flavor dev     --debug --target lib/main_dev.dart
flutter build apk --flavor staging --debug --target lib/main_staging.dart
flutter build apk --flavor prod    --debug --target lib/main_prod.dart
flutter build ios --flavor dev     --debug --no-codesign --target lib/main_dev.dart
```

What a failure here usually means:

| Symptom | Root cause | Fix |
|---|---|---|
| `Dependency ':app@debug/compileClasspath' ... desugar` | core library desugaring not enabled | `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:<v>")` in `android/app/build.gradle.kts` |
| `Inconsistent JVM-target` / Kotlin `languageVersion` | Kotlin/AGP/Gradle mismatch | align `kotlinOptions.jvmTarget`, `compileOptions`, AGP + Kotlin plugin versions |
| `ClassNotFoundException: .MainActivity` on launch | leftover package after `--org` rename | move `MainActivity.kt` to the new package dir + fix `package` + manifest `android:name` |
| `resource drawable/ic_notification not found` | notification icon referenced but absent | add the drawable to `android/app/src/main/res/drawable*` or remove the manifest meta-data |
| iOS `Sandbox: rsync ... Permission denied` / pod errors | CocoaPods/entitlement drift | `pod repo update && pod install` in `ios/`; verify schemes/xcconfig |

## Step 3 — Boot on an emulator

Locally: start any emulator/simulator, then
`flutter test integration_test/app_boot_test.dart`.

CI: use the jobs in `snippets/ci-build-boot.yml` (mirrored in the repo-root
`.github/workflows/ci.yml`). The Android job uses
`reactivecircus/android-emulator-runner@v2`.

## Step 4 — Record evidence

Write the build log tail (the `exit 0` / `✓ Built …` line per flavor) and the
boot-test PASS line into the phase file's `## Build Verification` section. The
orchestrator gates `BUILD_VERIFIED` on this evidence existing (CLAUDE.md §3);
no evidence → it routes back to coder/app-bootstrap, never advances.

## Step 5 — Keep it the floor, not the ceiling

This gate proves "compiles + boots". It is necessary, not sufficient. Feature
correctness still needs unit/widget/integration tests, and backend paths still
need the non-mocked `backend-integration` job (see
`supabase-rls-client-contract`).

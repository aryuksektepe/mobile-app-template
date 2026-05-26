# Hardening — Verification Checklist

Run before every release. Tied to `release-manager` agent's pre-ship gate.

## Android
- [ ] `minifyEnabled true` + `shrinkResources true` in release buildType
- [ ] `proguard-rules.pro` present with Firebase + Drift + RC + freezed + Flutter + Sentry rules
- [ ] R8 mapping file `build/app/outputs/mapping/<flavor>Release/mapping.txt` generated
- [ ] Mapping file uploaded to Crashlytics (`gradle uploadCrashlyticsMappingFile<Variant>`)
- [ ] App Bundle built with `flutter build appbundle --release --flavor <f> --obfuscate --split-debug-info=...`
- [ ] `--split-debug-info` path uses STABLE name (no build number)
- [ ] `.symbols` files copied to CI artifact
- [ ] `verify-release-shrinking.sh` passes (BOOT_OK on real device, no `NoSuchMethodError`)

## iOS
- [ ] Strip Style = All Symbols (Build Settings → Release)
- [ ] Debug Information Format = DWARF with dSYM File
- [ ] Bitcode = NO (dead since Xcode 14)
- [ ] `flutter build ipa --release --flavor <f> --obfuscate --split-debug-info=...`
- [ ] dSYM upload step in Fastlane after `gym` (`upload_symbols_to_crashlytics`)
- [ ] Sentry CLI upload: `sentry-cli upload-dif --org <o> --project <p> ios/build/`

## Symbol upload (both platforms)
- [ ] Crashlytics dashboard shows new release version with symbol-OK badge
- [ ] Sentry shows release with sourcemaps uploaded
- [ ] Test crash from release build symbolicates cleanly in both

## Pre-ship smoke
- [ ] Release App Bundle installed on REAL device (not emulator); boots to first screen
- [ ] Release IPA installed via TestFlight; boots to first screen
- [ ] Test trigger one crash in release; verify Crashlytics shows readable Dart stack

## Re-validate when
- [ ] New SDK added with reflection (Drift extension, retrofit, dio adapter)
- [ ] Flutter major version bump
- [ ] Android Gradle Plugin bump
- [ ] Xcode major version bump

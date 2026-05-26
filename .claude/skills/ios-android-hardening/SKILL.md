---
name: ios-android-hardening
description: Release-build hardening — Flutter `--obfuscate --split-debug-info`, Android R8/ProGuard keep rules (Firebase, Drift, freezed, RC, retrofit, mocktail-mocked), iOS Strip Style + Symbols upload, IPA bitcode-off, removing Flutter debug strings, verifying shrinking didn't break reflection. Use as Phase 01 foundation work; revalidate every time a new SDK is added.
triggers: [proguard, r8, obfuscation, split debug info, release crash, NoSuchMethodError release, ClassNotFoundException, missing rule, shrinking broke, app size reduce, strip symbols, dsym upload, hardening, app bundle proguard]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
ios_min: "13.0"
android_min_sdk: 24
package_versions: {}
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [crash-monitor-dual]
---

# iOS + Android Release Hardening

## What this skill does

- Wires `flutter build` for release with `--obfuscate --split-debug-info` (Dart symbol stripping; required for `crash-monitor-dual` to decode stacks).
- Provides a **starter R8/ProGuard keep-rules file** covering Firebase + Drift + freezed + RevenueCat + retrofit + standard reflection-based packages.
- iOS Build Settings: `Strip Style = All Symbols`, `Deployment Postprocessing = Yes` for Release, dSYM generation = `DWARF with dSYM File`.
- Adds the `verify-release-shrinking` smoke step (the most common production crash is "missed keep rule" — caught by booting the release build once before shipping).
- Symbol upload coordination with `crash-monitor-dual`.

## What this skill does NOT do

- Does NOT enable code signing (release-manager territory).
- Does NOT cover web/desktop release builds.

## Decision tree

**Q1: Obfuscation needed?**
- YES (default for production) — `--obfuscate --split-debug-info=build/symbols/<flavor>/<version>`. Required so reverse engineering is non-trivial and crash reports can still be symbolicated via uploaded symbols.
- NO (debug/staging) — skip for faster iteration.

**Q2: R8 shrinking + obfuscation on Android?**
- YES (`isMinifyEnabled = true`, `isShrinkResources = true`) — recommended for size + obfuscation. REQUIRES correct keep rules or runtime crashes.
- NO — release APK ~50% bigger; reflection works without keep rules.

**Q3: New SDK using reflection added?**
- YES → re-run the [verify-release-shrinking](#verification) smoke + check pitfalls.md item #1.

## Quick start

1. Android `android/app/build.gradle`:
   ```gradle
   buildTypes {
     release {
       minifyEnabled true
       shrinkResources true
       proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
     }
   }
   ```
2. Copy [snippets/proguard-rules.pro](snippets/proguard-rules.pro) to `android/app/proguard-rules.pro`.
3. iOS `Runner.xcodeproj` → Build Settings → Release:
   - `Strip Style = All Symbols`
   - `Deployment Postprocessing = Yes`
   - `Debug Information Format = DWARF with dSYM File`
4. Always release-build with:
   ```bash
   flutter build appbundle --release --flavor prod \
     --obfuscate --split-debug-info=build/symbols/prod/$VERSION
   flutter build ipa --release --flavor prod \
     --obfuscate --split-debug-info=build/symbols/prod/$VERSION --export-options-plist=ios/ExportOptions.plist
   ```
5. Upload `build/symbols/prod/$VERSION/*.symbols` to Crashlytics + Sentry (see `crash-monitor-dual`).
6. **Boot the release build once on a real device before shipping** ([verify-release-shrinking.sh](snippets/verify-release-shrinking.sh)).

## Code patterns

| Need | File |
|---|---|
| ProGuard/R8 keep rules (Firebase, Drift, freezed, RC, retrofit, more) | [snippets/proguard-rules.pro](snippets/proguard-rules.pro) |
| Verify-release-shrinking smoke script | [snippets/verify-release-shrinking.sh](snippets/verify-release-shrinking.sh) |
| iOS ExportOptions.plist template | [snippets/ExportOptions.plist](snippets/ExportOptions.plist) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (10 entries). Top 5:
1. App boots in debug, crashes immediately in release with `NoSuchMethodError` / `ClassNotFoundException` → missing keep rule for a reflection-based SDK (Drift, Retrofit, freezed runtime fromJson).
2. `--split-debug-info` files left out of CI artifacts → Crashlytics can't symbolicate → stack traces are unreadable.
3. Forgot `--obfuscate` → release stack traces show Dart method names → easier reverse engineering.
4. R8 strips a class that's only called via JNI / `MethodChannel` → silent dead path.
5. iOS Strip Style = Non-Global Symbols (default for some Xcode setups) → dSYM upload incomplete → Crashlytics shows hex addresses.

## Verification

→ [checklist.md](checklist.md) (12 items: release boots on real device, symbols uploaded, R8 mapping file kept, Drift/freezed migrations still work after shrink, App Bundle integrity).

## Skill metadata
- Validation status: **pre-seeded** (rules compiled from official package docs — adapt per actual dependency set)
- Last verified: 2026-05-26
- Depends on: `crash-monitor-dual` (consumes `--split-debug-info` output + dSYM)

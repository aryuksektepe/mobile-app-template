---
name: firebase-core-setup
description: FlutterFire foundation — flutterfire_cli setup, multi-flavor (dev/staging/prod) Firebase projects, App Check (Play Integrity + DeviceCheck), per-flavor service files, Xcode/Gradle wiring. Required before adding any other Firebase product (Auth, Firestore, FCM, Analytics, Crashlytics, Remote Config). Use as Phase 01 foundation work.
triggers: [firebase, flutterfire, firebase init, firebase setup, firebase_core, flavor, dev staging prod, app check, google-services.json, GoogleService-Info.plist, firebase_options]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.3.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  firebase_core: "^4.7.0"
  firebase_app_check: "^0.4.0"
  flutterfire_cli: ">=1.3.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Firebase Core Setup — FlutterFire Foundation

## What this skill does

- Wires `firebase_core` 4.x into a multi-flavor Flutter project (dev/staging/prod with **separate Firebase projects per flavor**).
- Automates per-flavor service-file generation via `flutterfire_cli` shell script.
- Configures **App Check** (Play Integrity on Android, DeviceCheck on iOS) with debug-provider fallback for simulator/emulator.
- Creates flavor entrypoints (`main_dev.dart`, `main_stg.dart`, `main_prod.dart`) and a single shared `bootstrap()` function.
- Sets up Riverpod providers for shared FirebaseApp/FirebaseAuth/etc.

## What this skill does NOT do

- Does NOT configure individual Firebase products (Auth, Firestore, Storage, FCM, Analytics, Crashlytics) — those are separate skills that depend on this one.
- Does NOT set up Flutter flavors themselves (Android `productFlavors`, Xcode schemes) — that's prerequisite work `app-bootstrap` agent handles.
- Does NOT manage Firebase Console resources (security rules, indexes, Functions deploy).

## Decision tree

**Q1: Single Firebase project for all flavors, or one project per flavor?**
- ONE PROJECT PER FLAVOR (recommended) — separate Firestore data, separate Crashlytics, no risk of polluting prod metrics with dev events. Slightly more console juggling.
- Single project — simpler, but dev/test data lives next to prod. Only choose for personal/hobby apps.

**Q2: App Check from day one?**
- YES (recommended) — even if backend doesn't enforce yet, you'll have the token plumbing ready. Saves a painful retrofit when you add Firestore/Functions later.
- Defer — acceptable for early prototyping; add via `flutterfire reconfigure` later.

**Q3: Commit `google-services.json` / `GoogleService-Info.plist` to git?**
- YES (default) — they are project identifiers, not secrets (the API keys inside are restricted by SHA fingerprint + bundle ID).
- NO — only if security policy requires; then inject via CI from secrets store.

## Quick start

```bash
# 1. Tooling
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

# 2. Add package
flutter pub add firebase_core firebase_app_check

# 3. Run config script (see snippets/flutterfire-config.sh)
./flutterfire-config.sh dev
./flutterfire-config.sh stg
./flutterfire-config.sh prod

# 4. Run a flavor
flutter run --flavor dev -t lib/main_dev.dart
```

## Code patterns

| Need | File |
|---|---|
| Multi-flavor configure script | [snippets/flutterfire-config.sh](snippets/flutterfire-config.sh) |
| Shared bootstrap with App Check | [snippets/bootstrap.dart](snippets/bootstrap.dart) |
| Flavor entrypoints (dev/stg/prod) | [snippets/main_dev.dart](snippets/main_dev.dart) |
| Riverpod core providers | [snippets/firebase_providers.dart](snippets/firebase_providers.dart) |

For full setup (Firebase Console projects, Android Gradle, iOS Podfile, App Check provider tokens) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (13 entries). Top 3:
1. `[core/duplicate-app]` after hot restart — guard with `if (Firebase.apps.isEmpty)`.
2. iOS build "GoogleService-Info.plist not found" — wrong Xcode build phase per scheme.
3. Region NOT EU but app serves EU — Firebase project default region is **irreversible after creation**. Pick `europe-west*` at creation time.

## Verification

→ [checklist.md](checklist.md) (16 items: tooling, per-flavor builds, App Check tokens, debug provider registration).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_core` 4.7.0, `flutterfire_cli` 1.3.0+

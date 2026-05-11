# Firebase Core Setup — Implementation Guide

## 1. Tooling install

```bash
npm install -g firebase-tools
firebase login

dart pub global activate flutterfire_cli
flutterfire --version   # ≥ 1.3.0
```

## 2. Create per-flavor Firebase projects

In [Firebase Console](https://console.firebase.google.com):
1. Create three projects: `<appname>-dev`, `<appname>-stg`, `<appname>-prod`.
2. **CRITICAL**: pick the data region per product (Firestore, Storage, Functions) at creation. **It is irreversible.** For TR/EU users, `europe-west1` or `europe-west3`.
3. For each project, go to Project Settings and add iOS + Android apps with the flavor-specific bundle IDs:
   - `com.acme.myapp.dev`, `com.acme.myapp.stg`, `com.acme.myapp` (prod uses base ID).

## 3. Flutter flavors prerequisite

Before running `flutterfire configure`, your project must have:

**Android `android/app/build.gradle.kts`:**
```kotlin
android {
  flavorDimensions += "env"
  productFlavors {
    create("dev") { dimension = "env"; applicationIdSuffix = ".dev" }
    create("stg") { dimension = "env"; applicationIdSuffix = ".stg" }
    create("prod") { dimension = "env" }
  }
}
```

**iOS Xcode schemes**: create `Runner-dev`, `Runner-stg`, `Runner-prod` schemes via Xcode → Manage Schemes. Each scheme targets a different bundle ID via `Product Bundle Identifier` build setting (use User-Defined Setting like `BUNDLE_ID_SUFFIX`).

(`app-bootstrap` agent should produce this scaffold.)

## 4. Run the multi-flavor configure script

```bash
chmod +x flutterfire-config.sh
./flutterfire-config.sh dev
./flutterfire-config.sh stg
./flutterfire-config.sh prod
```

Verify output:
- `lib/firebase_options_dev.dart`, `_stg.dart`, `_prod.dart`
- `ios/flavors/dev/GoogleService-Info.plist` (etc.)
- `android/app/src/dev/google-services.json` (etc.)

## 5. Wire iOS per-flavor plist into Xcode

`flutterfire configure` patches Xcode's project.pbxproj for the most common case, but verify:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. For each scheme (Runner-dev/stg/prod), check Build Phases → Copy Bundle Resources includes the **right** `GoogleService-Info.plist` for that flavor.
3. Best practice: add a "Copy Firebase Plist" Run Script Build Phase (before Compile Sources) that copies the correct flavor plist:
   ```bash
   cp "${SRCROOT}/flavors/${FIREBASE_FLAVOR}/GoogleService-Info.plist" \
      "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
   ```
   And set `FIREBASE_FLAVOR` per scheme.

## 6. Verify Android per-flavor JSON

`android/app/src/<flavor>/google-services.json` is auto-detected by the Gradle plugin when you run with `--flavor <flavor>`.

Verify: `cd android && ./gradlew tasks` should not error on the google-services plugin.

## 7. Add Flutter packages

```yaml
dependencies:
  firebase_core: ^4.7.0
  firebase_app_check: ^0.4.0
  flutter_riverpod: ^2.5.0
```

```bash
flutter pub get
cd ios && pod install --repo-update
```

## 8. Create flavor entrypoints

- [snippets/bootstrap.dart](snippets/bootstrap.dart) — shared init (Firebase + App Check + runApp).
- [snippets/main_dev.dart](snippets/main_dev.dart) — flavor entrypoint. Mirror as `main_stg.dart` and `main_prod.dart`.

```bash
flutter run --flavor dev -t lib/main_dev.dart
```

## 9. App Check setup

### Production providers

**Android — Play Integrity API:**
1. Google Cloud Console (NOT Firebase) → Project for the flavor → APIs & Services → enable **Play Integrity API**.
2. Firebase Console → App Check → register Play Integrity for the Android app.
3. Add Play App Signing SHA-256 fingerprint to Firebase Console (Project Settings).

**iOS — DeviceCheck (default):**
1. Firebase Console → App Check → register DeviceCheck for iOS app.
2. Generate **App Attest Key** from [Apple Developer Portal](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Keys → enable App Attest.
3. Upload Key ID + Team ID + `.p8` to Firebase Console.

(For stronger attestation use App Attest instead of DeviceCheck — only on iOS 14.5+ physical devices.)

### Debug provider (simulator/emulator)

In `bootstrap.dart`, debug builds use `AndroidProvider.debug` / `AppleProvider.debug`. On first run the SDK logs a debug token to the console:
```
App Check debug token: 12345678-90ab-cdef-1234-567890abcdef
```
Copy it → Firebase Console → App Check → Apps → ⋮ → **Manage debug tokens** → register.

## 10. Enforce App Check on backend

Until you enforce, App Check tokens are gathered but not required. To enforce:
- Firebase Console → App Check → APIs → for each (Firestore, Functions, Storage, RTDB, Authentication) → click **Enforce**.

⚠ Test thoroughly in staging first — enforcement instantly rejects all unattested traffic.

## 11. Verify

Run [checklist.md](checklist.md).

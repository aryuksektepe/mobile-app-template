# Firebase Core Setup — Pitfalls Catalog

13 entries from FlutterFire GitHub issues, FlutterFire docs, and CodeWithAndrea multi-flavor guide.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | `[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists` after hot restart | `Firebase.initializeApp()` called twice (often during dev) | Guard with `if (Firebase.apps.isEmpty) await Firebase.initializeApp(...)`; never call init inside widget code or `initState` | [GH #10313](https://github.com/firebase/flutterfire/issues/10313) |
| 2 | Same duplicate-app error after switching Firebase projects | Stale `google-services.json` / `GoogleService-Info.plist` from old project still resolved by gradle/Xcode | Delete service files, run `./flutterfire-config.sh <flavor>` again | [dev.to](https://dev.to/curtlycritchlow/how-to-fix-coreduplicate-app-a-firebase-app-named-default-already-exists-error-3bjj) |
| 3 | Wrong Firebase project loads in flavor (e.g., dev events go to prod) | Two flavors share the same iOS bundle ID — Xcode plist resolution is ambiguous | Use distinct bundle IDs per flavor (`.dev`, `.stg` suffix) | [FlutterFire CLI docs](https://firebase.flutter.dev/docs/cli/) |
| 4 | iOS build error: `GoogleService-Info.plist not found` | Per-flavor plist not added to the right Xcode build phase per scheme | Add a Run Script Build Phase that copies `flavors/$FIREBASE_FLAVOR/GoogleService-Info.plist` to `${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/`; set `FIREBASE_FLAVOR` env var per scheme | [CodeWithAndrea](https://codewithandrea.com/articles/flutter-firebase-multiple-flavors-flutterfire-cli/) |
| 5 | Android build fails: `File google-services.json is missing` | Flavor source-set folder mismatch | File must live at `android/app/src/<flavor>/google-services.json` where `<flavor>` matches `productFlavors {}` block name exactly | [CodeWithAndrea](https://codewithandrea.com/articles/flutter-firebase-multiple-flavors-flutterfire-cli/) |
| 6 | Multiple `firebase_options_*.dart` files bundled into release APK/IPA | Single shared `main.dart` imports all variants | Use one entrypoint per flavor (`main_dev.dart` etc.); only import that flavor's options file | [CodeWithAndrea](https://codewithandrea.com/articles/flutter-firebase-multiple-flavors-flutterfire-cli/) |
| 7 | App Check rejects all requests in debug | Production attestation providers used on simulator/emulator | Use `AndroidProvider.debug` / `AppleProvider.debug` in `kDebugMode`; copy logged debug token to Firebase Console → App Check → Manage debug tokens | [Firebase docs](https://firebase.google.com/docs/app-check/flutter/debug-provider) |
| 8 | Play Integrity errors in production Android | SHA-256 fingerprint not registered, or Play Integrity API not enabled in Cloud Console | Enable Play Integrity API in Cloud Console (NOT Firebase); add Play App Signing SHA-256 (NOT debug keystore) to Firebase Console | [Firebase Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider) |
| 9 | iOS DeviceCheck "App Attest unsupported" on simulator | DeviceCheck/App Attest only work on physical devices iOS 14.5+ | Always use debug provider on simulator/emulator; gate by `kDebugMode` or `Platform.environment` | [Firebase default providers](https://firebase.google.com/docs/app-check/flutter/default-providers) |
| 10 | After adding a new Firebase product (e.g., Crashlytics), iOS dSYM upload script missing from Xcode | `flutterfire configure` only patched the Xcode project once at initial setup | Run `flutterfire reconfigure` — it rewrites Xcode project.pbxproj run scripts and Android `build.gradle` | [flutterfire_cli changelog](https://pub.dev/packages/flutterfire_cli/changelog) |
| 11 | iOS App Store rejection: "Missing Privacy Manifest" | Old Firebase iOS SDK (<10.22.0) without bundled `PrivacyInfo.xcprivacy` | Bump `firebase_core` to 4.x (uses Firebase iOS SDK 11.x) — privacy manifests for Core/Analytics/Crashlytics now ship inside xcframeworks | [Firebase iOS release notes](https://firebase.google.com/support/release-notes/ios) |
| 12 | Hot restart loses Firebase instance OR throws duplicate-app | Native side keeps state but Dart side reinits | Same `Firebase.apps.isEmpty` guard; this is dev-only noise | [Reference](https://harishkunchala.com/flutter-a-firebase-app-named-default-already-exists) |
| 13 | App serves EU users but data goes to US (KVKK violation) | Firebase project default region was `us-central` at creation — **irreversible after the first Firestore/Storage/Functions resource is created** | Create EU-region project from start (`europe-west1`/`europe-west3`); for existing projects, you must create a new project and migrate | [Firebase locations](https://firebase.google.com/docs/projects/locations) |

## How to extend
When you hit a new issue:
1. Reproduce + identify root cause.
2. Append a row above with Symptom/Cause/Fix/Source.
3. Bump `last_verified` in [SKILL.md](SKILL.md).

# Firebase Core Setup — Verification Checklist

## Tooling
- [ ] `firebase --version` shows installed Firebase CLI
- [ ] `flutterfire --version` ≥ 1.3.0
- [ ] User is logged in: `firebase login --no-localhost` if SSH session

## Per-flavor Firebase projects
- [ ] Three Firebase projects exist (dev/stg/prod) with **distinct project IDs**
- [ ] Each has correct **default region** matching user-data-residency requirements (irreversible — pitfall #13)
- [ ] Each has both iOS app + Android app registered with flavor-specific bundle/package IDs

## Service files generated
- [ ] `lib/firebase_options_dev.dart`, `_stg.dart`, `_prod.dart` exist and contain different `apiKey` values
- [ ] `ios/flavors/<flavor>/GoogleService-Info.plist` exists for each flavor
- [ ] `android/app/src/<flavor>/google-services.json` exists for each flavor

## Build verification
- [ ] `flutter build apk --flavor dev -t lib/main_dev.dart` succeeds
- [ ] `flutter build apk --flavor prod -t lib/main_prod.dart` succeeds
- [ ] `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` succeeds
- [ ] Verified at runtime: dev build's events appear in dev Firebase project (not prod)

## App Check
- [ ] Play Integrity API enabled in Cloud Console for each Android app
- [ ] DeviceCheck (or App Attest) configured in Firebase Console for each iOS app
- [ ] Debug token registered in Firebase Console after first dev run
- [ ] App Check NOT enforced in production yet (enforce only after staging proves clean)
- [ ] (When ready) Enforced on Firestore + Functions + Storage in prod project

## Code wiring
- [ ] `bootstrap.dart` guards init with `if (Firebase.apps.isEmpty)`
- [ ] App Check `activate()` called immediately after `initializeApp()`
- [ ] Riverpod `firebaseAppProvider` exposed for downstream services
- [ ] Each flavor entrypoint imports ONLY its own `firebase_options_<flavor>.dart` (pitfall #6)

## Compliance
- [ ] Privacy policy mentions Firebase / Google as data processor
- [ ] Region disclosure documented (where user data physically resides)
- [ ] DPA signed: https://firebase.google.com/terms/data-processing-terms
- [ ] iOS `PrivacyInfo.xcprivacy` exists at `ios/Runner/` with at minimum `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`

## Operational
- [ ] CI builds pass for all three flavors
- [ ] Service files committed (or injected from CI secrets if security policy demands)
- [ ] Adding a NEW Firebase product → run `flutterfire reconfigure` (pitfall #10)

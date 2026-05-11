# Crash Monitoring — Verification Checklist

## Setup
- [ ] `firebase_crashlytics ^5.2.0` + `sentry_flutter ^9.20.0` resolved
- [ ] `sentry_dart_plugin` in `dev_dependencies`
- [ ] `flutterfire reconfigure` run after adding Crashlytics

## Code wiring
- [ ] `FlutterError.onError` sends to BOTH Crashlytics + Sentry
- [ ] `PlatformDispatcher.instance.onError` sends to BOTH (returns `true`)
- [ ] No `runZonedGuarded` (legacy pattern — pitfall #10)
- [ ] `setCrashlyticsCollectionEnabled(!kDebugMode)` called once after init
- [ ] `SentryFlutter.init` uses `appRunner: () => runApp(...)` (not init then runApp separately)
- [ ] `sendDefaultPii: false` in Sentry options
- [ ] `beforeSend` scrubber attached and verified

## User identification
- [ ] User IDs always passed through `_hash()` — manual code review confirms NO raw email/UID/phone
- [ ] On logout, `clearCrashUser()` called

## iOS
- [ ] `Debug Information Format` = "DWARF with dSYM File" for Release config
- [ ] "Run Firebase Crashlytics Scripts" build phase exists in Runner target
- [ ] Test crash from Xcode-installed build appears deobfuscated in Crashlytics within 5 min

## Android
- [ ] `firebaseCrashlytics { mappingFileUploadEnabled = true }` in `android/app/build.gradle.kts`
- [ ] Release AAB build → mapping uploads visible in Firebase Crashlytics → Settings
- [ ] Sentry receives release build crashes with deobfuscated frames after `dart run sentry_dart_plugin`

## Release tagging
- [ ] Sentry events show `release: package@1.2.3+45` (verify in Issue details)
- [ ] Crashlytics custom key `build_number` set per build

## Test crash flow
- [ ] `FirebaseCrashlytics.instance.crash()` triggers crash; appears in Firebase Console after restart + 5 min
- [ ] `Sentry.captureException(StateError('test'))` appears in Sentry within 1 min
- [ ] Both events show deobfuscated stack traces (NOT `xxx.dart:1`)

## Compliance
- [ ] Privacy policy lists Crashlytics (Google) + Sentry (Functional Software, US or EU region)
- [ ] Cross-border transfer disclosure under KVKK Art. 9 + GDPR Art. 13
- [ ] Crashlytics collection OFF until consent flag granted
- [ ] No PII in any crash payload (verified by inspecting one real test crash)
- [ ] Sentry EU region used if KVKK strict-residency required

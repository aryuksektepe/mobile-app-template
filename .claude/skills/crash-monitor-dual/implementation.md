# Crash Monitoring (Crashlytics + Sentry) — Implementation Guide

## 1. Prerequisites
- `firebase-core-setup` complete
- Sentry account + project created (one Sentry project; `environment` tags differentiate dev/stg/prod)

## 2. Add packages

```bash
flutter pub add firebase_crashlytics sentry_flutter package_info_plus crypto
flutter pub add --dev sentry_dart_plugin
flutterfire reconfigure       # adds iOS dSYM upload run script
cd ios && pod install --repo-update
```

## 3. Wire bootstrap

Use [snippets/crash_bootstrap.dart](snippets/crash_bootstrap.dart). Key calls:
1. `FlutterError.onError` → both services.
2. `PlatformDispatcher.instance.onError` → both services.
3. `FirebaseCrashlytics.setCrashlyticsCollectionEnabled(!kDebugMode)` — gated by consent later.
4. `SentryFlutter.init(...)` with `appRunner: () => runApp(...)`.

DO NOT use `runZonedGuarded` (legacy pattern from pre-Flutter-3.3 tutorials — causes pitfall #10).

## 4. Sentry config keys

Pass via `--dart-define`:
- `SENTRY_DSN` — from Sentry project settings
- `APP_ENV` — `dev` | `stg` | `prod`

```bash
flutter run --flavor prod -t lib/main_prod.dart \
  --dart-define=SENTRY_DSN=https://xxx@sentry.io/123 \
  --dart-define=APP_ENV=prod
```

For EU data residency: use `https://*.de.sentry.io` DSN (Sentry EU region).

## 5. PII scrubber

Use [snippets/sentry_scrubber.dart](snippets/sentry_scrubber.dart). Strips:
- User email + IP
- Authorization, Cookie, X-API-Key headers
- `token`, `password`, `secret` query string params
- Request bodies entirely

## 6. Identify user (after login + consent)

Use [snippets/identify_user.dart](snippets/identify_user.dart). Always pass HASHED user IDs. Wire into your auth flow:
```dart
ref.listen(authStateProvider, (prev, next) {
  next.whenData((user) {
    if (user != null) {
      identifyCrashUser(user.uid);
    } else {
      clearCrashUser();
    }
  });
});
```

## 7. iOS — dSYM upload

`flutterfire configure` adds the upload script. Verify:
1. Open `ios/Runner.xcworkspace`.
2. Runner target → Build Phases → look for "Run Firebase Crashlytics Scripts" or "[firebase_crashlytics] Crashlytics Upload Symbols".
3. Build Settings → Debug Information Format → must be **DWARF with dSYM File** for Release.

For obfuscated builds (`--split-debug-info`), upload the symbols directory:
```bash
firebase crashlytics:symbols:upload \
  --app=1:1234567890:ios:abcdef123456 \
  build/symbols
```

## 8. Android — mapping (R8/ProGuard) upload

For obfuscated release builds:
1. `android/app/build.gradle.kts` ensure `firebaseCrashlytics { mappingFileUploadEnabled = true }`.
2. Build: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`.
3. Mapping auto-uploads via Crashlytics Gradle plugin.

For Sentry: `dart run sentry_dart_plugin` after build uploads both Android mapping AND Dart symbols.

## 9. Sentry symbol upload

[snippets/pubspec_sentry.yaml](snippets/pubspec_sentry.yaml) has the `sentry:` block. Build then run plugin:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
SENTRY_AUTH_TOKEN=xxx dart run sentry_dart_plugin
```

⚠ NEVER commit `SENTRY_AUTH_TOKEN`. Use CI secrets.

## 10. Test crash

```dart
// In a debug screen / hidden long-press menu:
ElevatedButton(
  onPressed: () => FirebaseCrashlytics.instance.crash(),
  child: const Text('Test Crashlytics'),
),
ElevatedButton(
  onPressed: () => Sentry.captureException(StateError('Test Sentry')),
  child: const Text('Test Sentry'),
),
```

Crashlytics: app must restart after crash. Wait 5 minutes. Check Firebase Console → Crashlytics.
Sentry: appears in Issues within 1 minute.

## 11. Verify

Run [checklist.md](checklist.md).

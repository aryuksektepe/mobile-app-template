# Secure Storage — Implementation Guide

## 1. Add packages

```bash
flutter pub add flutter_secure_storage local_auth mutex shared_preferences
cd ios && pod install --repo-update
```

## 2. Android setup

1. `android/app/build.gradle.kts`:
   ```kotlin
   android { defaultConfig { minSdk = 21 } }   // 23 if biometrics required
   ```
2. Replace `MainActivity.kt` per [snippets/MainActivity.kt](snippets/MainActivity.kt) — must extend `FlutterFragmentActivity` for local_auth's biometric sheet.
3. Add manifest entries from [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml):
   - `USE_BIOMETRIC` permission
   - `android:allowBackup="false"` and `android:fullBackupContent="false"`

## 3. iOS setup

1. `ios/Podfile`: `platform :ios, '12.0'` minimum.
2. `ios/Runner/Info.plist`: add `NSFaceIDUsageDescription` (required for Face ID prompt).
3. (Optional) Xcode → Capabilities → Keychain Sharing if sharing secrets with Notification Service Extension or watchOS app.

## 4. Wire fresh-install wipe

Run [snippets/fresh_install_wipe.dart](snippets/fresh_install_wipe.dart) ONCE at app start, BEFORE any read/write to secure storage.

In `bootstrap()`:
```dart
await ensureFreshInstallCleared();   // run before any token reads
```

This solves the iOS "previous user resurrected" trap (pitfall #1).

## 5. Wire SecureTokenRepository

Use [snippets/secure_token_repository.dart](snippets/secure_token_repository.dart). Provider auto-injectable. Always go through this repo — no scattered `FlutterSecureStorage()` instances.

## 6. Wire AuthInterceptor

Use [snippets/auth_interceptor.dart](snippets/auth_interceptor.dart) with your Dio client:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(AuthInterceptor(
  ref.read(tokenRepoProvider),
  (oldRefresh) async {
    final res = await Dio().post('https://api.example.com/auth/refresh',
        data: {'refresh_token': oldRefresh});
    return (
      access: res.data['access_token'] as String,
      refresh: res.data['refresh_token'] as String,
    );
  },
));
```

## 7. Logout — clear EVERYTHING

```dart
Future<void> signOut(WidgetRef ref) async {
  await ref.read(tokenRepoProvider).clearAll();
  await FirebaseMessaging.instance.deleteToken();   // optional but recommended
  await FirebaseAnalytics.instance.setUserId(id: null);
  await clearCrashUser();                             // from crash-monitor-dual skill
  // Sign out of any OAuth providers (Google, Apple) here.
  await ref.read(firebaseAuthProvider).signOut();
}
```

## 8. Biometric reauth pattern (for sensitive actions)

```dart
import 'package:local_auth/local_auth.dart';

final localAuth = LocalAuthentication();
final ok = await localAuth.authenticate(
  localizedReason: 'Hesabınızı silmek için kimliğinizi doğrulayın',
  options: const AuthenticationOptions(
    biometricOnly: true,
    stickyAuth: true,
  ),
);
if (!ok) throw const BiometricFailedException();
// Proceed with sensitive action (delete account, etc.)
```

Handle `LockedOutException` (5 failures, 30s soft) and `PermanentlyLockedOutException` (until passcode entered) — fall back to password prompt.

## 9. Verify

Run [checklist.md](checklist.md). Critical:
- Uninstall iOS app, reinstall: previous user is NOT logged in.
- Concurrent 401s from multiple parallel requests do NOT cause logout.
- Logout clears all entries (verify via Keychain Access app on iOS).

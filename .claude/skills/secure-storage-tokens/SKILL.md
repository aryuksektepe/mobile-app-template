---
name: secure-storage-tokens
description: flutter_secure_storage 10.x for auth tokens — Keychain (iOS) + Keystore-backed cipher (Android, post EncryptedSharedPreferences deprecation), biometric-protected reads, refresh-token mutex, fresh-install Keychain wipe (iOS persistence quirk), Dio interceptor pattern. Use whenever you store tokens, refresh tokens, or any sensitive secret on device.
triggers: [secure storage, flutter_secure_storage, keychain, keystore, biometric, refresh token, access token, jwt, bearer token, encrypted shared preferences, local_auth, sensitive data]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.19.0"
ios_min: "12.0"
android_min_sdk: 21
package_versions:
  flutter_secure_storage: "^10.1.0"
  local_auth: "latest"
  mutex: "^3.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Secure Storage — Tokens & Sensitive Data

## What this skill does

- Wires `flutter_secure_storage` 10.x with the v10 default cipher (Keystore-backed RSA-OAEP + AES-GCM on Android; Keychain on iOS).
- **Fresh-install Keychain wipe** on iOS (Keychain survives app uninstall — known security/UX trap).
- Refresh-token **mutex** to serialize concurrent refresh requests (prevents replay-revocation lockouts).
- Biometric-protected entries via Android `AndroidOptions.biometric` and iOS `KeychainAccessibility.passcode`.
- Dio interceptor that injects `Authorization: Bearer <token>` and refreshes on 401.
- Single `SecureTokenRepository` (Riverpod-injected) — single source of truth for all auth secrets.
- KVKK/GDPR-compliant logout: clears ALL token-related entries.

## What this skill does NOT do

- Does NOT store passwords/PINs (anti-pattern; store the **refresh token** instead).
- Does NOT replace server-side token rotation strategy.
- Does NOT implement biometric reauth UI flows — that's auth skill territory.

## Decision tree

**Q1: Tokens that should survive iCloud restore (cross-device handoff)?**
- YES → `KeychainAccessibility.first_unlock` (default).
- NO → `KeychainAccessibility.first_unlock_this_device` (recommended for refresh tokens — prevents account takeover via restored backup).

**Q2: Biometric protection on read?**
- YES (recommended for refresh tokens) → `AndroidOptions.biometric()` + `KeychainAccessibility.passcode_this_device`.
- NO → standard read (faster, no biometric prompt).

**Q3: Allow Android backup of secure storage?**
- NO (recommended) → `android:allowBackup="false"` in AndroidManifest. Prevents stale ciphertext restored to a different device.

## Quick start

```bash
flutter pub add flutter_secure_storage local_auth mutex
```

## Code patterns

| Need | File |
|---|---|
| SecureTokenRepository + Riverpod providers | [snippets/secure_token_repository.dart](snippets/secure_token_repository.dart) |
| Fresh-install Keychain wipe | [snippets/fresh_install_wipe.dart](snippets/fresh_install_wipe.dart) |
| Dio AuthInterceptor with refresh + retry | [snippets/auth_interceptor.dart](snippets/auth_interceptor.dart) |
| MainActivity (FlutterFragmentActivity) | [snippets/MainActivity.kt](snippets/MainActivity.kt) |
| AndroidManifest + Info.plist entries | [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml) |

For full setup (Android backup config, Face ID usage description, biometric lockout handling) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (14 entries). Top 5:
1. iOS uninstall doesn't clear Keychain → previous user re-logged-in on fresh install. Use `shared_preferences` first-launch sentinel.
2. `BadPaddingException` on Android after upgrade → Keystore key invalidated; catch + `deleteAll()` + force re-auth.
3. Concurrent refresh races → token rotation revokes both. Use a `Mutex` around refresh.
4. Plaintext password "for biometric auto-login" → anti-pattern; store refresh token.
5. iOS 16.3+ `read()` returns null → mismatched accessibility level between read/write. Pin one level via const provider.

## Verification

→ [checklist.md](checklist.md) (15 items: fresh install wiped, biometric prompt works, logout clears everything, Android backup disabled).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `flutter_secure_storage` 10.1.0
- Depends on: (none)

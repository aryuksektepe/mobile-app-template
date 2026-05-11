# Secure Storage — Verification Checklist

## Setup
- [ ] `flutter_secure_storage ^10.1.0` resolved
- [ ] `local_auth` + `mutex` + `shared_preferences` added
- [ ] iOS deployment target ≥ 12.0
- [ ] Android `minSdk = 21` (23 if biometrics)
- [ ] `MainActivity` extends `FlutterFragmentActivity`
- [ ] `android:allowBackup="false"` + `android:fullBackupContent="false"` in AndroidManifest
- [ ] iOS `NSFaceIDUsageDescription` in Info.plist

## Repository
- [ ] Single `secureStorageProvider` const-instance with pinned `KeychainAccessibility`
- [ ] All token reads/writes go through `SecureTokenRepository`
- [ ] `refreshIfNeeded` wrapped in Mutex
- [ ] `clearAll()` deletes ALL token-related keys

## Fresh-install wipe
- [ ] `ensureFreshInstallCleared()` runs at app start, BEFORE any read/write
- [ ] iOS test: install, sign in, uninstall, reinstall → previous user NOT logged in
- [ ] Sentinel persists across app restarts (only resets on uninstall)

## Auth interceptor
- [ ] Bearer token auto-injected on requests
- [ ] 401 triggers refresh + retry
- [ ] Refresh failure → clearAll + caller signs out
- [ ] No infinite retry on the refresh endpoint itself (`extra['skip_auth_retry']`)

## Concurrency
- [ ] Test: 10 parallel API calls all hitting 401 → only ONE refresh fires; user stays logged in
- [ ] Server-side: refresh token rotation has grace window for in-flight requests

## Biometric
- [ ] Biometric prompt appears via `local_auth.authenticate()` with FaceID description
- [ ] `LockedOutException` caught → fall back to password
- [ ] `KeyPermanentlyInvalidatedException` (Android, after biometric enrollment change) → force re-login

## Logout
- [ ] `signOut()` calls `repo.clearAll()`
- [ ] `signOut()` clears FCM token
- [ ] `signOut()` clears Crashlytics + Analytics user
- [ ] After logout: re-opening app shows login screen (NOT cached user data)

## Compliance
- [ ] Privacy policy lists secure storage usage
- [ ] No passwords or PINs stored in any form
- [ ] Tokens have reasonable TTL (access ~15 min, refresh ~30-90 days)
- [ ] iOS Keychain Sharing access groups used only if NSE/widget needs them

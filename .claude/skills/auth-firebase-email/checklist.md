# Firebase Auth (Email) — Verification Checklist

## Setup
- [ ] `firebase_auth ^6.4.0` resolved
- [ ] Email/Password enabled in Firebase Console
- [ ] Email enumeration protection decision documented in `.project/decisions.md`
- [ ] Password policy configured in Firebase Console
- [ ] SMTP custom sender domain configured (improves deliverability)
- [ ] Action URL points to Firebase Hosting custom domain (NOT page.link)

## Code wiring
- [ ] `AuthRepository` is the single source of truth (no scattered `FirebaseAuth.instance` calls)
- [ ] All exceptions mapped to typed `AuthException` subclasses
- [ ] `authStateProvider` used for routing, `userChangesProvider` for widgets

## Flows tested
- [ ] **Signup**: new email → user created + verification email sent
- [ ] **Signin**: valid creds → user signed in
- [ ] **Signin (wrong password)**: returns `InvalidCredentialsException` (NOT `wrong-password` text — enumeration protection working)
- [ ] **Signin (rate limited)**: 5+ rapid bad attempts → `RateLimitedException`
- [ ] **Email verification**: link from email opens app → emailVerified flips to true after `reloadAndCheckVerified()`
- [ ] **Password reset**: forgot-password email → user clicks link → can set new password → can sign in with it
- [ ] **Password change**: requires current password reauth → succeeds
- [ ] **Email change**: `verifyBeforeUpdateEmail` sends to NEW email; old email unchanged until link clicked + reload
- [ ] **Account linking**: anonymous user → email signup keeps same UID
- [ ] **Account deletion**: full flow runs → Auth user gone → Firestore data purged via Cloud Function within minutes

## Sensitive ops
- [ ] Biometric reauth works on iOS (Face ID prompt with usage description)
- [ ] Biometric reauth works on Android (FlutterFragmentActivity required)
- [ ] Stale session (>5 min) on password change → triggers reauth flow
- [ ] Reauth flow re-prompts password and retries the operation

## GoRouter integration
- [ ] Logged out → redirect to `/login` with `return=` param
- [ ] Logged in but unverified → redirect to `/verify`
- [ ] Logged in + verified + on `/login` → redirect to `/home`
- [ ] No infinite redirect loops

## Logout
- [ ] `signOut` clears: Firebase Auth + secure_storage + FCM token + Crashlytics user + Analytics user
- [ ] After logout, re-opening app shows `/login` (NOT cached user)

## Compliance
- [ ] Account deletion reachable in-app within 2 taps from Settings
- [ ] Confirmation copy explains 30-day finalization (KVKK + GDPR)
- [ ] Apple App Review: account deletion present (5.1.1(v) since Jun 2022)
- [ ] Play Console Data Safety form declares deletion path
- [ ] Cloud Function `onUserDelete` deployed AND verified via test deletion (check logs + Firestore)
- [ ] Audit log entry written to `deletionAudit` collection per deletion (hashed UID only)

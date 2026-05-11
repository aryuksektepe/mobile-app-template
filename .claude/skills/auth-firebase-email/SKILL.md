---
name: auth-firebase-email
description: Firebase Auth 6.x email/password — signup, signin, signout, email verification, password reset, password change, email change (verifyBeforeUpdateEmail), account linking, biometric reauth, KVKK/GDPR-compliant account deletion (Apple Jun 2022 + Play Dec 2023 mandate). Email enumeration protection handled. Riverpod auth state, GoRouter gate, error code mapping.
triggers: [firebase auth, firebase_auth, email password, signup, login, signin, sign in, logout, sign out, password reset, change password, change email, email verification, account linking, account deletion, delete account, biometric reauth]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.3.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  firebase_auth: "^6.4.0"
  local_auth: "latest"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup, secure-storage-tokens]
---

# Firebase Auth — Email/Password (+ Account Management)

## What this skill does

- Wires `firebase_auth` 6.x with Riverpod `authStateProvider` + `userChangesProvider`.
- AuthRepository with all email flows: signup, signin, signout, password reset, password change, email change, email verification.
- Maps every realistic `FirebaseAuthException` code to typed app exceptions (15+ codes covered).
- **Email enumeration protection** aware (default-on for projects created after 2023-09-15) — `wrong-password` + `user-not-found` merged into `invalid-credential`.
- **`verifyBeforeUpdateEmail`** (replaces deprecated `updateEmail` in v6).
- **Reauth flow** before sensitive actions (password/email change, account deletion).
- **Biometric reauth** via `local_auth` (cached encrypted credential pattern).
- **Account deletion** with Cloud Function trigger for data purge (KVKK Art. 7 / GDPR Art. 17 — 30-day deadline, mandatory in-app per Apple 5.1.1(v) Jun 2022 + Play Dec 2023).
- **Account linking** for anonymous → email upgrade.
- GoRouter route guard with email-verified gating.

## What this skill does NOT do

- Does NOT handle Google/Apple sign-in — see `auth-google-signin` and `auth-apple-signin` (linkable to email account via `linkWithCredential`).
- Does NOT manage SMS/MFA — separate scope.
- Does NOT deploy the data-purge Cloud Function — provides skeleton only.

## Decision tree

**Q1: Email enumeration protection ON or OFF?**
- ON (default for new projects, RECOMMENDED) — leaks no information about which emails are registered. BUT breaks anonymous→email account linking (pitfall #2). Mitigation in implementation.md.
- OFF — only disable if anonymous-upgrade flow is critical AND you accept the security tradeoff.

**Q2: Email verification required before signin?**
- YES (recommended for paid features) — gate with route guard checking `user.emailVerified`. Block sensitive actions until verified.
- NO — allow unverified to access core features; require verification later (e.g., before checkout).

**Q3: Email verification deeplink — handle in app or fallback to web?**
- IN APP (recommended) — better UX. Requires `deeplinks-go-router` + Firebase Hosting custom domain (Dynamic Links is dead).
- WEB — Firebase's hosted handler page; simpler but jarring.

## Quick start

```bash
flutter pub add firebase_auth local_auth
```

Firebase Console → Authentication → Sign-in method → Enable **Email/Password**.

## Code patterns

| Need | File |
|---|---|
| AuthRepository (all flows) | [snippets/auth_repository.dart](snippets/auth_repository.dart) |
| Riverpod auth providers | [snippets/auth_providers.dart](snippets/auth_providers.dart) |
| Typed exceptions | [snippets/auth_exceptions.dart](snippets/auth_exceptions.dart) |
| GoRouter auth gate | [snippets/auth_router_gate.dart](snippets/auth_router_gate.dart) |
| Account deletion (full purge) | [snippets/delete_account.dart](snippets/delete_account.dart) |
| Cloud Function: data purge on user delete | [snippets/onUserDelete.ts](snippets/onUserDelete.ts) |

For full setup (action code settings, password policy, Hosting deeplinks, Cloud Function deploy) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (16 entries). Top 5:
1. `wrong-password` and `user-not-found` no longer thrown — both return `invalid-credential` (enumeration protection). Map to generic message.
2. `linkWithCredential` for anonymous → email throws `operation-not-allowed` due to enumeration protection.
3. `user.email` stays old after `verifyBeforeUpdateEmail` — only flips after user clicks link AND `user.reload()` called.
4. `user.delete()` only removes auth record — must trigger Cloud Function to purge Firestore/Storage data.
5. Action code links return `invalid-action-code` — codes expire in 1 hour.

## Verification

→ [checklist.md](checklist.md) (18 items: signup/signin/reset/change all flows, account-deletion verified backend purge, biometric reauth works).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_auth` 6.4.0
- Depends on: `firebase-core-setup`, `secure-storage-tokens`

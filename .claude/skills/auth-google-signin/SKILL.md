---
name: auth-google-signin
description: Google Sign In v7+ with Firebase Auth (NEW initialize/authenticate/authorizationClient API — completely different from v6 and earlier). Multi-flavor SHA-1+SHA-256 (debug + upload + Play App Signing), serverClientId requirement, FedCM (mandatory Chrome 139+), separation of authentication vs authorization scopes, account linking, signOut vs disconnect.
triggers: [google sign in, google_sign_in, google login, sign in with google, federated identity, oauth google, fedcm]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.19.0"
ios_min: "12.0"
android_min_sdk: 21
package_versions:
  google_sign_in: "^7.2.0"
  firebase_auth: "^6.4.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup, auth-firebase-email]
---

# Google Sign In + Firebase Auth

## What this skill does

- Wires `google_sign_in` 7.x (NEW API: `initialize` + `authenticate` + `authorizationClient`).
- Bridges to Firebase Auth via `GoogleAuthProvider.credential(idToken: ..., accessToken: ...)`.
- Multi-flavor SHA management (debug + upload + Play App Signing fingerprints).
- `serverClientId` configuration (mandatory on Android since v7.1).
- Separates **authentication** (idToken — who they are) from **authorization** (accessToken — what Google APIs you can call).
- FedCM web flow (mandatory on Chrome 139+ since Aug 2025).
- Account linking + Apple guideline 4.8 enforcement (offer Sign-in with Apple alongside).
- `signOut` vs `disconnect` — when each.

## What this skill does NOT do

- Does NOT replace `auth-firebase-email` — typically apps offer BOTH email + Google.
- Does NOT cover Apple sign-in — see `auth-apple-signin` (mandatory pair with Google on iOS per guideline 4.8).
- Does NOT integrate Google Workspace org policy enforcement.

## Decision tree

**Q1: Need Google API access (Calendar, Contacts, Drive)?**
- YES → call `authorizationClient.authorizeScopes([...])` after `authenticate()`. Get accessToken.
- NO (just sign-in) → only need `idToken`. Don't request scopes (lighter consent screen).

**Q2: iOS app shipping → are you also implementing Sign in with Apple?**
- MUST be YES (Apple guideline 4.8). Apple rejects apps with social login but no SIWA. Implement `auth-apple-signin` skill in parallel.

**Q3: signOut vs disconnect on logout?**
- `signOut()` → clears local sign-in state. Account picker remembers user; one-tap sign-in next time.
- `disconnect()` → revokes the OAuth grant. User must explicitly authorize next time. Use this for "Hesabımı sil" flow.

## Quick start

```bash
flutter pub add google_sign_in
```

In Firebase Console → Authentication → Sign-in method → enable **Google** → note the auto-created **Web client ID** (this is your `serverClientId` for Android).

## Code patterns

| Need | File |
|---|---|
| GoogleAuthRepository (v7 API) | [snippets/google_auth_repository.dart](snippets/google_auth_repository.dart) |
| Initialize call in main() | [snippets/init_google_signin.dart](snippets/init_google_signin.dart) |
| Riverpod providers | [snippets/google_providers.dart](snippets/google_providers.dart) |
| Info.plist URL scheme entry | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |

For full setup (Android SHA reg, FedCM web, Workspace org policies) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (17 entries). Top 5:
1. Code 12500 on Android release: SHA mismatch — Play App Signing has different cert than upload.
2. `clientConfigurationError` on first call: forgot to await `initialize()`.
3. `serverClientId is required on Android` (v7.1+) — pass Web OAuth client ID, NOT Android client ID.
4. `account-exists-with-different-credential` — user has email account; link Google via `linkWithCredential`.
5. Apple guideline 4.8 rejection: implement Sign in with Apple too.

## Verification

→ [checklist.md](checklist.md) (15 items: works on debug + release + Play, account picker UX, account linking, disconnect on delete).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `google_sign_in` 7.2.0
- Depends on: `firebase-core-setup`, `auth-firebase-email`

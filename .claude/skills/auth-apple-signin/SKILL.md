---
name: auth-apple-signin
description: Sign in with Apple 8.x + Firebase Auth — nonce dance (SHA256 to Apple, raw to Firebase), name capture race condition (Apple returns name only on FIRST sign-in — must persist immediately), Hide-My-Email relay handling, Apple token revocation (App Review enforces this on account deletion), Service ID setup for Android/Web. Mandatory if you offer Google or other social login on iOS (guideline 4.8).
triggers: [apple sign in, sign in with apple, siwa, sign_in_with_apple, apple id, hide my email, apple revoke, oauth apple]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.41.0"
ios_min: "13.0"
android_min_sdk: 21
package_versions:
  sign_in_with_apple: "^8.0.0"
  crypto: "^3.0.3"
  firebase_auth: "^6.4.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup, auth-firebase-email]
---

# Sign in with Apple + Firebase Auth

## What this skill does

- Wires `sign_in_with_apple` 8.0.0 + Firebase Auth via `OAuthProvider("apple.com")`.
- **Nonce dance** correctly: generate raw nonce → SHA256 → pass hash to Apple → pass raw to Firebase. Mismatch = `invalid-credential`.
- **Name capture immediately** on first sign-in (Apple returns name only ONCE per Apple ID + app combo — most common bug).
- **Hide-My-Email relay** handling — register sender domain with Apple for deliverability.
- **Token revocation** on account deletion — Apple App Review actively tests this; absence = rejection.
- Service ID setup for Android + Web (uses web flow, not native).
- Account linking with existing email/Google accounts.

## What this skill does NOT do

- Does NOT replace Apple Developer Program membership requirement (paid, $99/yr — Apple service is restricted).
- Does NOT cover the Cloud Function for server-side token verification (provides client + revocation REST patterns only).

## Decision tree

**Q1: iOS-only or also Android/Web?**
- iOS-only → simpler. Native flow uses App ID directly.
- Android/Web → also need Service ID + Domain + Return URL configured in Apple Developer portal.

**Q2: Persist authorizationCode for revocation?**
- YES (mandatory if you offer in-app account deletion) — store on first sign-in via Cloud Function. Revoke on delete. Without this, App Review rejects.

**Q3: Force re-sign-in to get fresh authorizationCode for delete?**
- YES (recommended). The first-sign-in's authorizationCode is short-lived. Trigger a fresh sign-in inside the delete flow to get a usable code.

## Quick start

```bash
flutter pub add sign_in_with_apple crypto
```

Apple Developer Portal → enable Sign in with Apple capability on App ID + create Service ID (if Android/Web) + create Key.

## Code patterns

| Need | File |
|---|---|
| AppleAuthRepository (nonce + name + persist) | [snippets/apple_auth_repository.dart](snippets/apple_auth_repository.dart) |
| Riverpod providers | [snippets/apple_providers.dart](snippets/apple_providers.dart) |
| Account deletion w/ token revoke | [snippets/apple_delete.dart](snippets/apple_delete.dart) |
| Cloud Function: revoke Apple token | [snippets/revokeAppleToken.ts](snippets/revokeAppleToken.ts) |

For full setup (Apple Developer console steps, Xcode capabilities, Service ID for Android, JWT client secret for revoke) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (18 entries). Top 5:
1. `invalid OAuth response from apple.com` — nonce mismatch (sent SHA256 to Apple but raw to Firebase, or vice versa).
2. `displayName` always null after first sign-in — Apple returns name ONLY on first sign-in. If save fails, gone forever. Test by removing app from "Apps Using Apple ID" in Settings.
3. App Review rejection — guideline 5.1.1(v) requires `revokeToken` call before `user.delete()`.
4. Hide-My-Email emails bouncing — sender domain not registered with Apple's relay.
5. Android web flow `Invalid OAuth response` — Service ID misconfigured (Domains AND Return URLs).

## Verification

→ [checklist.md](checklist.md) (17 items: nonce verified, name captured first time, revoke called on delete, Hide-My-Email deliverability tested).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `sign_in_with_apple` 8.0.0
- Depends on: `firebase-core-setup`, `auth-firebase-email`

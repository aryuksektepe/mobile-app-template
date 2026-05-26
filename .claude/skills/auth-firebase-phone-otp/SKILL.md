---
name: auth-firebase-phone-otp
description: Phone OTP authentication via Firebase Auth — SMS verification flow with reCAPTCHA fallback (iOS, web), Play Integrity API (Android, supersedes SafetyNet), test phone numbers for dev, SMS rate limits + auto-retrieval (Android), paste-from-clipboard, country code picker, account linking with email/Google/Apple. Mandatory for TR/EM markets where phone-first auth is the norm.
triggers: [phone auth, phone otp, sms verification, firebase phone, verifyPhoneNumber, signInWithPhoneNumber, reCAPTCHA, play integrity, safetynet deprecated, otp paste, country code picker, sms rate limit, test phone number, sms auto retrieve]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  firebase_auth: "^6.0.0"
  country_code_picker: "^3.1.0"
  pinput: "^5.0.1"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup, auth-firebase-email]
---

# Phone OTP Authentication (Firebase)

## What this skill does

- Wires `FirebaseAuth.verifyPhoneNumber()` with the FlutterFire 6.x API (callback model — `codeSent`, `verificationCompleted`, `verificationFailed`, `codeAutoRetrievalTimeout`).
- Android: Play Integrity API (replaces deprecated SafetyNet); enable in Firebase Console.
- iOS: reCAPTCHA fallback when silent push verification fails (most simulator runs, some real devices).
- SMS auto-retrieval on Android via SMS Retriever API (no SMS permission needed — uses app hash).
- 6-digit OTP UI with `pinput` (paste-from-clipboard support).
- Country code picker with `country_code_picker` (TR default, IDD format `+90 555 123 4567`).
- Account linking with email/Google/Apple (per `auth-firebase-email`).
- Test phone numbers for dev (`+90 555 000 0000` returning fixed code `123456` — bypasses real SMS).

## What this skill does NOT do

- Does NOT handle SMS template / branding (Firebase sends standard format).
- Does NOT cover WhatsApp OTP / SMS providers other than Firebase.

## Decision tree

**Q1: Phone-only or phone + email/social?**
- PHONE-ONLY — simpler; users can't recover if they lose number.
- PHONE + LINKED (recommended) — link to email/Apple/Google so number rotation is recoverable.

**Q2: Allow web?**
- YES — reCAPTCHA required (Firebase auto-handles via invisible challenge).
- NO — mobile-only via Play Integrity (Android) + silent push (iOS).

## Quick start

```bash
flutter pub add firebase_auth country_code_picker pinput
```

1. Firebase Console → Authentication → Sign-in method → Phone → enable.
2. Android: Project Settings → App Check → Play Integrity → enable.
3. iOS: Project Settings → Cloud Messaging → APNs auth key uploaded (silent push needs APNs).
4. iOS: in Capabilities, enable Background Modes → Remote notifications + Push Notifications.
5. Apply [snippets/phone_auth_service.dart](snippets/phone_auth_service.dart) + the OTP UI snippet.

## Code patterns

| Need | File |
|---|---|
| Phone auth service + state machine | [snippets/phone_auth_service.dart](snippets/phone_auth_service.dart) |
| OTP entry UI (pinput + countdown + paste) | [snippets/otp_screen.dart](snippets/otp_screen.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. iOS: silent push verification fails on simulator → reCAPTCHA fallback NOT enabled → flow dies.
2. Android: Play Integrity not configured → every verifyPhoneNumber returns `app-not-authorized`.
3. Test phone numbers stop working in PROD app (only DEV Firebase project).
4. SMS auto-retrieval fails because app hash mismatch (release vs debug signing).
5. Same phone retries 5+ times in dev → Firebase rate-limits the project for hours.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: `firebase-core-setup`, `auth-firebase-email` (account linking)

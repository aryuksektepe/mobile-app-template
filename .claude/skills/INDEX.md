# Skills Index — read this BEFORE writing any implementation code

> **coder ZORUNLU bunu okumalı.** Her task için: tokenize → score against `Triggers` → match → open SKILL.md → follow verbatim.
> Match yoksa: implement from scratch, slug'ı phase frontmatter'da `skills_to_extract:`'e ekle.

**Last updated:** 2026-05-10
**Total skills:** 13 pre-seeded, 0 battle-tested (plus `_example-skill-template` for reference)

> **Validation status legend:**
> - `pre-seeded` — written from research, NOT yet validated in a real project. Treat as ADAPT not VERBATIM. Append findings to skill's pitfalls.md after first use.
> - `battle-tested` — verified across ≥2 successful real-project uses with no surprises. Use VERBATIM.

---

## How to use

**For coder agent:**

1. Read this file at the start of every task.
2. Tokenize task description (e.g. "add Apple Sign In to login screen").
3. Score each row's `Triggers` against tokens.
4. If any score ≥3 with scope match → open SKILL.md, follow verbatim.
5. Score 1-2 + structurally relevant → adapt (copy structure, swap domain types). Log near-miss in phase `skills_to_extract`.
6. Score 0 → implement from scratch. If you wrote a non-trivial pattern that recurs ≥2 times, add to `skills_to_extract`.

**Staleness check:** if `Last Verified` is >180 days, treat as ADAPT-not-VERBATIM. Add `near-miss: <slug> (stale)` to your phase notes — skill-extractor will refresh.

**Skill creation:** never bypass skill-extractor. Don't manually edit this file or skill directories during a regular phase — only skill-extractor does that on `SKILL_EXTRACTED` state.

---

## Auth & Identity

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`auth-firebase-email`](auth-firebase-email/SKILL.md) | Email/password — signup, signin, signout, email verification, password reset, password change, account linking, biometric reauth, KVKK-compliant account deletion | firebase auth, email password, signup, login, signin, logout, password reset, change password, change email, email verification, account deletion, biometric reauth | ios, android | 2026-05-10 | pre-seeded |
| [`auth-google-signin`](auth-google-signin/SKILL.md) | Google Sign In v7+ (NEW initialize/authenticate API) — multi-flavor SHA, serverClientId, FedCM, signOut vs disconnect | google sign in, google_sign_in, google login, federated identity, fedcm | ios, android | 2026-05-10 | pre-seeded |
| [`auth-apple-signin`](auth-apple-signin/SKILL.md) | Sign in with Apple 8.x + Firebase — nonce dance, name capture race, Hide-My-Email, token revocation (App Review enforces). Mandatory if offering Google on iOS (4.8) | apple sign in, sign in with apple, siwa, hide my email, apple revoke | ios, android | 2026-05-10 | pre-seeded |

## Notifications

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`notifications-fcm`](notifications-fcm/SKILL.md) | Push (FCM) + local notifications + permission soft-ask + foreground/bg/terminated handling + deep-link routing + token rotation. iOS APNs auth key, Android 13+ POST_NOTIFICATIONS, OEM battery quirks | notification, push notification, fcm, firebase_messaging, apns, local notification, notification permission, notification deeplink | ios, android | 2026-05-10 | pre-seeded |

## Payments & Subscriptions

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`subs-revenuecat`](subs-revenuecat/SKILL.md) | RevenueCat 10.x subscriptions/IAP — init, App Store + Play setup, Riverpod entitlement provider, paywalls v2, webhook server, account-deletion compliance | revenuecat, purchases_flutter, subscription, in-app purchase, iap, paywall, entitlement, restore purchases, storekit, play billing | ios, android | 2026-05-10 | pre-seeded |
| [`promo-codes-system`](promo-codes-system/SKILL.md) | Own server-side promo codes (NOT App Store offer codes) — Firestore + Cloud Functions, Crockford Base32, atomic transaction, App Check + rate limit, referral two-sided | promo code, promotional code, invite code, referral code, discount code, redemption, gift code, trial unlock | ios, android | 2026-05-10 | pre-seeded |

## Storage & State

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`secure-storage-tokens`](secure-storage-tokens/SKILL.md) | flutter_secure_storage 10.x — Keychain (iOS) + Keystore (Android), biometric-protected, refresh-token mutex, fresh-install Keychain wipe, Dio interceptor | secure storage, flutter_secure_storage, keychain, keystore, biometric, refresh token, access token, jwt | ios, android | 2026-05-10 | pre-seeded |

## Compliance & Security

> No standalone skill yet. KVKK/GDPR/MASVS controls live inside the relevant
> domain skills: `auth-firebase-email` (account deletion + 30-day purge),
> `secure-storage-tokens` (token at-rest encryption), `analytics-firebase`
> (Consent Mode v2), `crash-monitor-dual` (PII scrubbing), `notifications-fcm`
> (marketing opt-out), `subs-revenuecat` (RC user delete REST).

## Analytics & Observability

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`analytics-firebase`](analytics-firebase/SKILL.md) | Firebase Analytics (GA4) — event taxonomy, user properties, Consent Mode v2 (KVKK/GDPR), DebugView, BigQuery, ATT coordination | analytics, firebase_analytics, ga4, event tracking, user property, consent mode, debugview, screen tracking | ios, android | 2026-05-10 | pre-seeded |
| [`crash-monitor-dual`](crash-monitor-dual/SKILL.md) | Crashlytics + Sentry dual setup — PII scrubbing, opaque user IDs, dSYM/source maps, release tagging | crashlytics, sentry, crash report, error tracking, dsym, obfuscation, source map, performance monitoring, breadcrumbs | ios, android | 2026-05-10 | pre-seeded |
| [`remote-config-firebase`](remote-config-firebase/SKILL.md) | Firebase Remote Config — feature flags, A/B test, kill switches, force-update gate, real-time updates | remote config, feature flag, ab test, kill switch, force update, paywall variant, dynamic config | ios, android | 2026-05-10 | pre-seeded |

## Forms & UI Patterns

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`onboarding-flow`](onboarding-flow/SKILL.md) | First-launch onboarding — 3-5 page PageView, A/B variant, soft-ask permission pattern, deep-link replay, accessibility | onboarding, intro screens, walkthrough, first launch, welcome screen, soft ask, permission rationale | ios, android | 2026-05-10 | pre-seeded |

## Networking & Sync

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`deeplinks-go-router`](deeplinks-go-router/SKILL.md) | Universal Links + App Links + go_router 17.x — AASA + assetlinks hosting, multi-flavor SHA, sanitization, return-to. Firebase Dynamic Links DEAD as of Aug 25 2025 | deep link, deeplink, universal link, app link, go_router, app_links, aasa, assetlinks | ios, android | 2026-05-10 | pre-seeded |

## DevOps & CI/CD

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`firebase-core-setup`](firebase-core-setup/SKILL.md) | FlutterFire foundation — flutterfire_cli, multi-flavor (dev/stg/prod) Firebase projects, App Check (Play Integrity + DeviceCheck) | firebase, flutterfire, firebase init, firebase setup, firebase_core, flavor, app check, google-services.json, GoogleService-Info.plist | ios, android | 2026-05-10 | pre-seeded |

---

## Dependency graph

```
firebase-core-setup           (foundation — all Firebase skills depend on this)
├── analytics-firebase
├── crash-monitor-dual
├── remote-config-firebase
├── notifications-fcm
├── auth-firebase-email
│   ├── auth-google-signin
│   └── auth-apple-signin
└── promo-codes-system           (also depends on deeplinks-go-router + subs-revenuecat)

secure-storage-tokens             (independent foundation)
└── used by auth-firebase-email + onboarding-flow + auth interceptors

deeplinks-go-router               (independent foundation)
└── used by promo-codes-system + onboarding-flow + email-link callback (manual wiring in auth-firebase-email)

subs-revenuecat                   (independent — does not depend on Firebase)
└── used by promo-codes-system (paid promotional grants via RC REST)

onboarding-flow                   (depends on secure-storage-tokens + remote-config-firebase)
```

**Recommended Phase 01 order** (foundations first):
1. `firebase-core-setup`
2. `secure-storage-tokens`
3. `analytics-firebase`
4. `crash-monitor-dual`
5. `remote-config-firebase`
6. `deeplinks-go-router`

**Recommended Phase 02 order** (auth):
7. `auth-firebase-email`
8. `auth-google-signin` (if needed)
9. `auth-apple-signin` (if Google offered on iOS)
10. `onboarding-flow`

**Recommended later phases** (per feature):
11. `notifications-fcm`
12. `subs-revenuecat`
13. `promo-codes-system`

---

## Template / Examples

- `_example-skill-template/` — reference structure for what a skill directory should contain. NOT a real skill (don't match against it).

---

## How skills get added

1. coder works on a phase, encounters a reusable pattern
2. coder adds entry to phase frontmatter `skills_to_extract:`
3. After phase reaches CHRONICLED, skill-extractor evaluates per its §3 criteria (≥2 signals, generic, verified)
4. If extract → directory created, this INDEX updated, row added to correct domain section
5. Future coders read this INDEX, find matching skill, apply verbatim → token savings + consistency

## Promotion: pre-seeded → battle-tested

After a skill is used in **2 successful real-project deployments** with no surprises:
1. Update `validation_status: battle-tested` in its `SKILL.md` frontmatter.
2. Update Status column here.
3. Bump `recurrence_count`.

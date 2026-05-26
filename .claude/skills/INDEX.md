# Skills Index — read this BEFORE writing any implementation code

> **coder ZORUNLU bunu okumalı.** Her task için: tokenize → score against `Triggers` → match → open SKILL.md → follow verbatim.
> Match yoksa: implement from scratch, slug'ı phase frontmatter'da `skills_to_extract:`'e ekle.

**Last updated:** 2026-05-26
**Total skills:** 42 pre-seeded, 0 battle-tested (plus `_example-skill-template` for reference)

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
| [`auth-firebase-phone-otp`](auth-firebase-phone-otp/SKILL.md) | Phone OTP — SMS verification, reCAPTCHA fallback (iOS), Play Integrity (Android), test phone numbers, SMS auto-retrieval, country code picker, account linking. TR/EM markets staple | phone auth, phone otp, sms verification, firebase phone, verifyPhoneNumber, reCAPTCHA, play integrity, otp paste, country code picker, sms rate limit | ios, android | 2026-05-26 | pre-seeded |

## Compliance & Security

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`ios-att-prompt`](ios-att-prompt/SKILL.md) | App Tracking Transparency flow — pre-prompt + ATT timing + IDFA gating + Consent Mode v2 coordination. Apple Guideline 5.1.2(i) | att, app tracking transparency, idfa, NSUserTrackingUsageDescription, ATTrackingManager, consent mode v2, IDFA opt-in | ios | 2026-05-26 | pre-seeded |
| [`ios-privacy-manifest`](ios-privacy-manifest/SKILL.md) | PrivacyInfo.xcprivacy — required since May 1 2024. Data types + tracking domains + Required Reason API + third-party SDK signatures | privacy manifest, PrivacyInfo.xcprivacy, NSPrivacyAccessedAPITypes, required reason api, ITMS-91056, ITMS-91065 | ios | 2026-05-26 | pre-seeded |
| [`account-deletion-cross-cutting`](account-deletion-cross-cutting/SKILL.md) | 9-step orchestrated deletion across auth + RC + FCM + analytics + Crashlytics + secure storage + Drift. Apple 5.1.1(v) + Play mandate | account deletion, delete my account, KVKK silme, GDPR erasure, 5.1.1(v), data deletion, scrub user data | ios, android | 2026-05-26 | pre-seeded |
| [`certificate-pinning-dio`](certificate-pinning-dio/SKILL.md) | Public-key (SPKI) pinning via Dio — primary + backup pin, debug bypass, fail-closed on MITM, rotation runbook. MASVS-NETWORK-1 | certificate pinning, public key pinning, ssl pinning, MITM, MASVS, badCertificateCallback, pin rotation | ios, android | 2026-05-26 | pre-seeded |

## Notifications

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`notifications-fcm`](notifications-fcm/SKILL.md) | Push (FCM) + local notifications + permission soft-ask + foreground/bg/terminated handling + deep-link routing (incl. non-Home tab via shell) + token rotation. iOS APNs `.p8`, Android 13+ POST_NOTIFICATIONS, OEM battery, push-route allowlist | notification, push notification, fcm, firebase_messaging, apns, local notification, notification permission, notification deeplink, notification tab routing | ios, android | 2026-05-18 | pre-seeded |

## Payments & Subscriptions

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`subs-revenuecat`](subs-revenuecat/SKILL.md) | RevenueCat 10.x — init, App Store + Play setup, Riverpod entitlement, paywalls v2, webhook server, account-deletion compliance | revenuecat, purchases_flutter, subscription, in-app purchase, iap, paywall, entitlement, restore purchases, storekit, play billing | ios, android | 2026-05-10 | pre-seeded |
| [`promo-codes-system`](promo-codes-system/SKILL.md) | OWN server-side promo codes (NOT App Store offer codes) — Firestore + Cloud Functions, Crockford Base32, atomic transaction, App Check + rate limit, two-sided referral | promo code, promotional code, invite code, referral code, discount code, redemption, gift code, trial unlock | ios, android | 2026-05-10 | pre-seeded |

## Storage & State

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`secure-storage-tokens`](secure-storage-tokens/SKILL.md) | flutter_secure_storage 10.x — Keychain/Keystore, biometric-protected, refresh-token mutex, fresh-install Keychain wipe, Dio interceptor | secure storage, flutter_secure_storage, keychain, keystore, biometric, refresh token, access token, jwt | ios, android | 2026-05-10 | pre-seeded |

## Riverpod & Lifecycle

> Class (A) from the launch-smoke post-mortem: lifecycle/stream bugs invisible to single-build mocked tests, only manifest in a running app. Pair with `flutter-build-boot-gate`.

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`riverpod-2x-disposed-flag-guard`](riverpod-2x-disposed-flag-guard/SKILL.md) | Manual `_disposed` flag in `build()` → infinite rebuild loop. Use `ref.mounted`, keep build() pure | riverpod disposed flag, _disposed latch, ref.onDispose rebuild, notifier reuse, onboarding infinite loop, rebuild loop | ios, android | 2026-05-16 | pre-seeded |
| [`riverpod-autodispose-chain-churn`](riverpod-autodispose-chain-churn/SKILL.md) | autoDispose chain → ~30 req/s storm. keepAlive the right nodes; audit | autoDispose churn, request storm, keepAlive, ref.watch keepAlive, re-subscribe loop, provider recreated every rebuild | ios, android | 2026-05-16 | pre-seeded |
| [`riverpod-fetch-then-subscribe-yield`](riverpod-fetch-then-subscribe-yield/SKILL.md) | `async*` initial fetch not `yield`'d → UI empty until realtime event. yield snapshot then yield* updates | async* provider, stream provider, fetch then subscribe, yield* missing, await result discarded, realtime empty until event | ios, android | 2026-05-16 | pre-seeded |

## Models & Codegen

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`freezed-json-serializable`](freezed-json-serializable/SKILL.md) | freezed 3.x sealed unions + json_serializable patterns — @JsonKey snake_case, custom converters (DateTime/Enum), @Default null-safe, build_runner workflow, code-gen drift catching | freezed, json_serializable, sealed class, sealed union, when map, @Default, @JsonKey, build_runner watch, codegen, .g.dart, .freezed.dart, copyWith | ios, android | 2026-05-26 | pre-seeded |
| [`regen-clean-after-diagnostics`](regen-clean-after-diagnostics/SKILL.md) | CI generated-clean gate green — pre-push build_runner regen, deterministic generated artifacts, batch-push CI economy | generated diff fails CI, build_runner not clean, .g.dart drift, generated-clean gate, non-deterministic codegen, CI minute budget | ios, android | 2026-05-16 | pre-seeded |

## Analytics & Observability

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`analytics-firebase`](analytics-firebase/SKILL.md) | GA4 — event taxonomy, user properties, Consent Mode v2 (KVKK/GDPR), DebugView, BigQuery, ATT coordination | analytics, firebase_analytics, ga4, event tracking, user property, consent mode, debugview, screen tracking | ios, android | 2026-05-10 | pre-seeded |
| [`crash-monitor-dual`](crash-monitor-dual/SKILL.md) | Crashlytics + Sentry dual — PII scrubbing, opaque user ID, dSYM upload, release tagging | crashlytics, sentry, crash report, error tracking, dsym, obfuscation, source map, performance monitoring, breadcrumbs | ios, android | 2026-05-10 | pre-seeded |
| [`remote-config-firebase`](remote-config-firebase/SKILL.md) | Feature flag, A/B, kill switch, force-update gate, real-time updates | remote config, feature flag, ab test, kill switch, force update, paywall variant, dynamic config | ios, android | 2026-05-10 | pre-seeded |

## Forms, UI & Layout

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`onboarding-flow`](onboarding-flow/SKILL.md) | İlk açılış — 3-5 sayfa PageView, A/B variant, soft-ask permission pattern, deep-link replay | onboarding, intro screens, walkthrough, first launch, welcome screen, soft ask, permission rationale | ios, android | 2026-05-10 | pre-seeded |
| [`responsive-adaptive-layout`](responsive-adaptive-layout/SKILL.md) | RenderFlex overflow / küçük-büyük telefon / tablet / foldable / OS text scale. M3 window size classes + clamped textScaler + size×textScale golden matrix | responsive, adaptive layout, RenderFlex overflow, overflowed by pixels, screen size, small phone, tablet, foldable, split screen, MediaQuery.sizeOf, LayoutBuilder, breakpoint, window size class, text scale, textScaler, font size accessibility, dynamic type, large font | ios, android | 2026-05-17 | pre-seeded |
| [`splash-and-launcher-icon`](splash-and-launcher-icon/SKILL.md) | flutter_native_splash 2.x + flutter_launcher_icons 0.14+ — Android 12+ splash API, iOS launch storyboard, dark variants, RTL, adaptive Android icons, light/dark iOS App Icon | splash screen, native splash, launch screen, flutter_native_splash, launcher icon, app icon, flutter_launcher_icons, adaptive icon, android 12 splash, white flash, monochrome icon | ios, android | 2026-05-26 | pre-seeded |

## Networking & Sync

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`deeplinks-go-router`](deeplinks-go-router/SKILL.md) | Universal Links + App Links + go_router 17.x — AASA/assetlinks hosting, multi-flavor SHA, sanitization, custom scheme -10814, dual-Router black screen, `app_links` #if DEBUG cold-start trap. FDL DEAD | deep link, deeplink, universal link, app link, go_router, app_links, aasa, assetlinks, custom url scheme, CFBundleURLTypes, black screen deeplink | ios, android | 2026-05-18 | pre-seeded |
| [`gorouter-statefulshell-deeplink`](gorouter-statefulshell-deeplink/SKILL.md) | StatefulShellRoute tab branch deep-link/push switching — process-global shell holder + `goBranch(idx, initialLocation: idx==currentIndex)`, pure redirect, bounded cold-start handshake, `!identical` vs value-`!=` guard | go_router redirect crash, StatefulShellRoute deeplink, cold start deeplink, push tap routing, modified provider during build, branch not switching, goBranch, push lands on home | ios, android | 2026-05-18 | pre-seeded |
| [`dio-interceptor-stack`](dio-interceptor-stack/SKILL.md) | Production Dio interceptor chain — auth header, 401 refresh-token mutex (no token storm), exponential retry, PII-scrubbed logging, cancel tokens, base URL per flavor | dio, dio interceptor, retry interceptor, 401 refresh, refresh token mutex, request logging, cancel token, dio queued lock, expired access token | ios, android | 2026-05-26 | pre-seeded |
| [`connectivity-offline-ux`](connectivity-offline-ux/SKILL.md) | `connectivity_plus` 6.x — Riverpod stream, global offline banner, queued ops on reconnect, "interface vs internet reachability" distinction (captive portal trap) | connectivity, connectivity_plus, offline, online, no internet, network status, offline banner, retry on reconnect, queued operation, captive portal | ios, android | 2026-05-26 | pre-seeded |

## DevOps & CI/CD

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`firebase-core-setup`](firebase-core-setup/SKILL.md) | FlutterFire — flutterfire_cli, multi-flavor (dev/stg/prod) Firebase projects, App Check (Play Integrity + DeviceCheck) | firebase, flutterfire, firebase init, firebase setup, firebase_core, flavor, app check, google-services.json, GoogleService-Info.plist | ios, android | 2026-05-10 | pre-seeded |
| [`flutter-build-boot-gate`](flutter-build-boot-gate/SKILL.md) | Compile + first-boot smoke gate every phase + CI — BOOT_OK marker harness; the `INTEGRATION_SMOKE` gate's core | build gate, boot smoke, does it run, flutter build apk, walking skeleton, app launches, integration_test boot, INTEGRATION_SMOKE, BOOT_OK | ios, android | 2026-05-16 | pre-seeded |
| [`ios-android-hardening`](ios-android-hardening/SKILL.md) | Release hardening — `--obfuscate --split-debug-info`, R8/ProGuard keep rules (Firebase/Drift/freezed/RC), iOS Strip Style + Symbols upload, verify-release-shrinking gate | proguard, r8, obfuscation, split debug info, release crash, NoSuchMethodError release, shrinking broke, app size reduce, strip symbols, dsym upload, hardening | ios, android | 2026-05-26 | pre-seeded |

## Backend & Data Contracts

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`drift-schema-migrations`](drift-schema-migrations/SKILL.md) | Drift schema + migrations — append-only discipline, schema dump per version + generated upgrade tests, FK PRAGMA, type converters (Enum/DateTime/JSON), transactions | drift, schema migration, schemaVersion, onUpgrade, type converter, custom statement, FK pragma, drift json column, drift transaction | ios, android | 2026-05-26 | pre-seeded |
| [`supabase-rls-client-contract`](supabase-rls-client-contract/SKILL.md) | Every client write path must have integration-tested RLS/RPC. SECURITY DEFINER own-row upsert pattern | supabase write, RLS policy, column guard, security definer, rpc, violates row-level security | ios, android | 2026-05-16 | pre-seeded |
| [`supabase-read-through-cache-mirror`](supabase-read-through-cache-mirror/SKILL.md) | Cache miss → remote → mirror backfill; else fresh user sees "nothing here yet" forever | read-through cache, cache miss remote fallback, listX returns empty, drift mirror, offline-first read | ios, android | 2026-05-16 | pre-seeded |
| [`supabase-progress-aggregation-trigger`](supabase-progress-aggregation-trigger/SKILL.md) | Client appends events → server trigger/RPC/cron rolls up; else totals/streaks stay zero | progress_events, aggregation, rollup, streak zero, totals not updating, server-side writer, postgres trigger | ios, android | 2026-05-16 | pre-seeded |
| [`supabase-functions-client-contract-parity`](supabase-functions-client-contract-parity/SKILL.md) | Client↔Edge HTTP method + body field-name parity. Fixes POST-vs-GET, `otp_token` prod-dead bugs | functions.invoke, edge function contract, POST vs GET, otp_token, body field mismatch, req.method 405 | ios, android | 2026-05-16 | pre-seeded |
| [`supabase-local-verify-jwt-es256-hs256`](supabase-local-verify-jwt-es256-hs256/SKILL.md) | Local stack runbook — 401 verify_jwt ES256↔HS256, db-reset FK trap, realtime publication, CORS-preflight | edge function 401, verify_jwt, ES256 HS256, local supabase 401, JWT algorithm mismatch, local stack runbook | ios, android | 2026-05-16 | pre-seeded |

## Updates & Lifecycle

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`force-update-gate`](force-update-gate/SKILL.md) | Force/soft update flow via Remote Config minimum_version + recommended_version, blocking modal, store deep link, staged rollout | force update, soft update, minimum version, update gate, kill switch, version check, app update, store deep link | ios, android | 2026-05-26 | pre-seeded |

## Permissions & Platform

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`permission-handler-centralized`](permission-handler-centralized/SKILL.md) | Centralized PermissionService via `permission_handler` 11.x — soft-ask, just-in-time, settings deep link, iOS Info.plist usage strings, Android 13+ POST_NOTIFICATIONS, Android 14 partial photo access | permission, permission_handler, runtime permission, camera permission, location permission, photos permission, just in time permission, soft ask, settings deep link, openAppSettings, permanentlyDenied | ios, android | 2026-05-26 | pre-seeded |

## Background & Media

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`background-tasks-workmanager`](background-tasks-workmanager/SKILL.md) | workmanager 0.6+ — iOS BGAppRefreshTask + Android WorkManager. Periodic sync, constraints, exponential backoff. NOT real-time. OEM battery reality | background task, workmanager, BGAppRefreshTask, BGProcessingTask, periodic work, background sync, deferred work, OEM battery, doze mode | ios, android | 2026-05-26 | pre-seeded |
| [`media-picker-upload`](media-picker-upload/SKILL.md) | image_picker → crop → compress → Firebase/Supabase Storage upload. iOS Info.plist, Android 13+ READ_MEDIA_*, EXIF orientation fix, partial photo access | image picker, image_picker, camera, gallery, photo upload, firebase storage, supabase storage, exif orientation, image rotation, file size limit, image crop | ios, android | 2026-05-26 | pre-seeded |

## WebView & Engagement

| Slug | Purpose | Triggers | Platforms | Last Verified | Status |
|---|---|---|---|---|---|
| [`webview-wrapper`](webview-wrapper/SKILL.md) | webview_flutter 4.x — URL allowlist, JS bridge, back-handling, mixed-content guard, NOT for OAuth (Apple 4.5.4) | webview, webview_flutter, in-app browser, help page, terms of service, javascript channel, mixed content | ios, android | 2026-05-26 | pre-seeded |
| [`in-app-review-prompt`](in-app-review-prompt/SKILL.md) | in_app_review 2.x — Apple SKStoreReviewController + Play In-App Review. Happy-path gated, 90-day cooldown, fallback to store listing | in app review, in_app_review, rate us, rate the app, SKStoreReviewController, requestReview, rating prompt | ios, android | 2026-05-26 | pre-seeded |

---

## Dependency graph

```
firebase-core-setup           (foundation — all Firebase skills depend on this)
├── analytics-firebase
├── crash-monitor-dual
├── remote-config-firebase
│   └── force-update-gate
├── notifications-fcm
├── auth-firebase-email
│   ├── auth-google-signin
│   ├── auth-apple-signin
│   ├── auth-firebase-phone-otp
│   └── account-deletion-cross-cutting (also depends on subs-revenuecat + secure-storage-tokens + notifications-fcm + crash-monitor-dual + analytics-firebase)
└── promo-codes-system           (also depends on deeplinks-go-router + subs-revenuecat)

secure-storage-tokens             (independent foundation)
├── used by auth-firebase-email + onboarding-flow + auth interceptors
└── dio-interceptor-stack (reads tokens via this skill)

dio-interceptor-stack             (depends on secure-storage-tokens)
└── certificate-pinning-dio       (drop-in pinned HttpClient adapter for the same Dio)

deeplinks-go-router               (independent foundation)
├── gorouter-statefulshell-deeplink (depends on deeplinks-go-router)
└── used by promo-codes-system + onboarding-flow + email-link callback

subs-revenuecat                   (independent — does not depend on Firebase)
└── used by promo-codes-system (paid promotional grants via RC REST)

onboarding-flow                   (depends on secure-storage-tokens + remote-config-firebase + permission-handler-centralized for soft-ask)

permission-handler-centralized    (independent; coordinates with notifications-fcm + ios-att-prompt)

ios-privacy-manifest              (foundation — independent)
ios-att-prompt                    (depends on firebase-core-setup for analytics ATT-gating)

drift-schema-migrations           (independent)
└── pairs with supabase-read-through-cache-mirror

connectivity-offline-ux           (independent; pairs with drift + supabase-read-through-cache-mirror for queued ops)

ios-android-hardening             (depends on crash-monitor-dual for symbol upload)

media-picker-upload               (depends on permission-handler-centralized)
background-tasks-workmanager      (independent; coordinates with notifications-fcm for OEM workarounds)
webview-wrapper                   (independent)
in-app-review-prompt              (independent)
splash-and-launcher-icon          (independent)
freezed-json-serializable         (independent foundation)
```

**Recommended Phase 01 order** (foundations first):
1. `firebase-core-setup`
2. `secure-storage-tokens`
3. `freezed-json-serializable` (model layer ready before any feature)
4. `dio-interceptor-stack` + `certificate-pinning-dio`
5. `drift-schema-migrations` (if offline-first / local cache)
6. `analytics-firebase`
7. `crash-monitor-dual`
8. `remote-config-firebase`
9. `deeplinks-go-router`
10. `splash-and-launcher-icon`
11. `ios-privacy-manifest` + `ios-android-hardening` (release-prep, but configure early)
12. `permission-handler-centralized` + `connectivity-offline-ux`

**Recommended Phase 02 order** (auth):
13. `auth-firebase-email`
14. `auth-google-signin` (if needed)
15. `auth-apple-signin` (if Google offered on iOS — guideline 4.8)
16. `auth-firebase-phone-otp` (if phone-first market)
17. `onboarding-flow`
18. `ios-att-prompt` (if any tracking SDK)

**Recommended later phases** (per feature):
19. `notifications-fcm` + `gorouter-statefulshell-deeplink` (deep-link tab routing)
20. `subs-revenuecat`
21. `promo-codes-system`
22. `media-picker-upload`
23. `background-tasks-workmanager`
24. `webview-wrapper` (T&C / help)
25. `force-update-gate` (before first ship)
26. `account-deletion-cross-cutting` (before first ship — store mandate)
27. `in-app-review-prompt` (after ~v1.1, give users content first)

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

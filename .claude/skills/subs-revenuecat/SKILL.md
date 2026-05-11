---
name: subs-revenuecat
description: RevenueCat subscriptions/IAP integration for Flutter — initialization, App Store Connect + Play Console setup, entitlement gating with Riverpod, purchase + restore flows, paywalls (RC UI v2), webhook server validation, sandbox testing, account-deletion compliance (KVKK/GDPR). Use when adding any subscription, in-app purchase, or paywall feature.
triggers: [revenuecat, purchases_flutter, subscription, in-app purchase, iap, paywall, entitlement, restore purchases, customer info, storekit, play billing, in-app subscription, purchase, monetization, premium feature]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.22.0"
ios_min: "13.0"            # 15.0 if using purchases_ui_flutter paywalls
android_min_sdk: 23
package_versions:
  purchases_flutter: "^10.0.2"
  purchases_ui_flutter: "^10.0.2"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded   # not yet battle-tested in a real project. First user MUST verify each step + append findings to pitfalls.md.
depends_on: []
---

# RevenueCat — Subscriptions & IAP for Flutter

## What this skill does

- Wires `purchases_flutter` 10.x into a Flutter app (Riverpod-friendly).
- Configures App Store Connect, Xcode, Play Console, RC dashboard end-to-end.
- Provides paste-ready entitlement provider, purchase + restore handlers, paywall integration.
- Documents 25 real-world pitfalls collected from RC GitHub issues, community forum, and 2025-2026 changes (StoreKit 2 default, Billing 8, Paywalls v2 GA, $2.5K MTR pricing).
- Backend webhook validator template (idempotent, Authorization-header authenticated).

## What this skill does NOT do

- It does NOT design your monetization model (free trial length, price points, geo pricing) — that's a product decision documented in `.project/prd.md` §Monetization.
- It does NOT host the webhook server — provides handler logic only; deploy it on your backend (Cloudflare Worker, Cloud Function, Express, etc.).
- It does NOT handle promotional/offer-code redemption UI flows beyond linking out (Flutter SDK can't redeem in-app on iOS — Apple limitation).
- It does NOT implement custom paywall UI — use RC's `purchases_ui_flutter` (Paywalls v2 GA) or build your own with `Purchases.getOfferings()`.

## Decision Tree

**Q1: iOS only, Android only, or both?**
- Both → standard path (this skill). Two API keys (one per app in RC dashboard).
- iOS only / Android only → still use this skill but skip the other platform's setup section.

**Q2: Use RevenueCat's prebuilt paywall UI?**
- Yes → add `purchases_ui_flutter`, use [snippets/paywall_widget.dart](snippets/paywall_widget.dart). iOS deployment target MUST be ≥15.0.
- No (custom paywall) → omit `purchases_ui_flutter`, build with `Purchases.getOfferings()` and your own widgets. Saves ~2-3MB app size.

**Q3: Backend with webhook validation?**
- Yes (recommended for any production app) → deploy [snippets/webhook_handler.js](snippets/webhook_handler.js); set webhook URL + Authorization secret in RC dashboard.
- No (client-only entitlement check) → still works for MVP, but vulnerable to client clock manipulation and you have no source of truth for cancellations/refunds. Document this as accepted risk in `.project/known-issues.md`.

**Q4: Anonymous-first or identify-on-launch?**
- Anonymous-first (recommended) → call `Purchases.configure(...)` without `appUserID`. Call `Purchases.logIn(authUid)` after user signs in. RC aliases anonymous → identified.
- ⚠ See pitfall #5 in pitfalls.md — TRANSFER webhook does NOT fire on anonymous→identified merge. Backend must fetch fresh `CustomerInfo` after login.

## Quick start

```bash
flutter pub add purchases_flutter
flutter pub add purchases_ui_flutter   # only if using RC paywalls
```

Then:
1. Get iOS + Android **public SDK keys** from [RevenueCat dashboard](https://app.revenuecat.com) → Apps.
2. Pass keys via `--dart-define=RC_IOS_KEY=...` and `--dart-define=RC_ANDROID_KEY=...` (NEVER hardcode).
3. Wire `Purchases.configure()` in `main()` — see [snippets/main_init.dart](snippets/main_init.dart).
4. Expose entitlement state via Riverpod — see [snippets/revenuecat_provider.dart](snippets/revenuecat_provider.dart).
5. Gate features by reading `hasProProvider`.

For full setup (App Store Connect, Play Console, capabilities, sandbox testers, webhooks) → [implementation.md](implementation.md).

## Code patterns

| Need | File |
|---|---|
| Initialize SDK in main() | [snippets/main_init.dart](snippets/main_init.dart) |
| Riverpod entitlement provider + listener | [snippets/revenuecat_provider.dart](snippets/revenuecat_provider.dart) |
| Purchase flow with all error-code branches | [snippets/purchase_handler.dart](snippets/purchase_handler.dart) |
| Paywall widget (RC UI) + result handling | [snippets/paywall_widget.dart](snippets/paywall_widget.dart) |
| Account deletion (KVKK/GDPR compliant) | [snippets/account_deletion.dart](snippets/account_deletion.dart) |
| Webhook receiver (idempotent) | [snippets/webhook_handler.js](snippets/webhook_handler.js) |
| ProGuard rules (Android release builds) | [snippets/proguard-rules.pro](snippets/proguard-rules.pro) |

## Known pitfalls

DON'T re-discover bugs others paid for → [pitfalls.md](pitfalls.md) (25 entries with symptom, cause, fix, source URL).

Top 5 to memorize:
1. Empty offerings on iOS → Paid Apps Agreement not signed.
2. Renewals not appearing → Apple Server-to-Server Notification URL not set in App Store Connect.
3. `restorePurchases` empty → wrong Apple ID signed into device, or testing TestFlight build with sandbox account.
4. Anonymous→identified merge → no TRANSFER webhook fires. Backend must pull fresh after login.
5. v10+ removed restore for consumed one-time products → product type misconfiguration in RC dashboard becomes permanent.

## Verification

After implementation, run [checklist.md](checklist.md) — 14 verification gates covering deps, dashboard config, sandbox test, restore button visibility, webhook delivery, KVKK delete-flow, privacy manifest.

## Skill metadata

- Validation status: **pre-seeded** — first project to use this MUST verify each step holds and append any deviations to `pitfalls.md`. After 2 successful real-project uses, change `validation_status` to `battle-tested`.
- Last verified: 2026-05-10 against `purchases_flutter` 10.0.2 + `purchases_ui_flutter` 10.0.2.
- Sources: 35+ (RC docs, GitHub issues, RC community forum, RC engineering blog) — see end of pitfalls.md.
- Major version assumed: v10. If using v9 or earlier, see [implementation.md](implementation.md) §"Older versions" before applying.

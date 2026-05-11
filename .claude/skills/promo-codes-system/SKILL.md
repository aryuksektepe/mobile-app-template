---
name: promo-codes-system
description: OWN server-side promo codes (NOT App Store offer codes — RC handles those). Firestore + Cloud Functions architecture, Crockford Base32 codes (no I/L/O/U ambiguity), atomic transaction redemption, App Check + per-user rate limiting, referral codes via deep links, RevenueCat REST integration for paid grants, KVKK-compliant logging. Use for "BLACKFRIDAY30", "INVITE123", trial unlocks, referral programs.
triggers: [promo code, promotional code, invite code, referral code, discount code, redemption, gift code, trial unlock, share to earn, refer a friend]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.22.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  cloud_firestore: "^5.0.0"
  cloud_functions: "^5.0.0"
  firebase_app_check: "^0.4.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup, deeplinks-go-router, subs-revenuecat]
---

# Promo Codes — Own Server-Side System

## What this skill does

- Firestore + Cloud Functions architecture for branded codes (`LAUNCH2026`, `BLACKFRIDAY30`) AND user-generated referral codes.
- **Crockford Base32 alphabet** (`0123456789ABCDEFGHJKMNPQRSTVWXYZ`) — no ambiguous chars (I/L/O/U).
- Atomic redemption via Firestore transaction: read → check expiry/regions/remaining → write redemption record → decrement count → grant entitlement, all in one shot.
- **App Check enforced** on the redemption callable function (blocks emulator/script abuse).
- Per-user rate limiting + per-IP failure tracking.
- Composite redemption ID `{code}_{uid}` makes idempotency free (a 2nd write fails).
- Referral two-sided rewards: defer credit until referee completes meaningful action (sub purchase / 7-day retention), NOT signup.
- **RevenueCat promotional grants** via REST API v2 (server-only, never from client) for paid subscriptions.
- Code input UI with auto-uppercase, paste handling, ambiguous-char filter.

## What this skill does NOT do

- Does NOT cover Apple/Google **store-side** promo codes — those go through App Store Connect / RevenueCat offer codes (separate `subs-revenuecat` skill).
- Does NOT implement the marketing campaign UI (TR-only, time-limited, etc.) — only the code redemption mechanism.
- Does NOT replace fraud detection beyond rate limiting + App Check (for serious abuse, layer in vendor like Sift).

## Decision tree

**Q1: Codes grant paid subscription / digital content?**
- YES → use RevenueCat promotional entitlements via REST (Apple App Review allowed). Granting via your own backend bypassing IAP = App Store rejection (3.1.1).
- NO (free-tier feature unlock, credits, ads-removed) → manage entitlement in your own backend.

**Q2: Region-restricted codes (TR-only campaign)?**
- YES → enforce server-side using `x-appengine-country` header (NOT client locale — bypassable).
- NO → skip region gate.

**Q3: Referral codes — credit on signup or post-conversion?**
- POST-CONVERSION (recommended) — referrer gets credit when referee buys a sub OR is retained 7 days. Prevents fake-account farming.
- ON SIGNUP — easy, but invites abuse.

## Quick start

```bash
flutter pub add cloud_functions firebase_app_check
# Backend (Cloud Functions):
cd functions
npm install firebase-functions firebase-admin node-fetch
```

## Code patterns

| Need | File |
|---|---|
| Cloud Function — `redeemPromoCode` (atomic) | [snippets/redeem_function.ts](snippets/redeem_function.ts) |
| Code generator (admin script) | [snippets/code_generator.ts](snippets/code_generator.ts) |
| Riverpod PromoController + Flutter UI input | [snippets/promo_controller.dart](snippets/promo_controller.dart) |
| Firestore security rules | [snippets/firestore.rules](snippets/firestore.rules) |
| RevenueCat promotional grant (server) | [snippets/rc_grant.ts](snippets/rc_grant.ts) |

For full setup (collections schema, App Check enforcement, referral two-sided flow) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (17 entries). Top 5:
1. Race conditions over-issue last-N codes — must be Firestore transaction.
2. Case mismatch (`abc123` vs `ABC123`) → uppercase server-side.
3. Codes leaking to Analytics → log only `code_hash`, never raw code.
4. Granting paid sub from your backend bypassing IAP → App Store rejects (3.1.1). Use RC promotional entitlements.
5. Region check from client locale → bypassable; enforce via Cloud Function geolocation header.

## Verification

→ [checklist.md](checklist.md) (15 items: App Check enforced, double-redeem rejected, region gate enforced server-side, referral rewards land post-conversion).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10
- Depends on: `firebase-core-setup` (App Check), `deeplinks-go-router` (referral landing pages)

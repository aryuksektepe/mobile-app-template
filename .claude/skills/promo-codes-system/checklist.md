# Promo Codes — Verification Checklist

## Backend
- [ ] Firestore rules deny direct client read/write to `promoCodes`, `redemptions`, `rateLimits`
- [ ] Cloud Function `redeemPromoCode` deployed with `enforceAppCheck: true`
- [ ] Function pinned to EU region (`europe-west1`) for KVKK
- [ ] Code generator script tested on 100-code batch
- [ ] Backup strategy in place for `promoCodes` collection (Firestore export)

## Atomicity
- [ ] Test: 10 concurrent redemptions of a code with `maxRedemptions=1` → exactly 1 succeeds
- [ ] Test: same user retries 3× → first succeeds, 2nd+ return idempotent success
- [ ] Test: race during exhaustion (last-1 code) → exactly 1 success, others get `code_exhausted`

## Validation
- [ ] Crockford Base32 enforced server-side AND in client input formatter
- [ ] Whitespace stripped before validation
- [ ] Mixed-case input → uppercased before lookup
- [ ] Codes with I/L/O/U rejected at generation time

## Anti-abuse
- [ ] App Check enforced — emulator without debug token gets `failed-precondition`
- [ ] Rate limit: 6th attempt within 60s returns `rate_limited`
- [ ] Per-user cap (`maxRedemptionsPerUser`) honored
- [ ] No raw codes in any Analytics event (manual review of `code_hash` only)

## Region gate
- [ ] Region restriction enforced via `x-appengine-country` (server-side)
- [ ] Bypass attempt: client setting fake locale → still blocked

## Referral flow (if implemented)
- [ ] Referral codes deterministic per referrer (same code each visit)
- [ ] Deep link `https://yourdomain.com/r/CODE` opens app & stashes code
- [ ] Code applied at first conversion event (NOT signup)
- [ ] Referrer credited only AFTER referee converts; one-shot per referee

## RevenueCat integration (if granting paid subs)
- [ ] RC secret key in Cloud Function env var, NEVER in client
- [ ] Promotional grant uses RC REST v2 `grant_entitlement`
- [ ] User sees "Free for X days, then $Y" disclosure before redemption
- [ ] Apple App Review tested on TestFlight build with promo grant

## Compliance
- [ ] KVKK: redemption events deletable on user's right-to-erasure request
- [ ] Privacy policy mentions promo data collection (timestamp, UID, country, code)
- [ ] App Store: paid digital content gated only via RC promotional entitlements (not bypassing IAP)

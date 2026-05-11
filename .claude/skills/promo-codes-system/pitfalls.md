# Promo Codes — Pitfalls Catalog

17 entries from Firebase docs, RevenueCat docs, OWASP, Apple guidelines, community.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | Last-N codes redeemed twice → over-issued | Reading `redeemedCount` then writing without transaction | Wrap in `db.runTransaction()`; never use plain reads + `FieldValue.increment` for capacity-bounded checks | [Firebase transactions](https://firebase.google.com/docs/firestore/manage-data/transactions) |
| 2 | "Code already used" appearing for valid codes | Case mismatch (`abc123` vs `ABC123`) | Always uppercase server-side; reject mixed case at validation | [Crockford spec](https://www.crockford.com/base32.html) |
| 3 | Whitespace from paste fails validation | User pasted `"  ABC123 "` | Strip with `.trim()` + `.replace(/\s+/g, '')` BEFORE pattern check | community |
| 4 | Codes leak via Analytics → competitor harvests | Logging full code in `promo_redeem_attempt{code: "BLACKFRIDAY30"}` | Only log code TYPE / hash / first-3-chars, never full code | OWASP |
| 5 | One user redeems 50 codes in a script | No App Check, no rate limit, no per-user cap | Enforce App Check on callable, sliding-window rate limit, `maxRedemptionsPerUser` field | [Firebase App Check](https://firebase.google.com/docs/app-check) |
| 6 | Emulator farm abuses signup-bonus codes | App Check disabled on emulator builds | Enforce App Check; use debug tokens only for dev; reject in production callable | [Talsec abuse prevention](https://medium.com/@talsec/fraud-proofing-an-android-app-choosing-the-best-device-id-for-promo-abuse-prevention-aa4a2459637f) |
| 7 | Referrer rewarded for fake referees who immediately uninstalled | Crediting on signup instead of post-conversion | Defer referral credit until referee completes meaningful action (sub purchase or 7-day retention) | community |
| 8 | RevenueCat entitlement granted but expires immediately | Calling RC API from client (key exposed) OR wrong duration unit | Always grant from server with secret key; pass explicit `end_time_ms` | [RC API v2](https://www.revenuecat.com/docs/api-v2) |
| 9 | Code typed `BLACKFRIDAY3O` (letter O) doesn't match `30` | Ambiguous chars in alphabet | Generate from Crockford Base32 alphabet (no I/L/O/U); reject in input formatter | [DEV - Crockford](https://dev.to/kralik12/generate-human-friendly-random-codes-in-php-with-crockfords-base32-fob) |
| 10 | Same user double-redeems via concurrent taps | Client doesn't disable button; transaction race | Disable button on `AsyncLoading`; server uses composite ID `{code}_{uid}` so 2nd write fails | community |
| 11 | Region campaign leaks worldwide | Region check from client locale (spoofable) | Use `x-appengine-country` header / Cloud Function geolocation; validate server-side | [Firebase callable docs] |
| 12 | A/B test users redeem each other's exclusive codes | Codes shared in chat/Reddit | Use sticky per-audience codes (RC offerings) OR mark codes single-use w/ specific eligibility check | community |
| 13 | Retry storm crashes Cloud Function | Client retries on 500s without backoff | Use exponential backoff (1s/2s/4s) + idempotent design (composite redemption ID handles retries safely) | community |
| 14 | Codes generated locally collide because randomness was `Math.random()` | Weak RNG in browser | Use `crypto.randomBytes` server-side; check Firestore for collision; retry up to 5x | community |
| 15 | Promo code in URL gets logged to access logs / analytics referrer | Sharing `https://app.com/redeem?code=XYZ` | Redirect promo URLs to scrub query params; OR carry code in path segment + 302 to clean URL | OWASP |
| 16 | Trial promo grants subscription that converts to paid charge | Granting paid entitlement without explaining trial-end behavior | Always communicate "free for X days, then $Y/mo unless cancelled"; store grant origin for refund handling | App Store guidelines |
| 17 | Apple App Store rejects app for promo codes that "circumvent IAP" | Granting digital subscription via non-IAP code on iOS | RevenueCat promotional entitlements are explicitly allowed; rolling your own digital subscription bypassing IAP violates 3.1.1 | Apple guidelines |

# RevenueCat Flutter — Pitfalls Catalog

25 real-world bugs / surprises collected from RC GitHub issues, RC community forum, and 2025-2026 SDK changes. Each entry: symptom, root cause, fix, source.

When you hit a NEW pitfall not listed here, append it. That's how this skill stops being "pre-seeded" and becomes battle-tested.

---

## Setup / dashboard

### #1 — Empty offerings on iOS
- **Symptom:** `Purchases.getOfferings()` returns `null` current offering OR offerings with no packages.
- **Cause:** Paid Apps Agreement not signed in App Store Connect. Without it, products won't load.
- **Fix:** Agreements, Tax, and Banking → Paid Apps → sign + complete tax + banking.
- **Source:** RC Community — multiple "PurchaserInfo empty" threads.

### #6 — Renewals never appear in dashboard
- **Symptom:** Initial purchase works, but RC dashboard never shows renewals; entitlement expires unexpectedly.
- **Cause:** Apple Server-to-Server Notification URL not set (or set to V1 instead of V2) in App Store Connect.
- **Fix:** RC dashboard → Apple App Store → click "Apply in App Store Connect" — copies the URL. In App Store Connect, set BOTH Production AND Sandbox URLs, choose Version 2.
- **Source:** https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications

### #16 — `PlatformException(23, ...)` configuration error on configure
- **Symptom:** App crashes/errors immediately on `Purchases.configure()`.
- **Cause:** Wrong API key for platform (using iOS key on Android or vice versa); product/entitlement not set up in dashboard; or pointed at wrong RC project.
- **Fix:** Verify `appl_xxx` for iOS, `goog_xxx` for Android. Verify offerings exist in dashboard. Confirm bundle ID matches RC dashboard app config.
- **Source:** GH issue purchases-flutter#635.

### #17 — `PlatformException(5, productNotAvailable)`
- **Symptom:** Purchase fails immediately with code 5.
- **Cause:** Product not approved by Apple/Google; not in same store account; bundle/package name mismatch; or just propagation lag (~hours after creation).
- **Fix:** Wait for store propagation. Verify bundleId in Xcode == RC dashboard == App Store Connect. For Android, verify package name matches and app uploaded to at least Internal Testing.
- **Source:** RC Community PE5 thread.

---

## Purchase flow

### #5 — Anonymous → identified merge loses entitlement on backend
- **Symptom:** User purchases as anonymous, then signs in. App shows entitlement (RC aliased correctly) but your backend doesn't know.
- **Cause:** The TRANSFER webhook does NOT fire on anonymous→identified aliasing via `Purchases.logIn()`. Only fires on cross-identified transfers.
- **Fix:** After `Purchases.logIn(authUid)`, immediately fetch fresh `CustomerInfo` from your backend (or have the client PUT entitlement state). Don't wait for webhook.
- **Source:** https://community.revenuecat.com/general-questions-7/no-transfer-webhook-when-logging-in-after-anonymous-purchase-6767

### #21 — Pending Android purchase looks like failure
- **Symptom:** User completes purchase flow but `purchasePackage()` returns or errors before granting entitlement; user thinks it failed.
- **Cause:** Android purchase is in PENDING state — wallet auth, family approval, slow card processing. Can take minutes to hours.
- **Fix:** Catch `PurchasesErrorCode.paymentPendingError` and show "Purchase pending — we'll grant access automatically when complete." Listen on `addCustomerInfoUpdateListener` for resolution. See [snippets/purchase_handler.dart](snippets/purchase_handler.dart).
- **Source:** Google Play Billing pending-transactions docs + RC error codes reference.

### #9 — `getCustomerInfo` returns stale data right after purchase
- **Symptom:** Purchase succeeds, but `getCustomerInfo()` immediately after still shows no entitlement.
- **Cause:** SDK caches CustomerInfo (~5 min default). Your call returns cached value before refresh.
- **Fix:** Either (a) call `Purchases.invalidateCustomerInfoCache()` before `getCustomerInfo()`, or (b) preferred — don't poll, listen via `addCustomerInfoUpdateListener` which fires immediately on any state change.
- **Source:** https://www.revenuecat.com/docs/test-and-launch/debugging/caching

---

## Restore

### #3 — `restorePurchases` returns empty entitlements on iOS
- **Symptom:** User had purchased pro, deleted/reinstalled app, taps Restore, gets empty result.
- **Cause:** Apple ID currently signed into device differs from the one used for purchase. OR testing TestFlight build with wrong Apple ID.
- **Fix:** User: verify Apple ID via Settings → App Store. Sandbox: Settings → App Store → Sandbox Account.
- **Source:** GH issue purchases-flutter#224.

### #4 — Android `restoreTransactions` hangs forever in sandbox
- **Symptom:** After uninstall/reinstall with active sub, restore never returns.
- **Cause:** Known RC SDK bug under specific Billing 8 + sandbox conditions.
- **Fix:** Some 2025 reports claim downgrading purchases_flutter to 8.10.6 helps. Verify against latest patch first. Add a 30s timeout with retry UI.
- **Source:** GH issues purchases-flutter#198 and #1420.

### #2 — Non-consumable cannot be restored from v10+
- **Symptom:** User who bought a non-consumable (e.g., lifetime unlock) on an older app version cannot restore on v10+.
- **Cause:** Product was misconfigured as `CONSUMABLE` in RC dashboard. RC consumes one-time purchases. v10 removed the workaround restore path.
- **Fix:** AUDIT product types in RC dashboard BEFORE upgrading to v10. For affected users, either downgrade or recreate the purchase server-side (manual customer-by-customer).
- **Source:** purchases_flutter v10.0.0 changelog.

---

## Paywall (purchases_ui_flutter)

### #11 — iOS paywall returns `cancelled` even on success
- **Symptom:** User completes purchase, paywall closes, but `PaywallResult` is `cancelled` instead of `purchased`.
- **Cause:** Bug in `purchases_ui_flutter` 8.5.1 (iOS sandbox specifically). Fixed in 9.x+ but defensive code recommended forever.
- **Fix:** Don't trust the result enum alone. After paywall dismissal, `invalidateCustomerInfoCache()` + `getCustomerInfo()` and check entitlements directly. See [snippets/paywall_widget.dart](snippets/paywall_widget.dart).
- **Source:** https://community.revenuecat.com/sdks-51/purchase-ui-flutter-8-5-1-paywallresult-cancell-always-in-ios-sandbox-5927

### #12 — iOS paywall doesn't dismiss after restore
- **Symptom:** User taps "Restore Purchases" on RC paywall on iOS — restore succeeds, but paywall stays on screen. Android dismisses correctly.
- **Cause:** UI bug in the iOS PaywallView wrapper.
- **Fix:** In `onRestoreCompleted` callback, manually `Navigator.of(context).maybePop()`. See [snippets/paywall_widget.dart](snippets/paywall_widget.dart).
- **Source:** GH issue purchases-flutter#1161.

### #25 — App size jumps with `purchases_ui_flutter`
- **Symptom:** Adding `purchases_ui_flutter` increases app size by 2-3 MB.
- **Cause:** Pulls in RC's native UI libraries (SwiftUI helpers, paywall renderer).
- **Fix:** If you have a custom paywall, omit `purchases_ui_flutter` entirely — `purchases_flutter` alone is much lighter.
- **Source:** Observation; verify with `flutter build appbundle --analyze-size`.

---

## Promo / offer codes

### #13 — Offer codes (iOS) cannot be redeemed in-app from Flutter
- **Symptom:** No SDK method to redeem an iOS offer code from inside the app.
- **Cause:** Flutter SDK doesn't expose iOS native `presentCodeRedemptionSheet`.
- **Fix:** Link out: `https://apps.apple.com/redeem?ctx=offercodes&id=YOUR_APP_ID&code=THE_CODE` opens the App Store redemption flow.
- **Source:** https://community.revenuecat.com/sdks-51/how-to-redeem-an-offer-code-in-flutter-for-both-android-and-ios-1856

### #14 — Promo codes don't work cross-platform
- **Symptom:** Marketing promised "use code XYZ" — works on iOS but not Android, or vice versa.
- **Cause:** iOS offer codes ≠ Android promo codes. They're different systems with different capabilities. Android promo codes can only grant trials, not free products or discounts.
- **Fix:** Don't promise users "one code." Branch per platform in marketing material AND in code redemption UX.
- **Source:** RC Community promo-code threads.

---

## Sandbox / testing

### #7 — TestFlight prices wrong / products not loading
- **Symptom:** Build deployed via TestFlight shows wrong prices or empty offerings.
- **Cause:** TestFlight is a hybrid mode — production Apple ID + sandbox-style purchases. Notoriously unreliable for IAP testing. Or: dev key used in TestFlight build instead of prod key.
- **Fix:** Use **production** RC API key in TestFlight builds. For day-to-day testing prefer Xcode + sandbox tester (or StoreKit Configuration File). Reserve TestFlight for end-to-end pre-release.
- **Source:** RC docs — Sandbox Testing.

### #8 — Sandbox sub renews every 24 hours (was every few minutes)
- **Symptom:** Test cycles take a full day to validate renewal logic.
- **Cause:** Apple changed sandbox renewal cadence in December 2024 from minutes to 24h.
- **Fix:** Plan test cycles around 24h. For fast iteration, use Xcode StoreKit Configuration File (custom renewal speed).
- **Source:** RC engineering blog 2025; verified Dec 2024 Apple change.

### #10 — Sandbox tester "already used / expired"
- **Symptom:** Sandbox purchase fails with "this account cannot be used" or sub appears already-expired.
- **Cause:** Apple sandbox testers can only complete a sub-cycle a limited number of times. Re-use is restricted.
- **Fix:** Create a fresh sandbox tester per cycle. Settings → App Store → Sandbox Account → sign out, then sign in fresh tester. OR clear purchase history in Settings → App Store → Subscriptions.
- **Source:** RC docs — Sandbox.

### #23 — "Subscriptions still in sandbox" after release
- **Symptom:** App is launched on store, but purchases still show as sandbox.
- **Cause:** App not actually live yet (in review or staged release); OR user is testing TestFlight build (still sandbox).
- **Fix:** Confirm App Store Connect shows "Ready for Sale". For users, install the production build from store.
- **Source:** RC Community.

---

## Webhooks

### #19 — Webhook delivered twice (or more)
- **Symptom:** Same purchase event creates duplicate entitlement records.
- **Cause:** RC guarantees at-least-once delivery, not exactly-once.
- **Fix:** Dedupe by `event.id` in the webhook handler. Insert a `webhook_events` row with `event.id` as PK; bail if already exists. See [snippets/webhook_handler.js](snippets/webhook_handler.js).
- **Source:** RC docs — Webhooks.

### #20 — Webhook lacks signature header
- **Symptom:** Looking for `x-revenuecat-signature` header — it's not there.
- **Cause:** RC removed the HMAC signature header. Now uses an Authorization header value YOU set in the dashboard.
- **Fix:** RC dashboard → Webhooks → set Authorization header value (a strong shared secret). Validate `req.headers.authorization === SECRET` in your handler.
- **Source:** https://community.revenuecat.com/dashboard-tools-52/is-x-revenuecat-signature-removed-and-where-is-webhook-secret-key-7110

---

## Family sharing / restrictions

### #15 — Android shows "Ask your parent" on subscription purchase
- **Symptom:** Family-managed Google account tries to buy sub, gets blocked with "Ask your parent."
- **Cause:** Google's Family Link rules — child accounts cannot purchase auto-renewing subscriptions, only one-time purchases with approval.
- **Fix:** Document as a known limitation. Surface a friendlier message when caught: "Subscriptions aren't available on family-supervised accounts."
- **Source:** RC Community "Ask your parent" thread.

### #18 — iOS family-sharing inflates revenue counts
- **Symptom:** RC dashboard shows revenue numbers that don't match Apple payout reports.
- **Cause:** Family-shared transactions (`in_app_ownership_type=FAMILY_SHARED`) grant entitlement but generate no new revenue.
- **Fix:** When reporting revenue internally, filter only `PURCHASED` transactions (not FAMILY_SHARED). Entitlement grants still count both.
- **Source:** RC engineering blog — family sharing.

---

## Compliance / privacy

### #22 — Account deletion leaves RC user data behind (KVKK/GDPR breach)
- **Symptom:** User deletes account in app, but RC dashboard still shows their subscriber record with purchase history.
- **Cause:** `Purchases.logOut()` only clears local cache. RC server retains the subscriber record forever unless explicitly deleted.
- **Fix:** Three-step deletion. After in-app delete: (1) backend calls `DELETE https://api.revenuecat.com/v1/subscribers/{app_user_id}` with **secret API key**, (2) `Purchases.logOut()` on device, (3) sign out from auth provider. Secret key NEVER ships in app. See [snippets/account_deletion.dart](snippets/account_deletion.dart).
- **Source:** https://www.revenuecat.com/docs/dashboard-and-metrics/customer-history/manage-users + KVKK Right to Erasure.

### #24 — StoreKit 2 — no more receipt file
- **Symptom:** Old code using `appStoreReceiptURL` or `SKReceiptRefreshRequest` no longer works (deprecated iOS 17+).
- **Cause:** RC iOS SDK 5+ defaults to StoreKit 2, which uses signed JWS Transactions instead of receipt files.
- **Fix:** Don't write any code that touches `appStoreReceiptURL`. Don't try to upload receipts to your backend manually — let RC handle JWS validation server-side via webhooks.
- **Source:** https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/

---

## Sources

- https://pub.dev/packages/purchases_flutter (changelog)
- https://github.com/RevenueCat/purchases-flutter (releases + issues)
- https://www.revenuecat.com/docs (Flutter setup, webhooks, sandbox, errors, caching, restore behavior)
- https://www.revenuecat.com/blog (StoreKit 2 update, Play Billing 8 migration, Paywalls v2 GA, family sharing)
- https://community.revenuecat.com (forum threads cited inline above)
- Apple Developer documentation — App Store Server Notifications V2, StoreKit 2, Family Sharing
- Google Play Billing Library 8 migration guide
- KVKK İlke Kararı 2026/347 (account deletion + right to erasure)

---

## How to extend this catalog

When you hit a new RC issue:
1. Reproduce it (or confirm symptom from logs).
2. Find root cause (search GH issues + RC community for similar reports).
3. Document fix that worked.
4. Append entry here with: **Symptom**, **Cause**, **Fix**, **Source URL**.
5. Bump `last_verified` in [SKILL.md](SKILL.md) to today's date.
6. After 2 successful real-project uses with no surprises, change `validation_status` from `pre-seeded` to `battle-tested`.

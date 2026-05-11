# RevenueCat — Verification Checklist

After applying this skill, walk through every item. Failures mean the integration is NOT ready for release.

## Build / static
- [ ] `flutter pub get` resolves without conflicts (`purchases_flutter ^10.0.2`)
- [ ] `flutter analyze` returns 0 issues
- [ ] `flutter test` passes
- [ ] iOS: `cd ios && pod install --repo-update` succeeds
- [ ] iOS deployment target ≥13.0 in Xcode project AND Podfile (≥15.0 if using paywalls)
- [ ] Android `minSdk = 23` in `android/app/build.gradle.kts`
- [ ] No hardcoded API keys in source — verify with `grep -r "appl_" lib/ ios/ android/`

## RC dashboard
- [ ] Project has both iOS App and Android App with separate API keys
- [ ] At least one Entitlement defined (e.g., `pro`)
- [ ] Products created and attached to entitlements
- [ ] At least one Offering with packages + the user-facing prices fetched from each store

## App Store Connect (iOS)
- [ ] Paid Apps Agreement signed (pitfall #1)
- [ ] Tax + banking info complete
- [ ] In-App Purchase key uploaded to RC (StoreKit 2 requirement)
- [ ] Apple Server-to-Server Notifications V2 — BOTH Production AND Sandbox URLs set (pitfall #6)
- [ ] At least one sandbox tester created
- [ ] At least one IAP product status NOT "Missing Metadata"

## Play Console (Android)
- [ ] App uploaded to at least Internal Testing track
- [ ] Subscriptions configured with Base Plans + Offers
- [ ] License testers added
- [ ] Service Account JSON uploaded to RC dashboard
- [ ] Real-time Developer Notifications (RTDN) Pub/Sub topic configured

## Code wiring
- [ ] `Purchases.configure()` called in `main()` after `WidgetsFlutterBinding.ensureInitialized()`
- [ ] API key passed via `--dart-define` (not hardcoded)
- [ ] `Purchases.setLogLevel(LogLevel.warn)` in release builds
- [ ] Riverpod `customerInfoProvider` listens via `addCustomerInfoUpdateListener` and disposes on `ref.onDispose`
- [ ] `hasProProvider` reads `entitlements.active.containsKey('pro')`
- [ ] After auth login: `Purchases.logIn(authUid)` + immediately fetch backend (pitfall #5)
- [ ] Purchase handler catches ALL listed `PurchasesErrorCode` cases — see [snippets/purchase_handler.dart](snippets/purchase_handler.dart)

## Paywall (if using `purchases_ui_flutter`)
- [ ] iOS deployment target ≥15.0
- [ ] After paywall dismissal, code re-checks entitlement directly (pitfall #11)
- [ ] iOS restore callback manually pops paywall (pitfall #12)
- [ ] **Restore Purchases** button visible on every paywall screen (Apple App Review)
- [ ] Privacy Policy + Terms of Use links visible on paywall (Apple App Review)
- [ ] Subscription disclosure visible: price, billing period, auto-renew, free trial length (Apple App Review)

## Webhook server
- [ ] Endpoint deployed and reachable
- [ ] Authorization header value matches RC dashboard config
- [ ] Idempotent — dedupe by `event.id` (pitfall #19)
- [ ] Returns 200 within RC's timeout window (~10s)
- [ ] Test event sent from RC dashboard → received and processed
- [ ] Handles at minimum: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, TRANSFER

## Sandbox test (manual — must perform on real device)
- [ ] iOS: signed in with sandbox tester via Settings → App Store → Sandbox Account
- [ ] iOS: purchase from Xcode build succeeds → entitlement appears in `customerInfo.entitlements.active`
- [ ] iOS: app killed and relaunched → entitlement persists
- [ ] iOS: tapped Restore Purchases → entitlement restored on fresh install
- [ ] iOS: cancel from Settings → after expiration, app reflects expired state
- [ ] Android: signed in with license tester account
- [ ] Android: purchase from Internal Testing build succeeds → entitlement granted
- [ ] Android: PENDING purchase scenario (use slow card / wallet) → app shows pending UI, then resolves

## Compliance
- [ ] Privacy policy lists RevenueCat (US) as data recipient with purpose
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`
- [ ] Play Data Safety form declares "Purchase history" + "Device IDs" as collected/shared
- [ ] In-app account deletion flow: tested end-to-end, verifies RC subscriber record deleted server-side (pitfall #22)
- [ ] "Manage Subscription" button uses `customerInfo.managementURL`
- [ ] Privacy policy + terms links accessible from app Settings

## Release build verification
- [ ] iOS release build (production RC key) installed via TestFlight → purchase flow works
- [ ] Android release AAB (production RC key) installed via Internal Testing → purchase flow works
- [ ] Webhook delivers events from production builds (verify in RC dashboard logs)
- [ ] App size impact measured: `flutter build appbundle --analyze-size` (pitfall #25)

---

## If any item fails

1. Find the matching pitfall in [pitfalls.md](pitfalls.md).
2. Apply the fix.
3. Re-run the failed checklist item.
4. If you discover a NEW pitfall not in the catalog → APPEND it to pitfalls.md so the next project doesn't pay the same cost.

After all items pass and zero new pitfalls found across 2 projects → update `validation_status: battle-tested` in [SKILL.md](SKILL.md).

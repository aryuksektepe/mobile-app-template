# RevenueCat Flutter — Implementation Guide

End-to-end setup. Follow in order. Each step has a verification line so you know it worked.

---

## 0. Compatibility matrix (verify FIRST)

| Component | Min | Notes |
|---|---|---|
| `purchases_flutter` | 10.0.2 | Latest as of 2026-05-10 |
| `purchases_ui_flutter` | 10.0.2 | Only if using RC paywalls / Customer Center |
| Flutter SDK | 3.22.0 | Raised in v9 |
| Dart | 3.4.0 | Raised in v9 |
| iOS deployment target | 13.0 | **15.0** if using `purchases_ui_flutter` paywalls |
| Android `minSdk` | 23 | Raised in v10 (was 21) |
| Xcode | 14.0+ | |
| Play Billing Library | 8.3.0 | Vendored — don't add separately |

⚠ If your project is below these mins, either upgrade the project or pin to an older `purchases_flutter` (v8 supported iOS 11 + minSdk 21, but loses StoreKit 2 default + Paywalls v2).

---

## 1. RevenueCat dashboard

1. Sign up at https://app.revenuecat.com.
2. Create a **Project** (one project = one logical app, regardless of platform count).
3. Inside the project, create **two Apps**: one iOS, one Android. Each generates a separate **public SDK key** (`appl_xxxxx` and `goog_xxxxx`).
4. Define **Entitlements** — these are what your code checks. Use a stable identifier like `pro` (NOT product IDs). Most apps need one entitlement only.
5. Add **Products** — these mirror what's in App Store Connect / Play Console. Use store-side product IDs (e.g., `com.yourapp.pro_monthly`).
6. Attach products → entitlements (a product grants an entitlement when active).
7. Create an **Offering** (e.g., `default`) and add packages (`$rc_monthly`, `$rc_annual`, `$rc_lifetime` are RC's standard package identifiers).

**Verify:** Dashboard → Offerings → "default" shows your packages with prices fetched from each store (may take hours after store-side creation).

---

## 2. iOS — App Store Connect

1. **Sign Paid Apps Agreement** (Agreements, Tax, and Banking → Paid Apps).
   - This is the #1 cause of empty offerings (pitfall #1). Without it, products will not load.
2. Complete **tax forms** + **banking info**.
3. App → Features → **In-App Purchases** → create products.
   - For subscriptions: create a **Subscription Group** first, then add subscriptions to it.
   - Status will be "Missing Metadata" until you fill all required fields (display name per locale, review screenshot, description).
4. App → App Information → set the **Subscription Status URL** (RC dashboard → Apple App Store config → "Apply in App Store Connect" copies it for you).
5. **In-App Purchase Key** (StoreKit 2 requirement):
   - App Store Connect → Users and Access → Integrations → In-App Purchase → Generate.
   - Download the `.p8` file, copy Key ID + Issuer ID.
   - Upload to RC dashboard → Apple App Store config.
6. **App Store Server Notifications**:
   - In App Store Connect → App → App Information → set **Production Server URL** AND **Sandbox Server URL** to the URLs from RC dashboard.
   - Choose **Version 2** (NOT V1).
   - Without this, RC silently misses renewals and cancellations (pitfall #6).
7. **Sandbox testers**: Users and Access → Sandbox → Testers → add. Use a unique email per tester (cannot reuse Apple ID emails).

**Verify:** RC dashboard → Apple App Store → all green checks (Agreement signed, IAP key uploaded, Server Notifications configured).

---

## 3. iOS — Xcode project

1. Open `ios/Runner.xcworkspace`.
2. Select Runner target → Signing & Capabilities → **+ Capability** → **In-App Purchase**.
3. Set **iOS Deployment Target** to 13.0 (or 15.0 if using RC paywalls).
4. Update `Podfile` platform line:
   ```ruby
   platform :ios, '13.0'   # or '15.0' for paywalls
   ```
5. Run `cd ios && pod install --repo-update && cd ..`.
6. **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`): RC SDK ships its own manifest. App-level manifest must still declare:
   ```xml
   <key>NSPrivacyAccessedAPITypes</key>
   <array>
     <dict>
       <key>NSPrivacyAccessedAPIType</key>
       <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
       <key>NSPrivacyAccessedAPIReasons</key>
       <array><string>CA92.1</string></array>
     </dict>
   </array>
   ```
7. Optional but recommended: add a **StoreKit Configuration File** for local testing (Xcode → New File → StoreKit Configuration). Lets you test purchase flow without sandbox testers, instant renewals.

**Verify:** Build the iOS app in Xcode. No warnings about missing IAP capability or deployment target mismatch.

---

## 4. Android — Play Console

1. Create app, upload at least ONE signed bundle to **Internal testing** track. You CANNOT test purchases without this. Internal testing builds let testers buy with real-looking flow but no charge.
2. Monetize → Subscriptions:
   - Create subscription products with **Base Plans + Offers** (the new model since Billing 5).
   - Each base plan has a billing period (P1M, P1Y, etc.).
   - Offers attach to base plans for promo pricing / free trials.
3. Monetize → Setup → **License testing**: add tester emails. License testers see test messages on real billing UI.
4. Setup → API access → create or link a **Google Cloud Project** → create a **Service Account** with "Finance" role → generate JSON key.
5. Upload the Service Account JSON to RC dashboard → Google Play Store config.
6. Real-time Developer Notifications (RTDN):
   - In Play Console → Monetize → Monetization setup → set up Pub/Sub topic.
   - RC dashboard provides the topic name. Without RTDN, RC polls (slower, less reliable).

**Verify:** RC dashboard → Google Play → all green checks (Service Account valid, RTDN configured).

---

## 5. Android — Gradle / manifest

1. `android/app/build.gradle.kts` (or `.gradle`):
   ```kotlin
   android {
     defaultConfig {
       minSdk = 23      // raised to 23 in purchases_flutter v10
       targetSdk = 34   // or current target
     }
   }
   ```
2. `AndroidManifest.xml`: BILLING permission is auto-added by the plugin. No manual edit required.
3. **ProGuard / R8**: SDK ships consumer rules. Only add custom rules if you see runtime crashes from obfuscation:
   - See [snippets/proguard-rules.pro](snippets/proguard-rules.pro).
4. **Multidex**: usually not needed (Billing 8 + RC don't push you over 64K methods alone).

**Verify:** `flutter build appbundle --release` succeeds, install on device, app launches.

---

## 6. Flutter — code wiring

### 6.1 Add deps
```yaml
# pubspec.yaml
dependencies:
  purchases_flutter: ^10.0.2
  purchases_ui_flutter: ^10.0.2  # only if using RC paywalls
  flutter_riverpod: ^2.5.0
```

### 6.2 Wire `Purchases.configure()` in `main()`
See [snippets/main_init.dart](snippets/main_init.dart).

Key rules:
- ALWAYS `WidgetsFlutterBinding.ensureInitialized()` first.
- Pass API key via `--dart-define`. NEVER hardcode.
- DO NOT pass `appUserID` if auth state isn't ready — let RC create anonymous, alias later via `logIn()`.
- Set `LogLevel.debug` in debug, `LogLevel.warn` in release.

### 6.3 Riverpod entitlement provider
See [snippets/revenuecat_provider.dart](snippets/revenuecat_provider.dart). Provides:
- `customerInfoProvider` — `StreamProvider<CustomerInfo>` that listens to `addCustomerInfoUpdateListener`.
- `hasProProvider` — `Provider<bool>` your widgets watch.
- Cleanup on `ref.onDispose`.

### 6.4 Purchase + restore handlers
See [snippets/purchase_handler.dart](snippets/purchase_handler.dart). Handles ALL `PurchasesErrorCode` cases the user can hit:
- `purchaseCancelledError` → silent (user cancelled, expected).
- `networkError` / `storeProblemError` → safe to retry.
- `paymentPendingError` (Android) → show "purchase pending" UI, listen for `customerInfoUpdates`.
- `productNotAvailableForPurchaseError` → propagation issue, retry later.
- All else → log + generic error.

### 6.5 Account deletion (KVKK/GDPR)
See [snippets/account_deletion.dart](snippets/account_deletion.dart). Three-step:
1. Cancel store-side subscription (instruct user — RC cannot cancel store subs).
2. Server-side: call `DELETE https://api.revenuecat.com/v1/subscribers/{app_user_id}` with **secret** API key (NEVER from client).
3. Client-side: `await Purchases.logOut()`.

---

## 7. Paywalls

### Option A — RC Paywalls v2 (recommended)
1. Build paywall in RC dashboard → Paywalls → V2 editor.
2. Show via `RevenueCatUI.presentPaywall(...)` — see [snippets/paywall_widget.dart](snippets/paywall_widget.dart).
3. Result enum: `purchased | restored | cancelled | notPresented | error`.
4. ⚠ Pitfall #11: in `purchases_ui_flutter` 8.5.1, iOS sandbox sometimes returns `cancelled` even after success. Don't trust the result enum alone — also check `customerInfo.entitlements` after dismissal. Fixed in 9.x+ but defensive code recommended.
5. ⚠ Pitfall #12: iOS paywall doesn't auto-dismiss after restore (Android does). Pop the route manually in restore callback.

### Option B — Custom paywall
1. Skip `purchases_ui_flutter` package.
2. `final offerings = await Purchases.getOfferings();`
3. `final current = offerings.current;` — your `default` offering.
4. Iterate `current.availablePackages` to render.
5. Apple App Review requires:
   - Visible **Restore Purchases** button.
   - Visible **Privacy Policy** + **Terms of Use** links.
   - Price + period + auto-renew disclosure for subscriptions.

---

## 8. Webhook server

Why mandatory for production: client-only entitlement is vulnerable to clock manipulation, SDK cache, anonymous→identified gaps, and gives you no source of truth for refunds, billing issues, transfers.

### Setup
1. RC dashboard → Project Settings → Integrations → Webhooks.
2. Set URL (your endpoint).
3. Set **Authorization header value** — a secret you generate. RC sends this in every request's `Authorization` header. (Old `x-revenuecat-signature` was removed — see pitfall #20.)
4. Enable retry on failure (RC retries up to 3 times with backoff).

### Implementation
See [snippets/webhook_handler.js](snippets/webhook_handler.js).

Critical:
- **Authenticate** every request via the Authorization header value match.
- **Idempotent** by event `id` — RC delivers at-least-once.
- **Switch on `event.type`** — granular handling for INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, TRANSFER, REFUND_REVERSED, etc.
- Return 200 quickly. Process async if heavy.

---

## 9. Sandbox testing

### iOS
1. On device: Settings → App Store → **Sandbox Account** → sign in with sandbox tester email.
2. Run app from Xcode (NOT from TestFlight — TestFlight is a hybrid mode with weird quirks).
3. Initiate purchase → sandbox UI appears with sandbox tester confirmation.
4. **Renewal cadence in sandbox**: 24 hours (changed Dec 2024 from minutes — pitfall #8). Plan tests around this OR use Xcode StoreKit Configuration File for fast iteration.
5. Each sandbox tester can only complete a sub cycle a limited number of times — create fresh testers for repeat tests (pitfall #10).

### Android
1. License tester emails (Play Console → Setup → License testing) get the test purchase flow on Internal Testing builds.
2. Open Play Store on device with license tester account.
3. Install app from Internal Testing track URL.
4. Purchase shows "This is a test purchase. You will not be charged."

### TestFlight (iOS)
- Hybrid: prod Apple ID + sandbox-style purchases. Many quirks — prefer Xcode + sandbox tester for most testing.
- Use TestFlight only for end-to-end pre-release validation.
- Use **production** RC API key in TestFlight builds.

---

## 10. Older versions reference

If pinned to older `purchases_flutter`:

| Version | Key differences from v10 |
|---|---|
| v9.x | No Web Billing fully GA; minSdk 21; PurchaseResult API is same as v10 |
| v8.x | StoreKit 2 default introduced; Billing 7; minSdk 21 |
| v7.x | Returns `CustomerInfo` from purchase methods (not `PurchaseResult`); no Web; StoreKit 1 default; iOS 11+ supported |
| v6.x | `Purchases.setup()` deprecated, `configure()` introduced |

⚠ v9 → v10 breaking: removed restore for consumed one-time products. If your dashboard misclassifies a non-consumable as consumable, restoration breaks permanently. Audit product types in RC dashboard before upgrading.

---

## 11. Verification

Run [checklist.md](checklist.md) before considering this skill applied.

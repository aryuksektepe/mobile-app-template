# Third-Party SDK Privacy Manifest Checklist

Apple maintains a list of "commonly-used SDKs" that MUST ship their own `PrivacyInfo.xcprivacy` AND be code-signed. Without both, the binary upload fails with `ITMS-91065`.

## Common SDKs in this template's default stack

Verify each — bump if missing.

| SDK | Pod name(s) | Manifest needed | Verify path |
|---|---|---|---|
| Firebase Core | `Firebase/Core`, `FirebaseInstallations` | yes — present since 10.20+ | `ios/Pods/FirebaseInstallations/PrivacyInfo.xcprivacy` |
| Firebase Auth | `Firebase/Auth` | yes | `ios/Pods/FirebaseAuth/PrivacyInfo.xcprivacy` |
| Firebase Analytics | `Firebase/Analytics` | yes | `ios/Pods/FirebaseAnalytics/PrivacyInfo.xcprivacy` |
| Firebase Crashlytics | `Firebase/Crashlytics` | yes | `ios/Pods/FirebaseCrashlytics/PrivacyInfo.xcprivacy` |
| Firebase Messaging | `Firebase/Messaging` | yes | `ios/Pods/FirebaseMessaging/PrivacyInfo.xcprivacy` |
| Sentry | `Sentry`, `sentry_flutter` | yes — 8.18+ | `ios/Pods/Sentry/PrivacyInfo.xcprivacy` |
| RevenueCat | `RevenueCat`, `PurchasesHybridCommon` | yes — 4.31+ | `ios/Pods/RevenueCat/PrivacyInfo.xcprivacy` |
| Google Sign In | `GoogleSignIn`, `GTMSessionFetcher` | yes — 7.1+ | `ios/Pods/GoogleSignIn/PrivacyInfo.xcprivacy` |
| Sign In with Apple | (system framework) | n/a |  |
| FlutterFire (umbrella) | per-module | yes (in each Firebase pod) | see above |
| `app_links` | `app_links` | yes — 6.0+ | `ios/Pods/app_links/PrivacyInfo.xcprivacy` |
| `flutter_secure_storage` | `flutter_secure_storage` | yes — 9.2+ | `ios/Pods/flutter_secure_storage/PrivacyInfo.xcprivacy` |
| `shared_preferences` | `shared_preferences_foundation` | yes — 2.4+ | `ios/Pods/shared_preferences_foundation/PrivacyInfo.xcprivacy` |
| `permission_handler` | `permission_handler_apple` | yes — 9.4+ | `ios/Pods/permission_handler_apple/PrivacyInfo.xcprivacy` |

## Quick automated check

```bash
# Run from project root
find ios/Pods -name 'PrivacyInfo.xcprivacy' | sort
```

Cross-reference against the SDK list above. Any SDK MISSING the file → bump that pod version OR file a vendor issue OR replace.

## If a vendor refuses to ship a manifest

Options (in order of preference):
1. **Bump to latest** — vendor may have shipped one since you locked.
2. **File a public issue** — vendors are motivated by App Review pain.
3. **Vendor an internal wrapper manifest** — risky; technically a manifest must come from the vendor for signature verification to pass.
4. **Replace the SDK** — last resort.

## Update cadence

Re-run this checklist whenever:
- A new pod is added to `Podfile`.
- `pod install` bumps a major version.
- Apple publishes new Required Reason API categories or expands the "commonly-used SDK" list.
- App Store Connect upload fails with `ITMS-91056` / `91061` / `91065`.

# Privacy Manifest — Full Implementation

## 1. Create the file

`ios/Runner/PrivacyInfo.xcprivacy` (plist format). Use [snippets/PrivacyInfo.xcprivacy](snippets/PrivacyInfo.xcprivacy) as base. Four top-level keys:

| Key | Type | What |
|---|---|---|
| `NSPrivacyTracking` | Bool | True if any IDFA / fingerprint / cross-company data combination for ads |
| `NSPrivacyTrackingDomains` | Array<String> | Domain endpoints your app contacts FOR TRACKING when ATT is granted — match `cname.example.com` style, NOT URLs |
| `NSPrivacyCollectedDataTypes` | Array<Dict> | What you collect, why, whether linked to identity, whether used for tracking |
| `NSPrivacyAccessedAPITypes` | Array<Dict> | Required Reason API categories you call + reason codes |

## 2. Add to Xcode

Open Xcode → Runner target → drag `PrivacyInfo.xcprivacy` into the Runner group → "Create folder references" or "Copy items if needed" → check Target Membership = Runner.

Verify: Build → check `~/Library/Developer/Xcode/DerivedData/<App>/Build/Products/.../Runner.app/PrivacyInfo.xcprivacy` exists in the bundle.

## 3. Required Reason API audit

Run [snippets/audit-privacy-manifest.sh](snippets/audit-privacy-manifest.sh). It greps `ios/`, `lib/`, and all Pods for known API symbols and flags every match. Output:

```
[CA92.1] UserDefaults  — 23 hits (shared_preferences + 4 SDKs)
[3B52.1] FileTimestamp — 7 hits (cached_network_image, image_picker)
[7D9E.1] DiskSpace     — 2 hits (video_player)
[35F9.1] SystemBootTime — 1 hit  (firebase_analytics)
```

Map each line to a reason code (Apple's approved list — see [snippets/PrivacyInfo.xcprivacy](snippets/PrivacyInfo.xcprivacy) for the full reason code table).

## 4. Third-party SDK audit

Apple's "commonly used SDK" list (~80 SDKs) MUST ship a manifest AND a digital signature. If any pod in your `ios/Podfile.lock` is on that list and missing the manifest, upload rejects with `ITMS-91065`.

Run [snippets/sdk-checklist.md](snippets/sdk-checklist.md). For each `pod 'X'`:
1. Open `ios/Pods/X/PrivacyInfo.xcprivacy` — must exist.
2. Open `ios/Pods/X/X.xcframework/_CodeSignature/` — signature must exist.

If missing, bump to the latest SDK version (most major SDKs added manifests in 2024). If still missing, file an issue with the vendor; in extreme cases, replace the SDK.

## 5. NSPrivacyTracking + Tracking Domains

When `NSPrivacyTracking: true`:
- Every endpoint you POST tracking data to MUST be in `NSPrivacyTrackingDomains`.
- When ATT is DENIED, iOS will BLOCK network calls to those domains (DNS resolution returns null). Test this behavior on a denied-ATT device.
- Domain format: `app-measurement.com`, NOT `https://app-measurement.com/abc`.
- Common entries: Firebase Analytics (`app-measurement.com`, `firebaseinstallations.googleapis.com`), Facebook (`graph.facebook.com`), AdMob (`googleads.g.doubleclick.net`).

## 6. Cross-check with App Store Connect

App Store Connect → My App → App Privacy. This form declares data categories. The manifest's `NSPrivacyCollectedDataTypes` MUST match. If they disagree → App Review reject 5.1.

Common collected data types (`NSPrivacyCollectedDataType` values):
- `NSPrivacyCollectedDataTypeEmailAddress` (auth)
- `NSPrivacyCollectedDataTypeName` (profile)
- `NSPrivacyCollectedDataTypeDeviceID` (analytics, ATT-gated)
- `NSPrivacyCollectedDataTypeCrashData` (Crashlytics, Sentry)
- `NSPrivacyCollectedDataTypePerformanceData` (Performance Monitoring)
- `NSPrivacyCollectedDataTypeUserID` (analytics)

For each: declare `NSPrivacyCollectedDataTypeLinked` (linked to identity), `NSPrivacyCollectedDataTypeTracking` (used for tracking), `NSPrivacyCollectedDataTypePurposes` (array of `NSPrivacyCollectedDataTypePurposeAppFunctionality` / `Analytics` / `ProductPersonalization` / `Advertising`).

## 7. Common reject codes

| Code | Meaning | Fix |
|---|---|---|
| ITMS-91056 | Required Reason API not declared | Add the API + reason code to `NSPrivacyAccessedAPITypes` |
| ITMS-91061 | SDK missing manifest | Bump SDK to a version that has one, or replace |
| ITMS-91065 | SDK missing signature | Vendor issue — bump or replace |
| 5.1.x reject | App Privacy form vs manifest mismatch | Reconcile both |

## 8. Updating when adding a feature

Every time `coder` adds:
- A new permission (camera, mic, location, photos) → check if related Required Reason APIs apply.
- A new third-party SDK → re-run [snippets/sdk-checklist.md](snippets/sdk-checklist.md).
- A new tracking integration → update `NSPrivacyTracking` + domains list + App Privacy form.

Make this an item in `compliance` agent's per-phase checklist.

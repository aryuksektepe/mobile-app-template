# ATT — Full Implementation

## 1. Info.plist

Add `NSUserTrackingUsageDescription` (see [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml)). Apple rejects vague strings (5.1.2(i)). Be specific about WHAT data and WHY. Localize via `InfoPlist.strings` for non-EN markets.

## 2. SDK init order (CRITICAL)

Wrong order = IDFA permanently lost for the device's attribution. The canonical order in `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  // OK — core, no tracking yet

  // 1. Init the ATT service (does NOT show prompt yet — just reads cached status).
  await AttService.instance.bootstrap();

  // 2. Conditionally init Analytics with personalization OFF until ATT granted.
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await FirebaseAnalytics.instance.setConsent(
    adStorageConsentGranted: AttService.instance.granted,
    analyticsStorageConsentGranted: true,  // anonymous analytics OK pre-ATT
    adUserDataConsentGranted: AttService.instance.granted,
    adPersonalizationSignalsConsentGranted: AttService.instance.granted,
  );

  // 3. DO NOT init Adjust/AppsFlyer/AdMob here. Gate them until ATT response (step 6).

  runApp(MyApp());
}
```

## 3. Pre-prompt timing

Trigger from a Riverpod listener on `onboardingCompletedProvider` OR after first FR-1 success. NOT from `main()`. NOT from splash. NOT from first tab open.

Inside the pre-prompt screen (see snippets/att_pre_prompt.dart), the "Devam et" button calls:
```dart
await AttService.instance.request();  // shows the SYSTEM prompt
```

## 4. After ATT response

```dart
final status = await AttService.instance.request();
// Re-sync consent state regardless of result
await FirebaseAnalytics.instance.setConsent(
  adStorageConsentGranted: status == TrackingStatus.authorized,
  ...
);
// NOW init Adjust/AppsFlyer with the resolved IDFA (or empty if denied)
await AdjustService.start();
await AdMob.instance.initialize();
```

## 5. SDK timeouts

If the user dismisses the prompt or takes long:
- Adjust `attConsentWaitingInterval` ≤ 360s — set this so first-session attribution doesn't fire prematurely.
- AppsFlyer `waitForCustomerUserId` similar.
- AdMob can buffer SKAdNetwork postbacks; init AFTER ATT response.

## 6. EU + Consent Mode v2

ATT is iOS-only. EU users ALSO need GDPR consent banner before analytics/ads (`consent_mode_v2`). Show the EU banner first (or in parallel on app cold start in EU territory per IP/locale), THEN ATT pre-prompt at the natural moment. The two are independent legal regimes.

## 7. iOS < 14.5 guard

```dart
if (Platform.isIOS) {
  final iosInfo = await DeviceInfoPlugin().iosInfo;
  if (_versionLt(iosInfo.systemVersion, '14.5')) {
    return TrackingStatus.authorized; // pre-ATT iOS — IDFA returned without prompt
  }
}
```

## 8. App Store review

A common reject is 5.1.2(i): "Your purpose string doesn't accurately describe how user data is collected and used." Self-audit: does the string list the actual partners? Is it consistent with the Privacy Manifest's `NSPrivacyTrackingDomains`? Is it consistent with App Store Connect → App Privacy → Data Used to Track You?

The 5.1.2(i) reject also fires if you show ANY pre-prompt that:
- Looks like an Apple UI (avoid black bar / system icons),
- Implies that tapping "Allow" is required to use the app,
- Withholds functionality unless tracking is granted (Apple guideline strict: ATT cannot gate features).

## 9. Reset for QA

Test the prompt repeatedly:
```bash
xcrun simctl privacy <udid> reset tracking <bundle-id>
# Or device: Settings → General → Reset → Reset Location & Privacy
```

`getTrackingAuthorizationStatus()` will return `notDetermined` and the prompt fires again.

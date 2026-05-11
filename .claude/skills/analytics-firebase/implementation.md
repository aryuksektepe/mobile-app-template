# Firebase Analytics — Implementation Guide

## 1. Prerequisite

`firebase-core-setup` skill must be applied first (multi-flavor Firebase projects + flutterfire configure complete).

## 2. Add package

```bash
flutter pub add firebase_analytics
flutter pub add crypto         # for hashing user IDs
flutterfire reconfigure        # so iOS/Android pick up Analytics
cd ios && pod install --repo-update
```

## 3. Default-deny consent (Info.plist + AndroidManifest)

Add the four consent default flags **set to false** so Analytics doesn't collect anything until consent flows complete.

- iOS: paste [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) into `ios/Runner/Info.plist`.
- Android: paste [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml) into `android/app/src/main/AndroidManifest.xml` inside `<application>`.

## 4. Wire Riverpod providers

Use [snippets/analytics_providers.dart](snippets/analytics_providers.dart). Add the observer to GoRouter so screen views fire automatically.

## 5. Define your event taxonomy

Use [snippets/analytics_service.dart](snippets/analytics_service.dart) as the single source of truth for events. Rules:
- snake_case
- ≤40 chars event name, ≤100 chars per param value, ≤25 params per event, ≤500 unique values per param
- never log PII (email, phone, raw user ID, full name, address)
- hash identifiers via `AnalyticsService.hashShort(...)` before logging
- reserved prefixes: NEVER use `firebase_`, `google_`, `ga_` in event/param names

Add one method per event in `AnalyticsService`. Calling code:
```dart
ref.read(analyticsServiceProvider).logPaywallShown(trigger: 'export_button', variant: 'A');
```

## 6. Consent UI flow

Show your consent banner on first launch (or version bump). On user choice:
```dart
final consent = ConsentService();
await consent.apply(ConsentChoice.acceptAll); // or denyAll, or per-flag custom
```

`ConsentService` (in [snippets/consent_handler.dart](snippets/consent_handler.dart)) persists the choice and re-prompts when `currentConsentVersion` changes (bump it when consent text materially changes).

## 7. ATT coordination (iOS only)

If you ALSO use IDFA (Google Ads SDK / Adjust / AppsFlyer):
1. Show your CMP/consent banner FIRST (clear analytics framing).
2. AFTER user accepts analytics, request ATT:
```dart
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

final status = await AppTrackingTransparency.requestTrackingAuthorization();
// granted/denied/restricted/notDetermined
```
3. Apple shows the prompt only **once per install lifetime**. Time it to a moment of clear user value, NOT app launch.

If you do NOT use IDFA → skip ATT entirely. Firebase Analytics uses IDFV (no consent UI for IDFV itself).

## 8. DebugView setup

### iOS — when running from Xcode:
1. Xcode → Edit Scheme → Run → Arguments → Arguments Passed On Launch → add `-FIRDebugEnabled`.
2. Run via Xcode (not `flutter run` from CLI — flag won't apply).
3. Firebase Console → Analytics → DebugView → wait ~10s, you should see your device.

### iOS — when running from CLI (`flutter run`):
The above flag is per-Xcode-launch. For CLI:
- Run from Xcode the FIRST time (flag becomes persisted in user defaults).
- Subsequent CLI runs honor it until you pass `-FIRDebugDisabled`.

### Android:
```bash
adb shell setprop debug.firebase.analytics.app com.acme.myapp.dev
flutter run --flavor dev -t lib/main_dev.dart
```

## 9. BigQuery export (optional but recommended)

1. Firebase Console → Project Settings → Integrations → BigQuery → Link.
2. Pick dataset region (match your Firebase region — Topic 1 §2 §13).
3. Choose **Streaming** (not daily batch) for sub-hour latency.
4. First events appear in BigQuery within 24h.
5. Free tier: ~1M events/day. Verify current quota in console before relying on this for marketing.

## 10. Verify

Run [checklist.md](checklist.md). Critical:
- DebugView shows events from BOTH platforms.
- No `screen_view` events fire when consent denied.
- `(other)` doesn't appear for any of your custom params after a week of data.

# Notifications (FCM + Local) — Implementation Guide

## 1. Prerequisite
- `firebase-core-setup` complete
- Apple Developer Program membership (for APNs)

## 2. Add packages

```bash
flutter pub add firebase_messaging flutter_local_notifications
flutterfire reconfigure
cd ios && pod install --repo-update
```

## 3. iOS — APNs Auth Key

1. Apple Developer Portal → Certificates, Identifiers & Profiles → **Keys** → +
2. Tick **Apple Push Notifications service (APNs)**
3. Download `.p8` (you can only download ONCE — save securely)
4. Note **Key ID** (10 chars) and **Team ID** (10 chars from membership)
5. Firebase Console → Project Settings → Cloud Messaging → **Apple app config**
6. Upload `.p8` + paste Key ID + Team ID
7. **One key works for all your apps and never expires** — much better than legacy certificates

## 4. iOS — Capabilities

In Xcode:
1. Apple Developer portal → Identifiers → your App ID → enable **Push Notifications**
2. Open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities
3. **+ Capability → Push Notifications**
4. **+ Capability → Background Modes** → tick **Remote notifications** AND **Background fetch**
5. Set deployment target ≥ 13.0

Add Info.plist entries from [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml).

## 5. Android — Manifest + permissions + icons

1. Add entries from [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml).
2. **Generate transparent monochrome notification icon**:
   - Android Studio → File → New → Image Asset → Icon Type: **Notification Icons** → upload your logo.
   - Saves to `android/app/src/main/res/drawable-*/ic_notification.png` at all densities.
   - Without transparency you get a white square (pitfall #4).
3. `android/app/build.gradle.kts`:
   ```kotlin
   android {
     defaultConfig {
       minSdk = 24      // raised by flutter_local_notifications 21
       targetSdk = 34   // 35 by Aug 2026 (Play Store mandate)
     }
   }
   ```

## 6. Background handler

[snippets/notifications_bootstrap.dart](snippets/notifications_bootstrap.dart) — top-level function with `@pragma('vm:entry-point')`. Call `registerBackgroundHandler()` from `bootstrap()` AFTER `Firebase.initializeApp()` but BEFORE `runApp()`.

## 7. Foreground handling + tap routing

[snippets/notification_service.dart](snippets/notification_service.dart) — single entry point. Init from a Riverpod provider:

```dart
ref.read(notificationServiceProvider).init();
```

Tap routing uses `pendingDeepLinkProvider` — your GoRouter redirect reads this and navigates AFTER auth state hydrated:

```dart
redirect: (ctx, state) {
  final pending = ref.read(pendingDeepLinkProvider);
  if (pending != null && isLoggedIn) {
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    return pending;
  }
  return null;
},
```

## 8. Permission flow (soft-ask)

DO NOT ask at launch. Use [snippets/soft_ask_permission.dart](snippets/soft_ask_permission.dart) at the right narrative moment (e.g., after onboarding, or when notification has clear value: "Get notified when your order ships").

iOS lets you provisionally authorize (Notification Center only, no banner) — pass `provisional: true` for less-intrusive opt-in.

## 9. Token sync

Use [snippets/token_sync.dart](snippets/token_sync.dart). Call `startSyncing()` after login + permission granted. Call `stopAndDelete()` on logout.

Backend schema: `(user_id, device_id, token, platform, updated_at)`. Send to ALL tokens for a user.

## 10. Rich notifications (iOS only)

For images in push notifications:
1. Xcode → File → New → Target → **Notification Service Extension**, name it `ImageNotification`.
2. **Set the extension's deployment target to match Runner** (mismatch = App Store rejection).
3. In the extension, add the `FirebaseMessaging` SwiftPM package.
4. Use `[FIRMessaging.extensionHelper populateNotificationContentWith:contentHandler:]` in `NotificationService.swift`.
5. Test on a **physical device** — simulator doesn't render images. Image must be HTTPS, ≤300KB.

## 11. OEM battery optimization (Android)

Xiaomi MIUI / Huawei EMUI / OPPO ColorOS aggressively kill background apps, dropping notifications. Mitigation:
- Send with `priority: high` and combination data+notification message.
- Show in-app dialog directing user to "Auto-start" / "Protected apps" settings.
- Consider `disable_battery_optimization` package.
- Document the limitation in your support FAQ.

## 12. Verify

Run [checklist.md](checklist.md). Critical:
- Foreground push displays (via local notification mirror).
- Background push wakes background handler.
- Cold-start tap routes to correct screen after auth ready.
- Token persists across reinstalls (verify in backend table).

---
name: notifications-fcm
description: Push notifications (FCM) + local notifications (flutter_local_notifications) + permission flow + foreground/background/terminated handling + deep-link routing on tap. Token rotation + multi-device support. iOS APNs auth key, Android 13+ POST_NOTIFICATIONS, channel hygiene, rich notifications, OEM battery optimization workarounds. Use whenever push or local notifications are needed.
triggers: [notification, push notification, fcm, firebase_messaging, apns, local notification, notification permission, notification deeplink, notification channel, foreground notification, background message, silent push, notification tab routing, push lands on home, push route allowlist]
platforms: [ios, android]
last_verified: 2026-05-18
flutter_min: "3.38.1"
ios_min: "13.0"
android_min_sdk: 24
package_versions:
  firebase_messaging: "^16.2.0"
  flutter_local_notifications: "^21.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup]
---

# Push & Local Notifications

## What this skill does

- Wires `firebase_messaging` 16.x + `flutter_local_notifications` 21.x.
- Foreground messages displayed via local notifications (FCM does NOT auto-show in foreground).
- Background isolate handler with `@pragma('vm:entry-point')`.
- Notification taps in 3 states (terminated/background/foreground) → deferred deep link routing through Riverpod.
- iOS APNs auth key (.p8) — NOT certificate.
- Android 13+ `POST_NOTIFICATIONS` runtime prompt + Android 8+ channel hygiene.
- Soft-ask permission pattern (NOT permission blast at launch).
- FCM token storage with multi-device awareness (`(userId, deviceId, token)`).
- Rich notifications (image attachments) via iOS Notification Service Extension.

## What this skill does NOT do

- Does NOT implement the marketing send pipeline (use Cloud Functions or your CRM).
- Does NOT handle in-app announcements (separate UX pattern).

## Decision tree

**Q1: Need rich notifications (images)?**
- YES → add iOS Notification Service Extension target. Adds setup complexity but worth it for media-heavy apps.
- NO → text-only is simpler and still effective.

**Q2: Topic-based or token-based addressing?**
- TOPIC (subscribe to `news`, `tr`, `pro_user`) — simple, scalable broadcast, but no audience targeting beyond topic membership.
- TOKEN (per-device) — granular, supports user-specific sends, requires backend to store + manage rotation.
- Most apps need BOTH.

**Q3: Provisional auth on iOS?**
- YES (iOS 12+) — silent delivery to Notification Center, less intrusive permission ask. Best for apps where notifications aren't core.
- NO — full prompt; better engagement when user opts in.

## Quick start

```bash
flutter pub add firebase_messaging flutter_local_notifications
flutterfire reconfigure
```

## Code patterns

| Need | File |
|---|---|
| Background handler + bootstrap | [snippets/notifications_bootstrap.dart](snippets/notifications_bootstrap.dart) |
| NotificationService (init + display + tap routing) | [snippets/notification_service.dart](snippets/notification_service.dart) |
| Soft-ask permission widget | [snippets/soft_ask_permission.dart](snippets/soft_ask_permission.dart) |
| Multi-device token sync | [snippets/token_sync.dart](snippets/token_sync.dart) |
| AndroidManifest entries | [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml) |
| Info.plist entries | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |
| iOS foreground `willPresent` delegate | [snippets/AppDelegate.willPresent.snippet.swift](snippets/AppDelegate.willPresent.snippet.swift) |
| Edge Function: FCM message with OS-level dedup keys | [snippets/edge-fn-dedup-buildFcmMessage.ts](snippets/edge-fn-dedup-buildFcmMessage.ts) |

For full setup (APNs key, NSE target, channel creation, OEM workarounds) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (22 entries). Top 7:
1. Background handler not firing — must be top-level + `@pragma('vm:entry-point')`.
2. iOS dev not receiving — use `.p8` auth key, not legacy `.p12` cert.
3. Foreground notification not shown — FCM does NOT auto-show; mirror via local notifications + iOS AppDelegate `UNUserNotificationCenter` delegate + `willPresent` override.
4. Android white-square icon — adaptive icon with non-transparent bg; need monochrome PNG.
5. Cold-start tap lands on `/` then jumps — pending-link Provider replayed after auth ready.
6. **Hybrid local + FCM çift bildirim** — `apns-collapse-id` (iOS) + Android `notification.tag` deterministic string ile OS-level dedup (pitfalls #17).
7. **Background handler `flutter_local_notifications.initialize()` çağırma** — deadlock; SADECE light işler (pitfalls #19).

## Verification

→ [checklist.md](checklist.md) (16 items: permission flow on iOS+Android, foreground display, cold-start tap routes correctly, token persists across restarts).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_messaging` 16.2.0 + `flutter_local_notifications` 21.0.0
- Depends on: `firebase-core-setup`

# Notifications — Verification Checklist

## Setup
- [ ] `firebase_messaging ^16.2.0` + `flutter_local_notifications ^21.0.0` resolved
- [ ] Android `minSdk = 24` (FLN 21 requirement)
- [ ] iOS deployment target ≥ 13.0
- [ ] APNs `.p8` auth key (NOT `.p12` cert) uploaded in Firebase Console
- [ ] Push Notifications + Background Modes (Remote notifications + Background fetch) capabilities enabled in Xcode
- [ ] Transparent monochrome `ic_notification.png` in `android/app/src/main/res/drawable-*/`
- [ ] `POST_NOTIFICATIONS` permission in AndroidManifest

## Code wiring
- [ ] Background handler is **top-level** function with `@pragma('vm:entry-point')`
- [ ] Background handler calls `Firebase.initializeApp()` itself
- [ ] `FirebaseMessaging.onBackgroundMessage(...)` called after `Firebase.initializeApp` in main
- [ ] Default Android channel created BEFORE first push arrives
- [ ] `onMessage` listener mirrors push to local notification (foreground display)
- [ ] `onMessageOpenedApp` + `getInitialMessage` both wired to `pendingDeepLinkProvider`
- [ ] GoRouter redirect reads + clears `pendingDeepLinkProvider` after auth hydrated

## Permission
- [ ] Soft-ask UI shown at narrative moment, NOT at app launch
- [ ] iOS prompt fires only after soft-ask CTA
- [ ] Android 13+ POST_NOTIFICATIONS prompt triggered correctly
- [ ] Verified provisional flow if used (silent delivery, no banner)

## Token
- [ ] Token persisted to backend after first sign-in
- [ ] `onTokenRefresh` updates backend
- [ ] Logout calls `stopAndDelete()` → token removed from backend + `FirebaseMessaging.deleteToken()`
- [ ] Multi-device tested: phone + tablet under same user → both receive personal push

## Foreground / background / terminated
- [ ] Push received in foreground → banner + sound (via local notification)
- [ ] Push received in background → OS notification appears
- [ ] Push received when app terminated → tap launches app to correct route
- [ ] Tap from background routes correctly without losing state

## Rich notifications (if implemented)
- [ ] iOS NSE target deployment target matches Runner
- [ ] Image displays on physical device (not simulator)
- [ ] Image URL is HTTPS, ≤300KB

## Compliance
- [ ] Privacy policy distinguishes transactional vs marketing pushes
- [ ] Marketing opt-out wired (deletes token + unsubscribes from marketing topics)
- [ ] FCM token declared as data collected in Play Data Safety + App Store Privacy
- [ ] No PII in push payload (or consent obtained for what is included)

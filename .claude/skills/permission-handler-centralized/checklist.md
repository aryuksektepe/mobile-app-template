# Permission Handler — Verification Checklist

- [ ] `permission_handler` ^11.3 in dependencies
- [ ] Single `PermissionService` (no scattered `Permission.X.request()` calls)
- [ ] iOS Info.plist usage strings for every permission the app calls (camera, photos, mic, location, contacts, bluetooth, Face ID)
- [ ] AndroidManifest.xml permissions declared (camera, audio, location, contacts, POST_NOTIFICATIONS, READ_MEDIA_*)
- [ ] `targetSdkVersion >= 33` so Android 13 POST_NOTIFICATIONS prompt fires
- [ ] `isLimited` (partial photo access) handled in UI — does NOT treat as denial
- [ ] `permanentlyDenied` → modal with `openAppSettings()` deep link
- [ ] Just-in-time pattern: permissions asked at moment of need, NOT at app launch
- [ ] Soft-ask screen (custom Dart UI explaining benefit) precedes the system prompt
- [ ] Lifecycle observer invalidates permission providers on app resume
- [ ] iOS location: WhenInUse before Always (sequential)
- [ ] Usage strings specific (App Review 5.1.1 self-audit)
- [ ] E2E test on real device: deny + permanentlyDeny + grant paths all UI-handled

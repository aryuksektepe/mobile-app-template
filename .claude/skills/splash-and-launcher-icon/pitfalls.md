# Splash + Launcher Icon — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | White flash between native splash and Flutter first frame | Native splash auto-removed before Flutter is ready | Call `FlutterNativeSplash.preserve(widgetsBinding: ...)` in main(), then `FlutterNativeSplash.remove()` from your root provider's first-data callback | [flutter_native_splash docs](https://pub.dev/packages/flutter_native_splash) |
| 2 | Android 12+ splash shows a TINY logo (clipped to a circle) | Used a wordmark / wide asset for `android_12.image` (OS masks to circle ~75% of canvas) | Use a 1:1 brand icon, 1152×1152, centered. Wordmark goes in `branding` slot | [Android 12 splash API](https://developer.android.com/develop/ui/views/launch/splash-screen) |
| 3 | iOS dark splash doesn't switch when device is in dark mode | LaunchScreen.storyboard regenerated without `image_dark:` | Add dark variants to config, re-run `dart run flutter_native_splash:create` | flutter_native_splash docs |
| 4 | Notification icon is a white square in tray | Using launcher icon as notification icon; missing transparent monochrome | Generate transparent monochrome PNG via Image Asset Studio; reference via `default_notification_icon` meta-data (skill: `notifications-fcm`) | [Tutorialpedia](https://www.tutorialpedia.org/blog/how-to-change-the-android-notification-icon-status-bar-icon-for-push-notification-in-flutter/) |
| 5 | Android 13 themed icon doesn't appear (user has wallpaper theming on) | `adaptive_icon_monochrome` config missing | Add `adaptive_icon_monochrome: assets/icon/monochrome.png` (white-on-transparent); re-run | [Android themed icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive) |
| 6 | iOS App Icon rejected by App Store — "icon contains transparency" | `remove_alpha_ios: true` missing in config | Add it; re-generate | flutter_launcher_icons docs |
| 7 | Splash logo flipped/cut off in Arabic locale | Logo anchored to start/end, not centered | All splash assets centered (default for `flutter_native_splash`); verify with RTL device locale | Flutter RTL guide |
| 8 | App icon updates on next build, but Android still shows old icon | Android caches launcher icon; needs uninstall + reinstall in some cases | Cold reinstall on test device after every icon change | Android docs |
| 9 | Splash color mismatch (looks slightly off) | Color in pubspec config drifted from design-system token | Source from `design-system.md` color tokens; cross-reference on every brand refresh | this skill's own pattern |
| 10 | Storybook splash works in debug, blank in release | Splash assets not included in pubspec `flutter.assets:` list | Ensure `assets/splash/` and `assets/icon/` are listed | flutter assets docs |

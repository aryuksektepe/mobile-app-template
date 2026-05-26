# Splash + Launcher Icon — Verification Checklist

- [ ] `flutter_native_splash` + `flutter_launcher_icons` in `dev_dependencies`
- [ ] `pubspec.yaml` config blocks present (light + dark variants)
- [ ] Assets exist: `assets/splash/logo.png`, `logo_dark.png`, `android12_icon.png`, `icon/icon_1024.png`, `foreground.png`, `monochrome.png`
- [ ] All asset paths listed under `flutter.assets:`
- [ ] `dart run flutter_native_splash:create` ran clean
- [ ] `dart run flutter_launcher_icons` ran clean
- [ ] iOS LaunchScreen.storyboard regenerated (check git diff)
- [ ] Android `values-v31/styles.xml` created (Android 12+ splash)
- [ ] `remove_alpha_ios: true` — iOS App Icon has no transparency
- [ ] Dark mode splash tested (toggle iOS dark mode + Android dark mode)
- [ ] Android 13 themed icon tested (Settings → Wallpaper & style → Themed icons ON)
- [ ] RTL locale tested (logo centered, not shifted)
- [ ] Cold install on real device — no white flash between splash and first frame
- [ ] Notification icon (separate, white-on-transparent) configured per `notifications-fcm`

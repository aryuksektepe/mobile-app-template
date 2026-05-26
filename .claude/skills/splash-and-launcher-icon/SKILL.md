---
name: splash-and-launcher-icon
description: Splash screen (flutter_native_splash 2.x) + launcher icon (flutter_launcher_icons 0.14+) — covers Android 12+ splash API (mandatory), iOS launch storyboard, dark mode variants, RTL, adaptive icons (Android), light/dark App Icon variants (iOS). Solves the "white flash before app loads" + "white square Android icon" pair. Use as Phase 01 foundation work.
triggers: [splash screen, native splash, launch screen, flutter_native_splash, launcher icon, app icon, flutter_launcher_icons, adaptive icon, android 12 splash, splashScreen, monochrome icon, white flash, white square notification, dark mode icon]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  flutter_native_splash: "^2.4.6"
  flutter_launcher_icons: "^0.14.4"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Splash Screen + Launcher Icon

## What this skill does

- Generates Android 12+ Splash Screen API assets + iOS LaunchScreen.storyboard via `flutter_native_splash`.
- Generates Android adaptive icons (foreground + background + monochrome for themed icons) + iOS App Icons + macOS + web via `flutter_launcher_icons`.
- Dark mode variants for both splash + icon.
- RTL-aware splash (logo centered, not start/end aligned).
- Removes the "white flash" between native splash and Flutter first frame.
- Avoids the Android "white square" notification icon issue (separate from launcher; you also need a transparent monochrome PNG for notifications — see `notifications-fcm`).

## What this skill does NOT do

- Does NOT animate splash (use Flutter `splashScreen` widget AFTER native splash for animation).
- Does NOT replace the in-app loading screen (separate from native splash).

## Decision tree

**Q1: Android 12+ splash API or legacy (pre-12)?**
- Modern (Android 12+) — required. Logo centered, single color background, brand icon only. `flutter_native_splash` handles both old + new via `android_12:` block.
- Legacy — automatically handled too. Don't need to manage manually.

**Q2: Dark mode splash?**
- YES (recommended) — `dark_color: #000000`, `dark_image: assets/splash_dark.png`. iOS uses LaunchScreen.storyboard with dark variants.
- NO — single asset works but feels dated.

**Q3: Adaptive icon (Android) — separate fg/bg?**
- YES (mandatory Android 8+) — `android.adaptive_icon_foreground` + `android.adaptive_icon_background`.
- ALSO add `android.adaptive_icon_monochrome` for Android 13+ themed icons (matches user's wallpaper-derived color).

## Quick start

1. Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_native_splash: ^2.4.6
     flutter_launcher_icons: ^0.14.4
   ```
2. Drop config into `pubspec.yaml` (see [snippets/pubspec.yaml.snippet](snippets/pubspec.yaml.snippet)).
3. Generate:
   ```bash
   dart run flutter_native_splash:create
   dart run flutter_launcher_icons
   ```
4. For Android 12+ splash: ensure `android/app/src/main/res/values-v31/styles.xml` exists (the package creates it).
5. Verify on:
   - Android 13+ device (themed icon matches wallpaper)
   - iOS dark mode (LaunchScreen swaps correctly)
   - RTL locale (logo centered, not shifted)

## Code patterns

| Need | File |
|---|---|
| pubspec config (both packages) | [snippets/pubspec.yaml.snippet](snippets/pubspec.yaml.snippet) |
| Asset prep checklist (sizes + transparency) | [snippets/asset-prep.md](snippets/asset-prep.md) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. White flash between native splash and first Flutter frame → use `flutter_native_splash` with `remove_after_delay` set + `FlutterNativeSplash.remove()` called from your root provider's first-data ready callback.
2. Android 12+ splash showed a TINY logo (the OS clips the icon to a circle) → use the 1:1 brand icon SVG, not the full app icon.
3. iOS dark splash didn't switch → LaunchScreen.storyboard wasn't regenerated; re-run `flutter_native_splash:create` after dark mode added.
4. Android adaptive icon shows white square in notification tray → that's the **notification** icon (separate), needs `default_notification_icon` meta-data + transparent monochrome PNG (skill: `notifications-fcm`).
5. Themed icon (Android 13) doesn't appear → missing `android.adaptive_icon_monochrome` config; OS falls back to colored adaptive icon.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none)

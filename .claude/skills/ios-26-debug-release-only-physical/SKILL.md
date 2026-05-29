---
name: ios-26-debug-release-only-physical
description: iOS 18.4+ / iOS 26+ Apple sıkılaştırılmış `mprotect()`'in Dart JIT executable page'leri reddetmesi nedeniyle, fiziksel iPhone'da DEBUG Flutter build cold-start'ta crash veya white-screen veriyor (özellikle ProMotion cihazlar — iPhone 15/16/17 Pro Max). Untethered launch'ta debugger attached değil → JIT init fail → `platformTaskRunner=null` → `VSyncClient` crash. ÇÖZÜM YOK Flutter tarafında — fiziksel cihazda iteration için RELEASE BUILD + `xcrun devicectl install` kullanmak ZORUNLU. Simulator'da debug + hot reload normal çalışır. Bu skill operasyonel runbook'tur — iOS 26 cihazda phase smoke'u patlamadan önce oku.
triggers: [ios 26, ios 18.4, debug build crash physical, vsyncclient, mprotect, flutter ios jit, beyaz ekran ios, white screen ios cold start, EXC_BAD_ACCESS FlutterViewController, ProMotion crash, iPhone 17 Pro Max debug crash, untethered launch crash, devicectl install, flutter debug doesn't run, debug build doesn't launch]
platforms: [ios]
last_verified: 2026-05-27
flutter_min: "3.38.0"
ios_min: "18.4"
extracted_from_phase: pre-seeded (a production run operational learning)
recurrence_count: 1
validation_status: pre-seeded
depends_on: []
---

# iOS 26 + Flutter Debug Mode — Release-Only on Physical Devices

## Why this skill exists

Apple iOS 18.4'te `mprotect()` enforcement'ı sıkılaştırdı (iOS 26'da daha da sıkı). Dart JIT, debugger attached değilse executable memory page'i oluşturamıyor. Sonuç:

- `flutter run` simulator'da OK ✓
- `flutter run -d <physical-ios-device>` build OK ama "Installing and launching..." takılır → timeout → cihazda manuel açınca beyaz ekran → crash
- Crash imzası: `EXC_BAD_ACCESS` → `-[VSyncClient initWithTaskRunner:callback:]` → `-[FlutterViewController viewDidLoad]`
- ProMotion cihazlarda (iPhone 15+ Pro/Pro Max) garantili patlar — `createTouchRateCorrectionVSyncClientIfNeeded` null taskRunner ile crash

Flutter team'in resmi pozisyonu ([#183900](https://github.com/flutter/flutter/issues/183900)):
> "Launching Flutter iOS apps that were built in debug mode from cold start is not supported currently."

## What this skill does

- iOS 18.4+ fiziksel cihazda iteration için doğru build/install komutlarını verir
- "Çalışmayan çözüm" listesini sunar (boşa zaman harcama önler)
- `qa-test-guide` ve `INTEGRATION_SMOKE` runtime gate'i için cihaz smoke politikasını netleştirir

## What this skill does NOT do

- Engine fix önermez (Flutter team'in işi — [PR #184639](https://github.com/flutter/flutter/pull/184639) takipte)
- Bug avı iş akışını değiştirmez — simulator + debug hâlâ standart geliştirme ortamı
- Android'i etkilemez (Android'de JIT problemi YOK, debug + cihaz sorunsuz)

## Decision tree

**Q1: Bug avlıyorum (kod değişikliği, hot reload lazım)?**
- → **Simulator + `flutter run`** (debug, hot reload, DevTools, breakpoint hepsi çalışır)

**Q2: Cihaz smoke / production fidelity / release davranışı testi?**
- → **Fiziksel cihaz + release build + `xcrun devicectl install`** (production ile aynı, hot reload yok)

**Q3: Performans/jank ölçümü?**
- → **Fiziksel cihaz + profile build** (`flutter run --profile`) — DevTools açılır, AOT compiled, gerçek perf

| Mod | Komut | Hot reload | DevTools | iOS 26 Home screen | App Store |
|---|---|---|---|---|---|
| Debug | `flutter run` | ✓ | ✓ | ❌ crash | ❌ |
| Profile | `flutter run --profile` | ❌ | ✓ | ✓ | ❌ |
| Release | `flutter build ios --release` | ❌ | ❌ | ✓ | ✓ |

## Quick start — fiziksel iPhone'a iteration

```bash
# 1. Build (signed release)
flutter build ios --release --dart-define-from-file=.env
# → build/ios/iphoneos/Runner.app

# 2. UDID al
flutter devices
# Veya:
xcrun devicectl list devices

# 3. Install
xcrun devicectl device install app \
  --device <UDID> \
  build/ios/iphoneos/Runner.app

# 4. Cihazdan manuel aç (Home screen tap) — release mode'da debugger attach yok
```

**Iteration tipik döngü (2-3 dk/sefer):**
- Fix simulator'da → `flutter build ios --release` → `devicectl install` → aç

## Snippet

→ [snippets/install-ios-release.sh](snippets/install-ios-release.sh) — paste-ready bash helper (UDID auto-detect + build + install).

## Pipeline policy (binding)

**`qa-test-guide` ve `INTEGRATION_SMOKE` runtime gate** için iOS 18.4+ fiziksel cihaz smoke senaryoları:

- **İSTENİR**: Release build, `xcrun devicectl install`, cihazdan manuel açılış, ekran ekran walkthrough
- **YASAK**: `flutter run -d <ios-physical>` debug build ile smoke "yapamadım" raporu kabul edilmez — release ile dene
- **Simulator alternatifi**: Cihaz yoksa simulator + debug ile yap, ama phase notunda "physical device unavailable" işaretle

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 3:
1. `devicectl install` "Could not obtain access to one or more requested file system resources" — terminal cwd project root olmalı, OR absolute path ver.
2. **Çalışmayan çözümler listesi** (boşa zaman önler): Flutter version upgrade, UIScene migration, plugin temizleme, DerivedData clear, pod reinstall — hiçbiri JIT/mprotect kök nedenini çözmez.
3. SPM auto-integration (Flutter 3.44'te varsayılan açık) FlutterFire ile çakışır → `flutter config --no-enable-swift-package-manager` + clean + `pod install`.

## Geleceğe not

- Flutter [PR #184639](https://github.com/flutter/flutter/pull/184639) — engine `ptrace_check.cc` iOS 26 için
- Xcode 26.4+ + Flutter 3.44+ → LLDB stop/continue fix ([Issue #184254](https://github.com/flutter/flutter/issues/184254)) — partial fix, hâlâ untethered launch sorunlu
- Apple iOS 27'de policy değişebilir — bu skill'i revalidate et

## Resources

- [Flutter #183900 — VSyncClient crash ProMotion + iOS 26](https://github.com/flutter/flutter/issues/183900)
- [Flutter #163984 — mprotect/JIT iOS 26](https://github.com/flutter/flutter/issues/163984)
- [Flutter Docs — Build modes](https://docs.flutter.dev/testing/build-modes)
- [Apple devicectl docs](https://developer.apple.com/documentation/xcode/devicectl)

## Skill metadata

- Validation status: **pre-seeded** (operasyonel öğrenme — a production run, 2026-05)
- Last verified: 2026-05-27 against Flutter 3.44, Xcode 26.x, iPhone 17 Pro Max iOS 26.x
- Depends on: yok (operasyonel skill, build dependency'si yok)
- Pairs with: [`flutter-build-boot-gate`](../flutter-build-boot-gate/SKILL.md) (cihaz smoke ne demek), [`ios-android-hardening`](../ios-android-hardening/SKILL.md) (release-build hardening akışı)

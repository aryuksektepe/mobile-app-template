# iOS 26 + Debug Mode — Pitfalls Catalog

a production run (2026-05) operasyonel öğrenmelerinden + Flutter issue tracker'dan.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | `flutter run -d <ios-physical>` "Installing and launching..." takılır, timeout | iOS 18.4+ mprotect — JIT debugger attached olmadan executable page açamıyor; Flutter tools install sonrası launch confirm bekliyor ama cihazda Dart engine init fail ediyor | RELEASE build kullan: `flutter build ios --release` + `xcrun devicectl install` + cihazdan manuel aç | [Flutter#183900](https://github.com/flutter/flutter/issues/183900) |
| 2 | App yüklenir, Home screen'den açınca beyaz ekran → kapanır | Untethered launch'ta debugger yok → JIT init fail → `platformTaskRunner=null` → ProMotion VSyncClient null taskRunner ile crash | Aynı: release build, debug atılır | [Flutter#163984](https://github.com/flutter/flutter/issues/163984) |
| 3 | `xcrun devicectl device install app` "Could not obtain access to one or more requested file system resources" | Terminal current directory project root değil; devicectl sandbox app bundle path'ine erişemiyor | `cd` proje root'a OR absolute path ver: `xcrun devicectl device install app --device <UDID> /full/path/to/build/ios/iphoneos/Runner.app` | Apple devicectl docs |
| 4 | Flutter version upgrade (3.38 → 3.44) sorunu çözmüyor | Kök neden Apple iOS tarafında (mprotect policy); Flutter engine fix ([PR #184639](https://github.com/flutter/flutter/pull/184639)) henüz merged/released değil | Boşa zaman harcama — release build pattern'ine geç. Xcode 26.4+ + Flutter 3.44+ partial fix (LLDB stop/continue) ama cold-start untethered hâlâ sorunlu | [Flutter#184254](https://github.com/flutter/flutter/issues/184254) |
| 5 | UIScene migration denenir → başka crash | Flutter 3.38 storyboard timing race (`UIWindowSceneDelegate` ile) | UIScene migration ayrı patch noktası, mprotect ile alakasız — yapma | Flutter team comments on #183900 |
| 6 | Plugin temizleme / pod reinstall / DerivedData clear semptomu değiştirmiyor | Hepsi build cache layer'ı, JIT runtime layer'ı değil | Cache temizliği belki gerekli ama sorunu çözmez; release build'e geç | empirical |
| 7 | CocoaPods install `Encoding::UndefinedConversionError` | macOS shell default encoding UTF-8 değil | `~/.zshrc`'ye `export LANG=en_US.UTF-8` + `export LC_ALL=en_US.UTF-8` (kalıcı); ya da tek seferlik `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install` | CocoaPods README |
| 8 | SPM auto-integration (Flutter 3.44 default ON) FlutterFire build fail | Swift Package Manager + CocoaPods çift-binding linker'da çakışır | `flutter config --no-enable-swift-package-manager` + `flutter clean` + `cd ios && rm -rf Pods Podfile.lock && pod install` | FlutterFire issues |
| 9 | iOS 26 cold-start sonrası ilk `LocalAuthentication.authenticate()` sessizce fail | iOS 26 LocalAuthentication framework transient bug (Apple) | PIN pad fallback otomatik gelsin; UI'da "tekrar dene" butonu; opsiyonel: 100ms gecikme + 1 retry. Bkz `app-lock-pin-biometric` skill | Apple radar (open) |
| 10 | Release build cihazda console log (debugPrint) yok | AOT build, debug attach yok | (a) Release-mode için Sentry/Crashlytics breadcrumb kullan; (b) cihaz sistem log'u: `brew install libimobiledevice && idevicesyslog \| grep -i runner`; (c) crash log: cihaz Settings → Privacy & Security → Analytics Data → `Runner-*.ips`, sonra parse | [libimobiledevice](https://libimobiledevice.org/) |

## Çalışmayan çözüm listesi (boşa zaman harcamayın)

Aşağıdakiler iOS 26 + Flutter debug + fiziksel cihaz cold-start crash'i için ÇÖZÜM DEĞİL:

1. ❌ Flutter version upgrade (3.44 hâlâ etkili)
2. ❌ UIScene migration (başka crash yaratır)
3. ❌ Plugin temizleme (semptom değişir ama crash devam)
4. ❌ Xcode DerivedData temizleme
5. ❌ Pod reinstall
6. ❌ Runner.entitlements değişiklikleri
7. ❌ `flutter clean` + rebuild

**Tek çalışan**: Release build kullan, `devicectl install`, manuel aç.

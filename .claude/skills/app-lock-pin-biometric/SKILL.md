---
name: app-lock-pin-biometric
description: Uygulama içi kilit (PIN + opsiyonel biyometrik) — finance/health/security uygulamaları için standart. PBKDF2-HMAC-SHA256 (120k iter, OWASP 2023) ile flutter_secure_storage'a hashed PIN, constant-time compare, exponential lockout backoff (3 fail → 30s, 60s, 120s, max 300s). MaterialApp.builder overlay gate, gerçek `paused → resumed` ayrımı (iOS biometric dialog / control center / notification drawer = `inactive` — re-lock TETİKLEMEZ; gerçek background = `paused`). iOS app-switcher privacy cover + opsiyonel native blur AppDelegate. Sign-out cleanup. Use whenever the app holds money/PII/private content and the user expects an in-app lock independent of OS lock.
triggers: [app lock, uygulama kilidi, pin lock, biometric lock, faceid lock, fingerprint lock, app-level lock, in-app pin, screen lock, finance lock, privacy lock, app switcher privacy, blur app switcher, local_auth, pin pad, lockout backoff, pbkdf2 pin]
platforms: [ios, android]
last_verified: 2026-05-27
flutter_min: "3.27.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  local_auth: "^2.3.0"
  flutter_secure_storage: "^10.1.0"  # aligned with secure-storage-tokens (canonical) — read/write/delete API unchanged 9→10
  crypto: "^3.0.6"
extracted_from_phase: pre-seeded (production Bug 3, production-validated)
recurrence_count: 1
validation_status: pre-seeded
depends_on: [secure-storage-tokens]
---

# App Lock — PIN + Biometric

## Why this skill exists

OS-level passcode/biyometrik kilidi tüm cihazı korur ama uygulama-içi kilit (App Lock) **paylaşılan cihaz** senaryosunda (eşler arası iPhone, hızlı izleyici, app-switcher önizleme) gizlilik katmanı sağlar. Finance/health/passwords kategorileri için kullanıcı beklentisi.

Bu pattern bir production run'da implementasyon **3 alt-bug** ile sonuçlandı; bu skill bütününü kalıbı verir.

## What this skill does

- `MaterialApp.builder` üzerinden `AppLockGate` overlay → tüm route'lar üstünde kilit ekranı
- Riverpod `NotifierProvider<AppLockController, AppLockState>` state machine
- PBKDF2-HMAC-SHA256 ile PIN hash (`crypto` paketi, 120k iter)
- Constant-time PIN compare (timing attack koruması)
- Exponential lockout backoff: 3 fail → 30s, 4 → 60s, 5 → 120s, max 300s
- `local_auth` biometric (Face ID, Touch ID, Android fingerprint) — opsiyonel opt-in
- Lifecycle state tracking: `paused → resumed` GERÇEK background; `inactive → resumed` (biometric dialog, control center, notif drawer, incoming call) re-lock **TETİKLEMEZ**
- iOS app-switcher privacy cover (Flutter overlay) + opsiyonel native AppDelegate blur
- Sign-out cleanup (storage wipe — başka kullanıcı login olursa eski PIN gelmez)
- Onboarding/login akışında kilit **gösterilmez** (session-gated)
- Settings'te PIN setup / biometric toggle / PIN değiştir / kilit kaldır

## What this skill does NOT do

- OS-level passcode'u yönetmez (Apple/Google'ın işi)
- Local DB içeriğini şifrelemez (ayrı katman — Drift + SQLCipher)
- Auth provider'a (Supabase/Firebase) bağlı değildir; bağımsız çalışır
- Anti-tampering / jailbreak detection değildir (ayrı concern)

## Decision tree

**Q1: Biyometrik zorunlu mu, opsiyonel mu?**
- ZORUNLU → PIN setup'tan sonra biyometrik prompt; kullanıcı reddedebilir ama UX'te öneri öne çıkar
- OPSİYONEL (önerilen) → kullanıcı Settings'ten açar; varsayılan PIN-only

**Q2: PIN uzunluğu?**
- 4 hane: hızlı, düşük entropi (10⁴=10k kombinasyon) — lockout backoff şart
- 6 hane (önerilen): denge — 10⁶=1M kombinasyon, hâlâ hızlı giriş
- 8 hane: bankalar tarzı, üst düzey

**Q3: "PIN unuttum" akışı?**
- Sign-out → re-authenticate → `clearOnSignOut()` → kilit gone. Yeni cihazda yeniden setup gerekir.
- (Daha karmaşık: email recovery token — bu skill scope dışı)

## Quick start

```bash
flutter pub add local_auth flutter_secure_storage crypto
```

iOS — `ios/Runner/Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Uygulamayı açmak için Face ID kullanabilirsiniz.</string>
```

Android — `android/app/src/main/AndroidManifest.xml` permissions:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

Android — `MainActivity.kt` `FlutterFragmentActivity` (BiometricPrompt için ZORUNLU):
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity: FlutterFragmentActivity()
```

## Code patterns

| Need | File |
|---|---|
| State (Notifier + AppLockState) | [snippets/app_lock_controller.dart](snippets/app_lock_controller.dart) |
| MaterialApp.builder overlay gate | [snippets/app_lock_gate.dart](snippets/app_lock_gate.dart) |
| PBKDF2 + constant-time compare storage | [snippets/app_lock_storage.dart](snippets/app_lock_storage.dart) |
| Lifecycle (paused vs inactive) | [snippets/lifecycle_tracker.dart](snippets/lifecycle_tracker.dart) |
| iOS native blur AppDelegate | [snippets/AppDelegate.snippet.swift](snippets/AppDelegate.snippet.swift) |

PIN pad UI ve setup sheet'i proje design-system'inden gelir (skill snippet vermez — generic Material Pad yeterli).

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. `didChangeAppLifecycleState`'te her `resumed`'da `lock()` → biyometrik **sonsuz döngüsü** (Face ID dialog = inactive → resumed → re-lock → tekrar dialog). FIX: `_lastMeaningfulState` ile sadece `paused → resumed` ayrımı.
2. Lockout countdown widget rebuild olmaz, PIN pad disable kalır. FIX: `Timer.periodic(1s) → setState`.
3. `showModalBottomSheet`'te `ref.watch` rebuild tetiklemez (modal kendi route'unda). FIX: `Consumer` ile sar.
4. iOS Face ID device'da `Icons.fingerprint` görünür — UX yanlış. FIX: `getAvailableBiometrics().contains(BiometricType.face)` ile koşullu ikon.
5. iOS 26 cold-start'ta ilk `authenticate()` sessizce fail edebilir (transient). FIX: PIN pad fallback otomatik gelsin, kullanıcı tekrar deneyebilsin.

## Verification

→ [checklist.md](checklist.md) (10 cihaz test maddesi).

## Skill metadata

- Validation status: **pre-seeded** (production validated; 1 proje)
- Last verified: 2026-05-27 against local_auth 2.3.0 (on `flutter_secure_storage` 9.2.2). Pin **bilerek `^10.1.0`'a hizalandı** — canonical `secure-storage-tokens` skill'i ile çakışmaması için; bu skill'in kullandığı `read`/`write`/`delete` API'si 9→10 arasında değişmedi (10.x'in değişikliği Android default cipher'ı). 10.x'e karşı cihaz re-verify'ı pending (kütüphane geneli "ADAPT, VERBATIM değil" etiketiyle tutarlı).
- Depends on: [`secure-storage-tokens`](../secure-storage-tokens/SKILL.md)
- Pairs with: [`ios-26-debug-release-only-physical`](../ios-26-debug-release-only-physical/SKILL.md) (cihazda smoke için release build), [`permission-handler-centralized`](../permission-handler-centralized/SKILL.md) (biometric runtime permission)

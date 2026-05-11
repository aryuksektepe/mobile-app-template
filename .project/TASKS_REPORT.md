# Skill Catalog — Task Report

**Tarih:** 2026-05-10
**Durum:** ✅ Tüm istenen 8 başlık + 5 mobil-app foundation skill'i (toplam **12 yeni skill**) yazıldı. Önceden var olan `subs-revenuecat` ile birlikte toplam **13 skill** mevcut.
**İstatistik:** 115 dosya, 4123 satır SKILL/implementation/pitfalls/checklist + bunca paste-ready snippet, ~668 KB.

---

## Hızlı Özet — Kullanıcının istediği 8 başlık nasıl karşılandı?

| # | İstenen | Yazılan skill |
|---|---|---|
| 1 | Firebase entegrasyonu | [`firebase-core-setup`](../.claude/skills/firebase-core-setup/SKILL.md) |
| 2 | Login / logout | [`auth-firebase-email`](../.claude/skills/auth-firebase-email/SKILL.md) (signOut + tüm auth state) |
| 3 | Promosyon kod oluşturma | [`promo-codes-system`](../.claude/skills/promo-codes-system/SKILL.md) (kendi backend'in — App Store offer kodları RC'de) |
| 4 | Şifre değişikliği akışı | [`auth-firebase-email`](../.claude/skills/auth-firebase-email/SKILL.md) (`changePassword`, recent-login reauth) |
| 5 | Yeni kullanıcı kaydı akışı | [`auth-firebase-email`](../.claude/skills/auth-firebase-email/SKILL.md) (`signUp` + email verification) |
| 6 | Onboarding akışları | [`onboarding-flow`](../.claude/skills/onboarding-flow/SKILL.md) |
| 7 | Google ile login | [`auth-google-signin`](../.claude/skills/auth-google-signin/SKILL.md) (v7+ yeni API) |
| 8 | Apple ile login | [`auth-apple-signin`](../.claude/skills/auth-apple-signin/SKILL.md) (Apple guideline 4.8 zorunlu) |

**Ek olarak hazırlanan 5 foundation skill** (her ciddi mobil app için temel):
- `secure-storage-tokens` (auth tokens, biometric — login akışıyla beraber gelir)
- `analytics-firebase` (event tracking — kullanıcı davranışı için zorunlu)
- `crash-monitor-dual` (Crashlytics + Sentry — production'da olmazsa olmaz)
- `notifications-fcm` (push — yine yaygın gereksinim)
- `deeplinks-go-router` (Universal Links + App Links — referral, email link callback)
- `remote-config-firebase` (feature flags + A/B test — onboarding A/B için gerekli)

---

## Tüm skill'lerin tam listesi ve ne yaptıkları

### Foundation (önce bunları kur)

#### 1. `firebase-core-setup` 🏗
**Ne yapar:** FlutterFire 4.x foundation. Multi-flavor (dev/staging/prod) için ayrı Firebase projeleri, `flutterfire_cli` automation script'i, App Check (iOS DeviceCheck + Android Play Integrity), debug provider fallback.
**Niye gerekli:** Her Firebase ürünü (Auth, Firestore, Analytics, Crashlytics, Remote Config, FCM) buna depend eder. İlk fazda kurulur, sonra tüm Firebase skill'leri üzerine bina edilir.
**Pitfall sayısı:** 13 (duplicate-app, region irreversibility, Play Integrity SHA, App Check debug token register).

#### 2. `secure-storage-tokens` 🔐
**Ne yapar:** `flutter_secure_storage` 10.x — Keychain (iOS) + Keystore (Android v10 yeni cipher) backed token storage. Refresh-token mutex (concurrent refresh race önler), iOS Keychain'in uninstall'da kalmasına karşı fresh-install wipe pattern, Dio AuthInterceptor (401 → refresh → retry).
**Niye gerekli:** Auth token'larını shared_preferences'a koyma; KVKK + güvenlik açığı. Her auth tabanlı app'te lazım.
**Pitfall sayısı:** 14 (iOS uninstall trap, BadPaddingException, biometric lockout, refresh token replay).

#### 3. `analytics-firebase` 📊
**Ne yapar:** Firebase Analytics (GA4) — type-safe `AnalyticsService` wrapper, snake_case enforcement, **Consent Mode v2** (4 flag — KVKK/GDPR ZORUNLU Temmuz 2025'ten beri), default-deny → user accepts → flip, BigQuery export, ATT coordination.
**Niye gerekli:** Hiçbir mobile app analytics olmadan ship edilmez. Consent Mode v2 olmadan EEA personalization sessizce kapanır.
**Pitfall sayısı:** 14 (DebugView CLI quirks, PII rules, high-cardinality "(other)", screen tracking with custom routers).

#### 4. `crash-monitor-dual` 💥
**Ne yapar:** Firebase Crashlytics + Sentry **dual** setup. Crashlytics native crash'lerde reliable, Sentry breadcrumbs/source maps/release tracking için zengin. PII scrubber (`beforeSend`), opaque hashed user IDs, dSYM + obfuscation map upload.
**Niye gerekli:** Production'da hangi crash'ler oluyor, hangi release'de? Tek başına Crashlytics yeter ama daily triage için Sentry UX çok daha iyi.
**Pitfall sayısı:** 14 (obfuscation maps, runZonedGuarded legacy, PII leakage, NDK coverage).

#### 5. `remote-config-firebase` 🚦
**Ne yapar:** Firebase Remote Config — feature flags, A/B test variants, kill switches, force-update gate. Real-time updates (since v4), typed `AppConfig` freezed model, non-blocking fetch.
**Niye gerekli:** App Store onayı beklemeden feature toggle, A/B test, maintenance mode, force update. Onboarding A/B varyantı için zorunlu.
**Pitfall sayısı:** 14 (12h cache surprise, defaults zorunlu, real-time storm, never gate legal/compliance with RC).

#### 6. `deeplinks-go-router` 🔗
**Ne yapar:** Universal Links (iOS) + App Links (Android) + go_router 17.x. AASA + assetlinks.json hosting, multi-flavor SHA management, **Firebase Dynamic Links DEAD as of Aug 25 2025** notu. URL whitelist + sanitization.
**Niye gerekli:** Email verification link app'i açsın diye, referral linkler için, marketing campaign link'leri için. FDL kapandığı için bu skill'in pattern'i kritik.
**Pitfall sayısı:** 16 (AASA Content-Type, Apple CDN 7-day cache, Play App Signing SHA mismatch, javascript: scheme injection).

### Auth flow skills (Phase 02)

#### 7. `auth-firebase-email` 📧
**Ne yapar:** Firebase Auth 6.x email/password — signup, signin, **signout** (full state clear), **email verification**, **password reset**, **password change** (recent-login reauth), **email change** (`verifyBeforeUpdateEmail` — v6'da `updateEmail` deprecate oldu), **account linking** (anonymous → email), **biometric reauth** (`local_auth`), **KVKK-compliant account deletion** (Apple 5.1.1(v) Jun 2022 + Play Dec 2023 mandate). Email enumeration protection-aware error mapping.
**Niye gerekli:** Login/logout/şifre/kayıt — kullanıcının istediği 4 başlığın 4'ü buraya düşüyor.
**Pitfall sayısı:** 16 (`invalid-credential` enumeration trap, anonymous link broken, `verifyBeforeUpdateEmail` quirk, action code expiry, orphan data after delete).

#### 8. `auth-google-signin` 🔑
**Ne yapar:** Google Sign In **v7+** (yepyeni API: `initialize` + `authenticate` + `authorizationClient`). Multi-flavor SHA-1+SHA-256 (debug + upload + **Play App Signing** — en sık unutulan), `serverClientId` mandatory (v7.1+), FedCM (mandatory Chrome 139+, Aug 2025), authentication ≠ authorization scopes, signOut vs disconnect.
**Niye gerekli:** Sosyal login en yaygın opsiyon; v7 API'si tamamen değişti — eski tutorial'ların hepsi yanlış.
**Pitfall sayısı:** 17 (code 12500 Play App Signing, `clientConfigurationError`, account picker, Apple guideline 4.8 zorunluluğu).

#### 9. `auth-apple-signin` 🍎
**Ne yapar:** Sign in with Apple 8.x + Firebase. **Nonce dance** (SHA256 → Apple, raw → Firebase), **name capture race condition** (Apple ismi sadece İLK sign-in'de döner — kaçırırsan ebediyen kayıp), **Hide-My-Email relay handling** (sender domain register), **token revocation on delete** (Apple App Review aktif test ediyor — yapmazsan reject), Service ID setup (Android/Web).
**Niye gerekli:** iOS'ta Google login varsa, Sign in with Apple OLMAK ZORUNDA (guideline 4.8 — direkt reject sebebi).
**Pitfall sayısı:** 18 (`invalid OAuth response`, displayName null, App Review revoke check, Hide-My-Email bouncing).

### Diğer mobil-app foundation

#### 10. `notifications-fcm` 🔔
**Ne yapar:** Push (FCM) + local notifications. Foreground/background/terminated 3-state handling, `@pragma('vm:entry-point')` background isolate, soft-ask permission pattern (NOT app launch), Android 13+ POST_NOTIFICATIONS, channel hygiene, multi-device token sync, iOS rich notifications (NSE), OEM (Xiaomi/Huawei) battery quirks.
**Niye gerekli:** Push olmadan re-engagement çok düşer. Permission flow yanlış yapılırsa %90+ denial.
**Pitfall sayısı:** 14 (white-square icon, APNs `.p8` not `.p12`, foreground display, channel immutability).

#### 11. `onboarding-flow` 👋
**Ne yapar:** İlk-açılış onboarding (3-5 ekran — research: 5+ ekranda %21-72 drop-off), A/B varyantı Remote Config'den (sticky bucketing), **soft-ask permission pattern** (notification/location/ATT'yi hemen isteme — sonraya bırak), deep-link replay (kullanıcı `/promo/X` linkinden geldi → onboarding bittiğinde orada açılır), Riverpod state, RTL + accessibility.
**Niye gerekli:** Kullanıcı edinme funnel'inin en kritik aşaması. ATT/notification permission timing yanlış olursa monetization öldürür.
**Pitfall sayısı:** 14 (iOS Keychain reinstall trap, ATT one-shot, A/B variant flicker, deep link eaten).

#### 12. `promo-codes-system` 🎟
**Ne yapar:** Kendi server-side promo kod sisteminiz (NOT App Store offer codes — onlar RC'de). Firestore + Cloud Functions, Crockford Base32 alphabet (I/L/O/U yok — `BLACKFRIDAY30`'da 0/O karışmaz), atomik Firestore transaction (last-N kod yarış koşulu önlenir), **App Check enforced** (script abuse blocker), per-user rate limit, **referral two-sided rewards** (referrer'a kredi referee CONVERT olunca, signup'ta değil), RevenueCat REST entegrasyonu (paid sub grant — Apple App Review uyumlu).
**Niye gerekli:** Marketing kampanyaları, viral growth, retention. Apple 3.1.1 kuralından dolayı paid içeriği bypass etmemek için RC promotional entitlements üzerinden gitmek şart.
**Pitfall sayısı:** 17 (atomicity, case mismatch, codes leaking to Analytics, App Check enforcement, App Review 3.1.1 rejection).

### Önceden mevcut

#### 13. `subs-revenuecat` 💳 (önceki turda yazıldı)
**Ne yapar:** RevenueCat 10.x subscriptions/IAP. Init, App Store Connect + Play Console setup, Riverpod entitlement provider, paywalls v2 GA, webhook server (idempotent), KVKK-compliant account deletion (3-step backend purge).
**Niye gerekli:** Subscription monetization için fiili standart. RC olmadan StoreKit/Billing ile direkt çalışmak çok daha riskli.
**Pitfall sayısı:** 25 (Paid Apps Agreement, anonymous→identified TRANSFER webhook quirk, restore Apple ID mismatch).

---

## Mimari kararlar — neden bu seçimler?

### Skill bağımlılık zinciri

```
firebase-core-setup ┌── analytics-firebase
                    ├── crash-monitor-dual
                    ├── remote-config-firebase
                    ├── notifications-fcm
                    ├── auth-firebase-email ┌── auth-google-signin
                    │                       └── auth-apple-signin
                    └── promo-codes-system

secure-storage-tokens ── (kullanılır: auth-firebase-email + onboarding-flow + auth interceptors)

deeplinks-go-router ── (kullanılır: promo-codes-system + onboarding-flow + auth callbacks)

subs-revenuecat ── (Firebase'den bağımsız)

onboarding-flow (depends on: secure-storage-tokens + remote-config-firebase)
```

### Phase önerisi (yeni proje başladığında)

**Phase 01 — Foundation** (ilk gün, tek seferde):
1. `firebase-core-setup`
2. `secure-storage-tokens`
3. `analytics-firebase`
4. `crash-monitor-dual`
5. `remote-config-firebase`
6. `deeplinks-go-router`

**Phase 02 — Auth & Onboarding**:
7. `auth-firebase-email`
8. `auth-google-signin` (ihtiyaç varsa)
9. `auth-apple-signin` (Google iOS'ta varsa zorunlu)
10. `onboarding-flow`

**Phase 03+ — Feature-driven** (proje gereksinimine göre):
11. `notifications-fcm`
12. `subs-revenuecat`
13. `promo-codes-system`

### Validation status

Tüm 13 skill **`pre-seeded`** durumunda. Bu ne demek?
- Araştırmayla yazıldılar, gerçek bir projede henüz test edilmediler.
- İlk projede kullanıldığında: VERBATIM kopyalama YERİNE ADAPT. Bulduğun yeni pitfall'ları ilgili skill'in `pitfalls.md`'sine append et.
- 2 başarılı gerçek-proje deployment'ından sonra → `validation_status: battle-tested` yap. O zaman VERBATIM kullanılır, token + zaman tasarrufu maksimum.

---

## Doğrulanan teknik vurgular (2025-2026 değişiklikleri)

| Konu | 2026-05-10 itibariyle |
|---|---|
| `firebase_core` | 4.7.0 (FlutterFire 4.12.0 release train) |
| `firebase_auth` | 6.4.0 (v6: `updateEmail` removed → `verifyBeforeUpdateEmail`; `fetchSignInMethodsForEmail` removed for enum protection) |
| `firebase_analytics` | 12.3.0 |
| `firebase_crashlytics` | 5.2.0 |
| `firebase_remote_config` | 6.4.0 (real-time `onConfigUpdated` since v4) |
| `firebase_messaging` | 16.2.0 |
| `flutter_local_notifications` | 21.0.0 (raised min Android API to 24) |
| `firebase_app_check` | 0.4.x |
| `purchases_flutter` (RC) | 10.0.2 (StoreKit 2 default, Billing 8.3, Paywalls v2 GA) |
| `google_sign_in` | 7.2.0 (NEW initialize/authenticate/authorizationClient API) |
| `sign_in_with_apple` | 8.0.0 (Flutter min raised to 3.41.0) |
| `flutter_secure_storage` | 10.1.0 (custom RSA+AES Keystore default; EncryptedSharedPreferences deprecated) |
| `go_router` | 17.2.3 |
| `app_links` | 7.0.0 (replaces dead `firebase_dynamic_links` — FDL shut down Aug 25 2025) |

### Kritik 2025-2026 değişiklikler not edildi

- **Firebase Dynamic Links SHUT DOWN** Aug 25, 2025 — `deeplinks-go-router` skill'i replacement options'ı belgeliyor (Branch, AppsFlyer, roll-your-own).
- **Apple Server-to-Server Notifications V2** zorunlu (RC için kritik — V1 olursa renewal eventleri kaçar).
- **TestFlight subscription renewal cadence** Aralık 2024'te dakikalardan **24 saate** çıktı.
- **Chrome 139+ FedCM mandatory** (Aug 2025) — Google Sign In web flow.
- **Consent Mode v2** Temmuz 2025'ten beri EEA personalization için zorunlu.
- **Apple guideline 4.8** revizyon — sosyal login varsa SIWA zorunlu.
- **RevenueCat $2.5K MTR** ücretsiz tier'ı (eski $10K rakamı yanlıştı).
- **Apple Privacy Manifest** Mayıs 2024'ten beri tüm yeni app'ler için zorunlu.
- **EncryptedSharedPreferences** Nisan 2025'te Google tarafından deprecate edildi → `flutter_secure_storage` v10 yeni cipher'a geçti.

---

## Toplam Pitfall Sayısı

**193 unique pitfall** kataloğa girdi (her biri Symptom + Cause + Fix + Source URL ile):

| Skill | # |
|---|---|
| firebase-core-setup | 13 |
| analytics-firebase | 14 |
| crash-monitor-dual | 14 |
| remote-config-firebase | 14 |
| notifications-fcm | 14 |
| secure-storage-tokens | 14 |
| onboarding-flow | 14 |
| deeplinks-go-router | 16 |
| promo-codes-system | 17 |
| auth-firebase-email | 16 |
| auth-google-signin | 17 |
| auth-apple-signin | 18 |
| subs-revenuecat (önceden) | 25 |

Bu sayede gelecek projelerde "aa bu güncellenmiş", "aa bu böyle değilmiş", "aa bu deprecate olmuş" diye saatler harcamayacaksın — pitfall katalogları zaten 2025-2026 değişikliklerini yakalamış.

---

## Senin için kritik bilmen gereken 5 şey

### 1. Tüm skill'ler `pre-seeded`, henüz battle-tested değil
İlk projede kullanırken, snippet'leri olduğu gibi kopyala-yapıştır YAPMA. ADAPT et. Bulduğun yeni bug/quirk'leri ilgili `pitfalls.md`'ye ekle. 2 başarılı projeden sonra `validation_status` upgrade.

### 2. Skill'ler birbirine bağımlı — sırasıyla kur
Phase önerisini takip et. `firebase-core-setup` her şeyden önce kurulmalı. `secure-storage-tokens` auth'tan önce. `auth-apple-signin` `auth-google-signin`'den hemen sonra (4.8).

### 3. Apple App Review için kritik 3 nokta
- **Sign in with Apple** (4.8) — Google login varsa zorunlu.
- **Account deletion in-app** (5.1.1(v)) — Settings'ten ≤2 tap erişilebilir.
- **Apple token revoke on delete** — `revokeTokenWithAuthorizationCode` çağırmazsan reddediliyorsun.

Üç noktayı da `auth-apple-signin` + `auth-firebase-email` skill'leri kapsıyor.

### 4. KVKK/GDPR için kritik 4 nokta
- **Consent Mode v2** (analytics-firebase) — 4 flag, default-deny.
- **Account deletion 30-day finalization** (auth-firebase-email + onUserDelete Cloud Function).
- **Cross-border transfer disclosure** — Firebase US, Sentry US (EU region opsiyonel), Apple/Google US.
- **Privacy Manifest** (iOS, Mayıs 2024+) — `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` minimum.

### 5. Skill'leri kullanırken
- coder agent her task öncesi `INDEX.md` okuyacak şekilde tasarlanmış (CLAUDE.md §7).
- `triggers` field'ı match yaparsa SKILL.md'yi açıp izliyor.
- Match olmazsa scratch'ten yapıyor + `skills_to_extract`'e ekliyor.
- skill-extractor faz sonunda yeni skill çıkartıyor.

---

## Eksik kalan / sonraki tur için öneri

Hemen ihtiyaç olmayan ama bir sonraki turda eklenebilir skill'ler (öncelik sırasıyla):

1. **`forms-validation`** — `formz` veya manuel TextEditingController + form validation pattern (TextFormField + validators + submit state).
2. **`drift-database`** — Drift (Isar abandoned) ile local DB schema, migrations, Riverpod entegrasyonu.
3. **`networking-dio`** — Dio + retry + cache + cancel-on-dispose pattern (AuthInterceptor zaten secure-storage-tokens'da).
4. **`localization-l10n`** — `flutter gen-l10n` setup, ARB workflow, RTL test, dynamic locale switch.
5. **`payments-stripe`** — Stripe iframe / Apple Pay / Google Pay (RC subscription dışında one-time payments için).
6. **`media-upload`** — `image_picker` + Firebase Storage + compression + progress.
7. **`testing-patterns`** — mocktail patterns, golden tests with Alchemist, integration_test setup.

---

## Sonraki turn'de senden bekliyorum

1. **"Şu skill'i şu projede denedim, X'te problem çıktı"** → o skill'in `pitfalls.md`'sine append + fix.
2. **"Y skill'inin Z bölümünü değiştirelim"** → revize ederim.
3. **"Şu yukarıdaki listeden A skill'ini hemen istiyorum"** → araştırıp aynı detay seviyesinde yazarım.
4. **"İyi iş, bir test projesi başlatalım"** → `/start-project` ile pipeline'ı başlatıp foundation skill'leri kullanırız.
5. **"Validation status'ları battle-tested'a çekelim"** → 2 gerçek proje deployment'ından sonra promotion.

Tüm dosyalar `.claude/skills/<slug>/` altında. INDEX.md'den her skill'e tıklanabilir.

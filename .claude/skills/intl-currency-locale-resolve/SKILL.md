---
name: intl-currency-locale-resolve
description: Dart `intl` package — `NumberFormat.currency(locale: 'tr', name: 'TRY')` SESSİZCE fallback yapar ve `'TRY 79.99'` döner; doğru çıktı `'₺79,99'` için locale TAM olmalı (`'tr_TR'`). Deno'nun `Intl.NumberFormat('tr-TR')`'i otomatik resolve eder, Dart `intl` etmez — Edge Function ile mobil arasında ÇİFT FORMAT bug'ı (örn. iki bildirim aynı tutar farklı format) klasik kaynak. Bu skill resolve helper'ı + locale eşleme tablosunu verir. Use whenever currency/date/number formatting is shown to the user.
triggers: [intl currency, NumberFormat currency, TRY 79.99 fallback, currency symbol missing, tr_TR locale, locale short code, double notification different format, currency format wrong, ₺ symbol not showing, intl locale resolve]
platforms: [ios, android]
last_verified: 2026-05-27
flutter_min: "3.0.0"
package_versions:
  intl: "^0.20.0"
extracted_from_phase: pre-seeded (production Bug 11 — çift bildirim format mismatch)
recurrence_count: 1
validation_status: pre-seeded
depends_on: []
---

# intl Currency / Date — Locale Resolve

## Why this skill exists

Dart `intl` package'ı `NumberFormat.currency(locale: 'tr', name: 'TRY').format(79.99)` çağrıldığında **sessizce fallback** yapar:
- Beklenen: `'₺79,99'`
- Fiili: `'TRY 79.99'` (sembol gelmez, ondalık ayırıcı yanlış)

Sebep: `intl` `'tr'` kısa kodunu locale data tablosunda **tam** bulamaz; `'tr_TR'` (region eklenmiş) bulur. Aynı bug `'en'`, `'es'`, `'de'`, `'pt'`, `'ja'` için de geçerli.

**Production'da nasıl yakalanır**: Genelde içerikte sembol farklılığı olarak görünür — ÖZELLİKLE **çift bildirim** senaryosunda (local + FCM aynı anda) iki bildirim aynı tutar için farklı format gösterir, çünkü server tarafı (Deno `Intl.NumberFormat('tr-TR', ...)`) otomatik resolve eder ama Dart etmez.

## What this skill does

- `resolveLocale(String shortCode)` helper'ı — kısa kodu tam locale'e map'ler
- `NumberFormat.currency` + `DateFormat` doğru kullanım pattern'i
- Server (Deno) ile parity testi nasıl yazılır

## What this skill does NOT do

- Locale seçimi PRD §16 işi — bu skill verilen locale'i FORMATLAR, locale belirlemez
- ARB / translation yönetmez — `localization` agent'ı işi

## Quick start

```dart
String resolveLocale(String shortCode) => switch (shortCode) {
  'tr' => 'tr_TR',
  'en' => 'en_US',
  'es' => 'es_ES',
  'de' => 'de_DE',
  'pt' => 'pt_BR',
  'ja' => 'ja_JP',
  'ar' => 'ar_SA',
  'fr' => 'fr_FR',
  'it' => 'it_IT',
  _ => 'en_US',
};

// Kullanım:
final amount = NumberFormat.currency(
  locale: resolveLocale(userLocale), // 'tr' → 'tr_TR'
  name: 'TRY',
).format(79.99);
// → '₺79,99' ✓
```

## Code patterns

| Need | File |
|---|---|
| Resolve helper + tests | [snippets/intl_locale.dart](snippets/intl_locale.dart) |

## Initialization (bir kere main()'de)

```dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // tüm locale'leri yükle
  runApp(const MyApp());
}
```

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 3:
1. `NumberFormat.currency(locale: 'tr', ...)` sessiz fallback → `'TRY 79.99'`. FIX: tam locale (`'tr_TR'`).
2. `DateFormat.yMMMd('tr')` çalışır ama haftaiçi (`E`) gibi pattern'ler boş döner — date formatting de tam locale ister.
3. Server-client format mismatch (Deno otomatik resolve, Dart yapmaz) → çift bildirim aynı tutar farklı format. FIX: server tarafı da `'tr-TR'` (BCP 47, hyphen) kullansın, mobil `'tr_TR'` (POSIX, underscore) kullansın — semantik eş.

## Verification

→ [checklist.md](checklist.md) (5 maddelik kısa liste).

## Skill metadata

- Validation status: **pre-seeded** (production Bug 11)
- Last verified: 2026-05-27 against `intl` 0.20.0
- Depends on: yok

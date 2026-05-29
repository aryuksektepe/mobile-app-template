# intl Currency / Locale — Pitfalls Catalog

production Bug 11 + Dart intl GitHub issues.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | `NumberFormat.currency(locale: 'tr', name: 'TRY').format(79.99)` → `'TRY 79.99'` (sembol yok, `.` ondalık) | `intl` package'ı `'tr'` kısa kodunu locale data tablosunda bulamıyor, sessizce ICU default fallback | `resolveLocale('tr')` → `'tr_TR'` kullan. Bkz `snippets/intl_locale.dart` | [dart-lang/i18n#143](https://github.com/dart-lang/i18n/issues/143) |
| 2 | `DateFormat.E('tr').format(date)` boş string döner | Date pattern symbols `'tr'` kısa kodunda eksik | `DateFormat.E(resolveLocale('tr')).format(date)` + `initializeDateFormatting()` main()'de | [intl docs](https://pub.dev/packages/intl) |
| 3 | Çift bildirim (local + FCM) aynı tutar farklı format gösterir (`₺79,99` vs `TRY 79.99`) | Server (Deno) `Intl.NumberFormat('tr-TR', ...)` otomatik resolve eder; mobil (Dart intl) kısa kod'u resolve edemediği için fallback'e düşer | Mobile tarafı `resolveLocale()` ile tam locale kullansın; server tarafı zaten BCP 47 hyphen ile çalışıyor (`'tr-TR'`) → çıktı aynı | empirical (production Bug 11) |
| 4 | `initializeDateFormatting()` çağrılmamış → date format runtime crash | Locale data lazy-load, ilk DateFormat çağrısından önce init şart | `main()`'de `await initializeDateFormatting()` (await ZORUNLU — sync değil) | [intl init docs](https://pub.dev/documentation/intl/latest/intl/initializeDateFormatting.html) |
| 5 | Web build size patladı (locale data tüm dillerle gelir) | Default init tüm locale'leri yükler | `initializeDateFormatting('tr_TR')` ile spesifik locale + multi-locale app'te `intl_utils` codegen ile tree-shake | [intl_utils](https://pub.dev/packages/intl_utils) |
| 6 | `currencySymbol: '₺'` parametresi gönderilmesine rağmen output yine `TRY` | `name` ve `symbol` ikisi de geçilirse priority kuralları locale-bağımlı; tam locale resolve edilmediğinde override beklendiği gibi çalışmaz | Önce `resolveLocale()` ile tam locale, sonra `name: 'TRY'` yeterli. `symbol` parametresini elle override etmek workaround değil, fix değil | empirical |

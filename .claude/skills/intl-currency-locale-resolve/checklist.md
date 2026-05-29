# intl Currency / Locale — Verification Checklist

```
[ ] main()'de `await initializeDateFormatting()` çağrılıyor
[ ] Tüm `NumberFormat.*` / `DateFormat.*` çağrıları `resolveLocale()` üzerinden geçiyor
    (grep: `NumberFormat\(locale:|DateFormat\(locale:|NumberFormat\.currency\(locale:`)
[ ] Test: TRY → '₺' içeriyor, ',' ondalık ayırıcı (snippets/intl_locale.dart altında örnek test var)
[ ] Test: USD → '$' içeriyor, ',' binlik ayırıcı
[ ] Server-client parity: aynı amount, aynı locale → aynı formatted string
    (Edge Function `Intl.NumberFormat('tr-TR', ...)` ↔ mobil `resolveLocale('tr')`)
```

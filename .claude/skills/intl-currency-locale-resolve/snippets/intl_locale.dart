// Dart intl locale resolver — short code → full locale.
// See SKILL.md for why this is necessary.

/// Map a short locale code ('tr', 'en') to the full POSIX locale ('tr_TR',
/// 'en_US') that the `intl` package can actually resolve.
String resolveLocale(String shortCode) => switch (shortCode.toLowerCase()) {
      'tr' => 'tr_TR',
      'en' => 'en_US',
      'en-gb' || 'en_gb' => 'en_GB',
      'es' => 'es_ES',
      'de' => 'de_DE',
      'fr' => 'fr_FR',
      'it' => 'it_IT',
      'pt' => 'pt_BR',
      'pt-pt' || 'pt_pt' => 'pt_PT',
      'ja' => 'ja_JP',
      'ko' => 'ko_KR',
      'zh' || 'zh-cn' || 'zh_cn' => 'zh_CN',
      'zh-tw' || 'zh_tw' => 'zh_TW',
      'ar' => 'ar_SA',
      'ru' => 'ru_RU',
      'nl' => 'nl_NL',
      'pl' => 'pl_PL',
      'sv' => 'sv_SE',
      'fi' => 'fi_FI',
      'no' => 'nb_NO',
      'da' => 'da_DK',
      'cs' => 'cs_CZ',
      _ => 'en_US',
    };

/// BCP 47 form (hyphen separator) — for server APIs / Intl.NumberFormat in JS/TS.
String toBcp47(String posixLocale) => posixLocale.replaceAll('_', '-');

// ---- Test (drop in test/intl_locale_test.dart) ----
//
// import 'package:flutter_test/flutter_test.dart';
// import 'package:intl/intl.dart';
// import 'package:intl/date_symbol_data_local.dart';
// import 'package:your_app/core/i18n/intl_locale.dart';
//
// void main() {
//   setUpAll(() async => initializeDateFormatting());
//
//   test('TRY formats with ₺ symbol when locale is resolved', () {
//     final out = NumberFormat.currency(
//       locale: resolveLocale('tr'),
//       name: 'TRY',
//     ).format(79.99);
//     expect(out, contains('₺'));
//     expect(out, contains(','));   // Turkish decimal separator
//     expect(out, isNot(contains('TRY 79.99')));
//   });
//
//   test('USD formats with \$ when locale is resolved', () {
//     final out = NumberFormat.currency(
//       locale: resolveLocale('en'),
//       name: 'USD',
//     ).format(1234.5);
//     expect(out, contains('\$'));
//     expect(out, contains('1,234'));
//   });
//
//   test('BCP 47 conversion preserves semantics', () {
//     expect(toBcp47('tr_TR'), 'tr-TR');
//     expect(toBcp47('en_US'), 'en-US');
//   });
// }

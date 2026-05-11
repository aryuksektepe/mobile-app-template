// Consent Mode v2 — flip flags after explicit user acceptance.
// Default-deny is set in Info.plist + AndroidManifest (see snippets in this dir).

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentChoice {
  const ConsentChoice({
    required this.analytics,
    required this.adStorage,
    required this.adUserData,
    required this.adPersonalization,
  });

  final bool analytics;
  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;

  static const denyAll = ConsentChoice(
    analytics: false,
    adStorage: false,
    adUserData: false,
    adPersonalization: false,
  );

  static const acceptAll = ConsentChoice(
    analytics: true,
    adStorage: true,
    adUserData: true,
    adPersonalization: true,
  );
}

class ConsentService {
  static const _kStored = 'consent.v2.choice';
  static const _kVersion = 'consent.v2.version';

  /// Bump when consent text materially changes — re-prompts users.
  static const currentConsentVersion = '2026-05-10';

  /// Apply a consent choice across all SDKs and persist locally.
  Future<void> apply(ConsentChoice c) async {
    await FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: c.analytics,
      adStorageConsentGranted: c.adStorage,
      adUserDataConsentGranted: c.adUserData,
      adPersonalizationSignalsConsentGranted: c.adPersonalization,
    );

    // Crash collection follows analytics consent (separate from ad/marketing).
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(c.analytics);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStored, _serialize(c));
    await prefs.setString(_kVersion, currentConsentVersion);
  }

  /// Returns null if user has never consented, OR consent text has been
  /// updated and re-acceptance is needed.
  Future<ConsentChoice?> readStored() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kVersion) != currentConsentVersion) return null;
    final raw = prefs.getString(_kStored);
    return raw == null ? null : _deserialize(raw);
  }

  String _serialize(ConsentChoice c) =>
      '${c.analytics ? 1 : 0}${c.adStorage ? 1 : 0}${c.adUserData ? 1 : 0}${c.adPersonalization ? 1 : 0}';

  ConsentChoice _deserialize(String s) => ConsentChoice(
        analytics: s[0] == '1',
        adStorage: s[1] == '1',
        adUserData: s[2] == '1',
        adPersonalization: s[3] == '1',
      );
}

// Bootstrap Remote Config — non-blocking fetch.
// Call from your bootstrap() AFTER Firebase.initializeApp().

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode, unawaited;

import 'remote_config.dart';

Future<void> initRemoteConfig() async {
  final rc = FirebaseRemoteConfig.instance;

  await rc.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      // Server enforces ~1 hour minimum in prod regardless of this value.
      minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
    ),
  );

  // CRITICAL: defaults for every key your app reads.
  // Without these, the first read returns the type's zero value (false/""/0),
  // even if the console has a value, until first fetch completes.
  await rc.setDefaults(AppConfig.defaults);

  // Fire and forget — UI uses defaults until first activation.
  // For paywall A/B variant where you NEED the value before first paint,
  // either await with a timeout OR show a brief splash.
  unawaited(rc.fetchAndActivate());
}

/// Variant logging — call this AFTER first paint when AppConfig settles.
/// Mirrors variant to Firebase Analytics so audience stickiness works.
Future<void> logCurrentVariant(String paywallVariant) async {
  // import 'package:firebase_analytics/firebase_analytics.dart';
  // await FirebaseAnalytics.instance.setUserProperty(
  //   name: 'paywall_variant',
  //   value: paywallVariant,
  // );
}

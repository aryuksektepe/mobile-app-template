// Combined Crashlytics + Sentry bootstrap.
// Call from your shared bootstrap() AFTER Firebase.initializeApp().
//
// Wires both error handlers; on each Flutter/Dart error, sends to BOTH services.
// Native iOS/Android crashes go through Crashlytics signal handlers (always reliable).

import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_scrubber.dart';

/// Initialize both crash services + run app.
///
/// Pre-condition: Firebase.initializeApp() already called.
Future<void> bootstrapWithCrashMonitoring(Widget app) async {
  // Wire BOTH services from the two canonical Flutter error sources.
  // Note: NO runZonedGuarded — that pattern is legacy as of Flutter 3.3+.

  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  // Default-OFF in debug (avoid noise / dev PII leakage).
  // Will be turned ON later by ConsentService when user accepts.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  final pkg = await PackageInfo.fromPlatform();
  final release = '${pkg.packageName}@${pkg.version}+${pkg.buildNumber}';

  await SentryFlutter.init(
    (o) {
      o.dsn = const String.fromEnvironment('SENTRY_DSN');
      o.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'dev');
      o.release = release;
      o.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      o.profilesSampleRate = kReleaseMode ? 0.1 : 0.0;
      o.attachScreenshot = true;
      o.attachViewHierarchy = true;
      o.sendDefaultPii = false;        // KVKK / GDPR
      o.beforeSend = sentryBeforeSend; // see sentry_scrubber.dart
      o.debug = kDebugMode;
    },
    appRunner: () => runApp(ProviderScope(child: app)),
  );
}

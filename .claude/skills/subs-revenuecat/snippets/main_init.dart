// RevenueCat initialization in main().
// Pass keys via --dart-define=RC_IOS_KEY=appl_xxx --dart-define=RC_ANDROID_KEY=goog_xxx
// NEVER hardcode keys.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureRevenueCat();

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _configureRevenueCat() async {
  await Purchases.setLogLevel(
    kReleaseMode ? LogLevel.warn : LogLevel.debug,
  );

  const iosKey = String.fromEnvironment('RC_IOS_KEY');
  const androidKey = String.fromEnvironment('RC_ANDROID_KEY');

  final apiKey = Platform.isIOS ? iosKey : androidKey;

  if (apiKey.isEmpty) {
    throw StateError(
      'RevenueCat API key missing. Pass via --dart-define=RC_IOS_KEY / RC_ANDROID_KEY.',
    );
  }

  // Anonymous-first: do NOT pass appUserID here even if you have one.
  // Call Purchases.logIn(authUid) AFTER your auth flow completes,
  // and RC will alias the anonymous ID → identified ID.
  // (See pitfall #5 — TRANSFER webhook does not fire on this aliasing,
  // so backend must fetch fresh CustomerInfo after logIn.)
  await Purchases.configure(PurchasesConfiguration(apiKey));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold());
  }
}

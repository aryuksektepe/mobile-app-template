// Shared Firebase + App Check bootstrap.
// Each flavor entrypoint (main_dev/stg/prod.dart) calls bootstrap() with its
// flavor-specific FirebaseOptions.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart' show MyApp;

Future<void> bootstrap(FirebaseOptions options) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against duplicate-app exception on hot restart (pitfall #1).
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }

  // App Check immediately after initializeApp.
  // - Debug providers: simulator/emulator + Xcode runs from CI.
  // - Production providers: Play Integrity (Android) + DeviceCheck (iOS).
  //   App Attest (iOS 14.5+ physical device) can be swapped in if you need
  //   stronger attestation; DeviceCheck is the safe default.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:   kDebugMode ? AppleProvider.debug   : AppleProvider.deviceCheck,
  );

  // In debug, copy the printed App Check token from device logs once and
  // register it at: Firebase Console → App Check → Apps → Manage debug tokens.

  runApp(const ProviderScope(child: MyApp()));
}

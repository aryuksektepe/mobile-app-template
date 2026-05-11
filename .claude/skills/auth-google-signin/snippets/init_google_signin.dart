// Initialize Google Sign In v7+. MUST be called BEFORE any other method.
// Call from your bootstrap() AFTER Firebase.initializeApp().
//
// CRITICAL: serverClientId is REQUIRED on Android (v7.1+) — pass the
// Firebase-auto-created WEB OAuth client ID, NOT the Android client ID.
// Find it in: Firebase Console → Authentication → Sign-in method →
//   click Google → "Web SDK configuration" → Web client ID.
//
// Pass via --dart-define=GOOGLE_WEB_CLIENT_ID=...

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

Future<void> initGoogleSignIn() async {
  await GoogleSignIn.instance.initialize(
    // iOS-only: REVERSED_CLIENT_ID prefix from GoogleService-Info.plist.
    // (FlutterFire CLI usually patches Info.plist for you; serverClientId
    // covers most cases too. Pass null if not sure.)
    clientId: kIsWeb || !Platform.isIOS
        ? null
        : const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),

    // Android: REQUIRED in v7.1+. Web OAuth client ID (type 3).
    serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
  );
}

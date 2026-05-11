// Apple Sign-In account deletion — REVOKE the Apple grant.
//
// Apple App Review actively tests this since Jun 2022 (guideline 5.1.1(v)).
// If you only call user.delete() without revoking, Apple rejects with:
//   "Your app supports Sign in with Apple, but it doesn't revoke the user's
//    Apple ID grant when they delete their account."
//
// Two-stage:
//   1. Force fresh sign-in to get a usable authorizationCode (the one from
//      original sign-in is short-lived).
//   2. Call FirebaseAuth.revokeTokenWithAuthorizationCode(...) which
//      uses Apple's /auth/revoke endpoint.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ⚠ COPY-PASTE NOTE: rewrite `../../<skill>/...` to `package:<your_app>/...`
// when lifting into your real `lib/`.
import '../../auth-firebase-email/snippets/auth_exceptions.dart';

String _genNonce([int n = 32]) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
  final r = Random.secure();
  return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
}

String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

/// Deletion flow specific to Apple Sign-In users.
/// Returns true if both revoke + delete succeeded.
Future<bool> deleteAppleAccount(FirebaseAuth firebase) async {
  final user = firebase.currentUser;
  if (user == null) return false;

  // Step 1: fresh sign-in to get a current authorizationCode.
  final rawNonce = _genNonce();
  final hashedNonce = _sha(rawNonce);

  AuthorizationCredentialAppleID apple;
  try {
    apple = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: hashedNonce,
    );
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) {
      throw const ReauthRequiredException(); // user backed out
    }
    rethrow;
  }

  // Step 2: re-authenticate (Firebase requires recent login).
  final cred = OAuthProvider('apple.com').credential(
    idToken: apple.identityToken,
    rawNonce: rawNonce,
  );

  try {
    await user.reauthenticateWithCredential(cred);
  } on FirebaseAuthException {
    throw const ReauthRequiredException();
  }

  // Step 3: REVOKE the Apple grant. App Review enforces this.
  if (apple.authorizationCode != null) {
    try {
      await firebase.revokeTokenWithAuthorizationCode(apple.authorizationCode!);
    } catch (e) {
      // If revoke fails, do NOT proceed with delete — fix root cause first.
      // Common: stale Cloud Function `storeAppleAuthCode`, or wrong client_id.
      rethrow;
    }
  }

  // Step 4: delete Firebase user. Cloud Function `onUserDelete` purges data.
  await user.delete();

  return true;
}

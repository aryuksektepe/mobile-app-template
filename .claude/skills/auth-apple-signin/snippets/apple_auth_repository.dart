// AppleAuthRepository — Sign in with Apple + Firebase Auth.
//
// CRITICAL nonce dance:
//   1. Generate raw random nonce (cryptographic).
//   2. SHA256(rawNonce) → send to Apple as `nonce` param.
//   3. Apple returns idToken signed over the SHA256 hash.
//   4. Pass RAW (un-hashed) nonce to Firebase as `rawNonce`.
//   5. Firebase recomputes SHA256, verifies match in idToken.
// Mismatch → `invalid OAuth response from apple.com` (pitfall #1).

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ⚠ COPY-PASTE NOTE: rewrite `../../<skill>/...` to `package:<your_app>/...`
// when lifting into your real `lib/`.
import '../../auth-firebase-email/snippets/auth_exceptions.dart';

class AppleAuthRepository {
  AppleAuthRepository(this._firebase);
  final FirebaseAuth _firebase;

  String _generateRawNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  /// Sign in with Apple → Firebase Auth.
  /// On FIRST sign-in only, persists name to Firestore + updates displayName.
  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = _sha256(rawNonce);

    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,    // SHA256-hashed nonce → Apple
        webAuthenticationOptions: WebAuthenticationOptions(
          // For Android/Web. On iOS native this block is ignored.
          clientId: const String.fromEnvironment('APPLE_SERVICE_ID'),
          redirectUri: Uri.parse(
            const String.fromEnvironment('APPLE_REDIRECT_URI'),
            // e.g., https://your-firebase-project.firebaseapp.com/__/auth/handler
          ),
        ),
      );

      final firebaseCredential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,    // RAW (un-hashed) → Firebase
      );

      final userCred = await _firebase.signInWithCredential(firebaseCredential);

      // CRITICAL: capture name on FIRST sign-in. Apple returns it only ONCE.
      await _captureNameIfFirstSignIn(userCred, apple);

      // CRITICAL: persist authorizationCode for later revocation.
      await _persistAuthorizationCode(apple);

      return userCred;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw _mapApple(e);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebase(e);
    }
  }

  Future<void> _captureNameIfFirstSignIn(
    UserCredential userCred,
    AuthorizationCredentialAppleID apple,
  ) async {
    final givenName = apple.givenName;
    final familyName = apple.familyName;
    if (givenName == null && familyName == null) return; // not first sign-in

    final displayName =
        [givenName, familyName].whereType<String>().join(' ').trim();
    if (displayName.isEmpty) return;

    final user = userCred.user;
    if (user == null) return;

    // Firestore + Firebase Auth display name in same flow. If either fails,
    // retry — losing this is permanent (test by removing app from Apps Using Apple ID).
    try {
      await user.updateDisplayName(displayName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': displayName,
        'givenName': givenName,
        'familyName': familyName,
      }, SetOptions(merge: true));
    } catch (_) {
      // Retry once. If it still fails, log to Sentry.
      try {
        await user.updateDisplayName(displayName);
      } catch (_) {}
    }
  }

  Future<void> _persistAuthorizationCode(
    AuthorizationCredentialAppleID apple,
  ) async {
    final code = apple.authorizationCode;
    if (code == null) return;

    try {
      // Backend exchanges code for refresh_token via Apple's token endpoint,
      // stores encrypted refresh_token in Firestore for later revocation.
      await FirebaseFunctions.instance
          .httpsCallable('storeAppleAuthCode')
          .call({'authorizationCode': code});
    } catch (_) {
      // Log but don't fail sign-in. Re-trigger fresh sign-in inside delete flow.
    }
  }

  AuthException _mapApple(SignInWithAppleAuthorizationException e) {
    return switch (e.code) {
      AuthorizationErrorCode.canceled => const _CanceledException(),
      AuthorizationErrorCode.failed => const UnknownAuthException('apple_failed'),
      AuthorizationErrorCode.invalidResponse =>
        const UnknownAuthException('apple_invalid_response'),
      AuthorizationErrorCode.notHandled =>
        const UnknownAuthException('apple_not_handled'),
      AuthorizationErrorCode.unknown => const UnknownAuthException('apple_unknown'),
    };
  }

  AuthException _mapFirebase(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-credential' => const InvalidCredentialsException(),
      'account-exists-with-different-credential' =>
        const AccountExistsWithDifferentCredentialException(),
      'user-disabled' => const AccountDisabledException(),
      'network-request-failed' => const NetworkException(),
      _ => UnknownAuthException(e.code),
    };
  }
}

class _CanceledException extends AuthException {
  const _CanceledException();
}

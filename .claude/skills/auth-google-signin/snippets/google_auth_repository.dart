// GoogleAuthRepository — v7+ API.
// Authentication (idToken) ≠ Authorization (accessToken for API calls).
//
// ⚠ COPY-PASTE NOTE: the `../../<skill>/snippets/...` import below is how
// skills cross-reference each other inside the template. When lifting this
// file into your real app's `lib/`, rewrite to `package:<your_app>/...`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../../auth-firebase-email/snippets/auth_exceptions.dart';

class GoogleAuthRepository {
  GoogleAuthRepository(this._google, this._firebase);
  final GoogleSignIn _google;
  final FirebaseAuth _firebase;

  /// Sign in with Google → exchange idToken for Firebase credential.
  /// Returns the Firebase UserCredential.
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Step 1: AUTHENTICATION — who are they?
      final account = await _google.authenticate(scopeHint: const ['email']);

      // v7: authentication property is SYNCHRONOUS (was async in v6).
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const UnknownAuthException('missing_id_token');
      }

      // Step 2: Exchange for Firebase credential.
      // accessToken is null when only auth (no API scopes requested).
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        // accessToken: only needed for Firebase OIDC linking with Google APIs;
        // pass if you also called authorizeScopes for Calendar/Contacts/Drive.
      );

      return await _firebase.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw _mapGoogleException(e);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  /// Optional: request Google API scopes (Calendar, Contacts, Drive, etc.)
  /// AFTER initial sign-in. Returns access token, or null if user denied.
  Future<String?> requestApiScopes(GoogleSignInAccount account, List<String> scopes) async {
    final auth = await account.authorizationClient.authorizeScopes(scopes);
    return auth.accessToken;
  }

  /// Lightweight silent sign-in. Use on app start to restore session.
  /// Returns null if user previously signed out / never signed in.
  Future<UserCredential?> tryLightweightSignIn() async {
    try {
      final account = await _google.attemptLightweightAuthentication();
      if (account == null) return null;
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      return _firebase.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException {
      return null;
    }
  }

  /// Sign out (clears local sign-in but Credential Manager remembers user
  /// — next signIn shows them auto-selected).
  Future<void> signOut() async {
    await _firebase.signOut();
    await _google.signOut();
  }

  /// REVOKE the OAuth grant (for "Hesabımı sil" flow).
  /// Next signIn requires explicit user authorization.
  Future<void> disconnect() async {
    try {
      await _google.disconnect();
    } catch (_) {
      // Best-effort.
    }
    await _firebase.signOut();
  }

  AuthException _mapGoogleException(GoogleSignInException e) {
    return switch (e.code.name) {
      'canceled' => const _CanceledException(),
      'interrupted' || 'unknownError' => const NetworkException(),
      'clientConfigurationError' || 'providerConfigurationError' =>
        const UnknownAuthException('config_error'),
      'uiUnavailable' => const UnknownAuthException('ui_unavailable'),
      'userMismatch' => const UnknownAuthException('user_mismatch'),
      _ => UnknownAuthException(e.code.name),
    };
  }

  AuthException _mapFirebaseException(FirebaseAuthException e) {
    return switch (e.code) {
      'account-exists-with-different-credential' =>
        const AccountExistsWithDifferentCredentialException(),
      'invalid-credential' => const InvalidCredentialsException(),
      'user-disabled' => const AccountDisabledException(),
      'network-request-failed' => const NetworkException(),
      _ => UnknownAuthException(e.code),
    };
  }
}

class _CanceledException extends AuthException {
  const _CanceledException();
}

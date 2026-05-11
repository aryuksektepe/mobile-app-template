// AuthRepository — single source of truth for all Firebase Auth email flows.
// Maps FirebaseAuthException codes to typed AuthException.

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_exceptions.dart';

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  /// Current signed-in user (synchronous snapshot).
  User? get currentUser => _auth.currentUser;

  /// Stream for routing (login/logout transitions).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Stream for profile updates (displayName, photoURL, emailVerified flips).
  Stream<User?> userChanges() => _auth.userChanges();

  // ── Sign up ────────────────────────────────────────────────────────────

  Future<UserCredential> signUp({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Send verification email immediately
      await cred.user?.sendEmailVerification(_actionCodeSettings());
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Sign in ────────────────────────────────────────────────────────────

  Future<UserCredential> signIn({required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────

  /// Caller should also clear secure storage, FCM token, analytics user.
  Future<void> signOut() => _auth.signOut();

  // ── Email verification ─────────────────────────────────────────────────

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification(_actionCodeSettings());
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  /// Force-refresh emailVerified after user clicks verification link.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ── Password reset (no current user required) ──────────────────────────

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: _actionCodeSettings(),
      );
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Password change (current user, requires recent login) ──────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser!;
    try {
      await _reauthEmail(user, currentPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Email change (v6: verifyBeforeUpdateEmail replaces updateEmail) ────

  /// Sends verification to NEW email. Email field stays old until link clicked
  /// AND `reloadAndCheckVerified()` called.
  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser!;
    try {
      await _reauthEmail(user, currentPassword);
      await user.verifyBeforeUpdateEmail(newEmail.trim(), _actionCodeSettings());
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Account deletion (KVKK + Apple/Google policy) ──────────────────────

  /// Deletes Firebase Auth user. Cloud Function `onUserDelete` should fire
  /// to purge Firestore + Storage data within 30 days.
  Future<void> deleteAccount({required String currentPassword}) async {
    final user = _auth.currentUser!;
    try {
      await _reauthEmail(user, currentPassword);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Account linking (anonymous → email upgrade) ────────────────────────

  Future<UserCredential> linkAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const UnknownAuthException('not-anonymous');
    }
    try {
      final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
      return await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<UserCredential> _reauthEmail(User user, String password) {
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    return user.reauthenticateWithCredential(cred);
  }

  ActionCodeSettings _actionCodeSettings() => ActionCodeSettings(
        // Replace with your Hosting custom domain
        url: 'https://yourdomain.com/auth/callback',
        handleCodeInApp: true,
        androidPackageName: 'com.acme.myapp',
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: 'com.acme.myapp',
      );

  AuthException _map(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => const InvalidEmailException(),
        // Email enumeration protection merges these into invalid-credential:
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          const InvalidCredentialsException(),
        'too-many-requests' => const RateLimitedException(),
        'user-disabled' => const AccountDisabledException(),
        'network-request-failed' => const NetworkException(),
        'email-already-in-use' => const EmailTakenException(),
        'weak-password' => const WeakPasswordException(),
        'requires-recent-login' => const ReauthRequiredException(),
        'invalid-action-code' || 'expired-action-code' =>
          const InvalidActionCodeException(),
        'account-exists-with-different-credential' =>
          const AccountExistsWithDifferentCredentialException(),
        _ => UnknownAuthException(e.code),
      };
}

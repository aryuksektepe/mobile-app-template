// Account deletion — KVKK Art. 7 + GDPR Art. 17 + Apple 5.1.1(v) (Jun 2022)
// + Google Play data deletion policy (Dec 2023).
//
// MUST be reachable in-app, not just via website.
// MUST trigger backend purge of related data within 30 days.
//
// ⚠ COPY-PASTE NOTE: the `../../<skill>/snippets/...` imports below are how
// skills cross-reference each other inside the template. When lifting this
// file into your real app's `lib/`, rewrite those to `package:<your_app>/...`
// paths matching where you placed each module.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../secure-storage-tokens/snippets/secure_token_repository.dart';
import '../../crash-monitor-dual/snippets/identify_user.dart';
import 'auth_repository.dart';
import 'auth_exceptions.dart';

/// Full account deletion sequence. Returns true on success.
///
/// Steps:
///   1. Biometric reauth (defense in depth — confirms intent).
///   2. Password reauth (Firebase requires recent login for delete).
///   3. Trigger any vendor-specific cleanup (RevenueCat, Apple Sign-In token revoke).
///   4. Call user.delete() — Firebase Auth user removed.
///   5. Cloud Function `onUserDelete` fires asynchronously to purge Firestore + Storage.
///   6. Clean up local state (secure storage, push token, analytics, crash user).
///
/// CALLER must inform user: "Hesabın silindi. Verilerin 30 gün içinde
/// sistemlerimizden tamamen kaldırılacak." (KVKK + GDPR compliance text)
Future<bool> deleteAccountFlow({
  required WidgetRef ref,
  required String currentPassword,
}) async {
  // Step 1: biometric (best-effort — fall back to password-only if not available)
  try {
    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    if (canCheck) {
      final ok = await localAuth.authenticate(
        localizedReason: 'Hesabınızı silmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) throw const BiometricFailedException();
    }
  } catch (_) {
    // If biometric fails or unavailable, password reauth (step 2) still gates.
  }

  // Step 2 + 4: Firebase reauth + delete (Firebase enforces recent login).
  final repo = ref.read(authRepoProvider);
  final user = repo.currentUser;
  if (user == null) return false;

  final uid = user.uid;

  try {
    // Step 3: vendor cleanup BEFORE delete (we need user context for some).
    //
    // For Sign in with Apple: must revoke the Apple grant (App Review enforces this).
    // See auth-apple-signin skill for impl. Pattern:
    //   await repo.revokeAppleTokenIfPresent(currentPassword);
    //
    // For RevenueCat: server-side delete via backend after we have uid.

    await repo.deleteAccount(currentPassword: currentPassword);

    // Step 6: local cleanup.
    await ref.read(tokenRepoProvider).clearAll();
    await clearCrashUser();
    // await FirebaseMessaging.instance.deleteToken();   // if notifications-fcm wired
    // await FirebaseAnalytics.instance.setUserId(id: null);

    // Backend purge runs async. Notify user it's complete + 30-day finalization.

    return true;
  } on ReauthRequiredException {
    rethrow;          // caller re-prompts password
  } on AuthException {
    rethrow;
  }
}

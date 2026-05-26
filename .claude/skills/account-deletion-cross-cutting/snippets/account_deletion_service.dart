// AccountDeletionService — orchestrates the 9-step canonical deletion flow.
// Each step is idempotent and individually retryable.
//
// Throws AccountDeletionError on any irrecoverable failure with `step` set to
// the failing step number so the UI can prompt "retry from step N".
//
// Caller (typically Settings → Delete Account screen):
//
//   try {
//     await ref.read(accountDeletionServiceProvider).deleteAccount(
//       reauthCredential: await _promptReauth(),
//     );
//     // success — router redirects to /welcome via auth state listener
//   } on AccountDeletionError catch (e) {
//     showRetryDialog(e.step, e.cause);
//   }

import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AccountDeletionError implements Exception {
  AccountDeletionError(this.step, this.cause);
  final int step;
  final Object cause;
  @override
  String toString() => 'AccountDeletionError(step=$step): $cause';
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(
    secureStorage: const FlutterSecureStorage(),
    apiClient: ref.read(apiClientProvider),
  ),
);

class AccountDeletionService {
  AccountDeletionService({
    required FlutterSecureStorage secureStorage,
    required Dio apiClient,
  })  : _secureStorage = secureStorage,
        _api = apiClient;

  final FlutterSecureStorage _secureStorage;
  final Dio _api;

  /// Runs the canonical 9-step deletion. Call reauthenticateWithCredential
  /// BEFORE calling this (or pass reauthCredential to do it here).
  Future<void> deleteAccount({AuthCredential? reauthCredential}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw AccountDeletionError(0, 'No signed-in user');
    final uid = user.uid;

    // Step 3 — reauthenticate (already-recent OK)
    try {
      if (reauthCredential != null) {
        await user.reauthenticateWithCredential(reauthCredential);
      }
    } catch (e) {
      throw AccountDeletionError(3, e);
    }

    // Step 4 — mark soft-deleted server-side
    try {
      await _api.post('/account/soft-delete', data: {'userId': uid});
    } catch (e) {
      throw AccountDeletionError(4, e);
    }

    // Step 5 — revoke Apple token (server-side, only if SIWA was the provider)
    final usedApple = user.providerData.any((p) => p.providerId == 'apple.com');
    if (usedApple) {
      try {
        await _api.post('/account/revoke-apple-token', data: {'userId': uid});
      } catch (e) {
        // Log + continue — server can retry the revocation, missing it is a delay not a leak
        FirebaseCrashlytics.instance.recordError(e, null,
            reason: 'Apple token revoke failed step 5 — server will retry');
      }
    }

    // Step 6 — RevenueCat user delete (server-side; SDK secret key)
    try {
      await _api.post('/account/delete-rc-user', data: {'userId': uid});
    } catch (e) {
      // Same as Apple revoke — log + continue (server retries)
      FirebaseCrashlytics.instance.recordError(e, null,
          reason: 'RC user delete failed step 6 — server will retry');
    }

    // Step 7 — FCM token cleanup
    try {
      await FirebaseMessaging.instance.deleteToken();
      // server-side row deletion was queued by step 4; nothing else here
    } catch (e) {
      // Non-fatal — token will expire on its own
    }
    await Purchases.logOut().catchError((_) {}); // SDK-side; non-fatal

    // Step 8 — analytics + crash + sentry user clear
    try {
      await FirebaseAnalytics.instance.setUserId(id: null);
      await FirebaseAnalytics.instance.resetAnalyticsData();
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await Sentry.configureScope((s) => s.setUser(null));
    } catch (e) {
      // Non-fatal
    }

    // Step 9 — wipe local + FirebaseAuth.delete()
    try {
      await _secureStorage.deleteAll();
      // Drift wipe — your app's DB instance:
      // await ref.read(appDbProvider).close();
      // await deleteDatabaseFile();
      await user.delete(); // Firebase Auth account deletion
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionError(3, 'Reauth expired — re-run flow');
      }
      throw AccountDeletionError(9, e);
    } catch (e) {
      throw AccountDeletionError(9, e);
    }

    // auth state listener will pick up sign-out and redirect to /welcome
  }
}

// Placeholder — wire to your actual Dio provider
final apiClientProvider = Provider<Dio>((ref) => Dio());

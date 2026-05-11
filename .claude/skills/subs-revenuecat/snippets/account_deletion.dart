// KVKK / GDPR-compliant account deletion for RevenueCat.
//
// Apple (since Jun 2022) and Google Play (since Dec 2023) require apps with
// account creation to provide in-app account deletion. RC stores its own
// user record separately — `Purchases.logOut()` only clears the LOCAL state.
//
// Three-step deletion:
//   1. (Optional but recommended) Tell user they must cancel store-side
//      subscription themselves — RC cannot cancel store subs. Show
//      managementURL.
//   2. Server-side: DELETE /v1/subscribers/{app_user_id} with SECRET API key.
//      MUST run from your backend — secret key NEVER ships in app.
//   3. Client-side: Purchases.logOut() to clear local cache.

import 'package:purchases_flutter/purchases_flutter.dart';

class AccountDeletionService {
  AccountDeletionService(this._backend);

  /// Your backend client. Must expose a method that calls
  /// DELETE /v1/subscribers/{appUserId} on RevenueCat REST API
  /// using the SECRET API key (sk_xxx) — never the public SDK key.
  final BackendApi _backend;

  /// Delete the user account. Call AFTER user has confirmed.
  ///
  /// Order matters:
  ///  1. Get RC app user id (still logged in).
  ///  2. Ask backend to delete RC subscriber + your own user record.
  ///  3. Then logOut from RC to reset to anonymous.
  ///  4. Then sign out from your auth provider.
  Future<DeletionResult> deleteAccount() async {
    try {
      final appUserId = await Purchases.appUserID;

      // Step 1: backend deletes RC subscriber + your own user record.
      // Backend should call:
      //   DELETE https://api.revenuecat.com/v1/subscribers/$appUserId
      //   Authorization: Bearer $RC_SECRET_API_KEY
      await _backend.deleteUserAndRevenueCatSubscriber(appUserId);

      // Step 2: clear local RC state — back to anonymous user.
      try {
        await Purchases.logOut();
      } catch (_) {
        // logOut throws if already anonymous. Safe to ignore.
      }

      return DeletionResult.success;
    } catch (e) {
      return DeletionResult.failure(e.toString());
    }
  }

  /// Get the URL that lets the user manage (cancel) their store subscription.
  /// Show this BEFORE deletion if user has active sub — RC cannot cancel
  /// the store-side billing relationship.
  Future<String?> getStoreSubscriptionManagementUrl() async {
    final info = await Purchases.getCustomerInfo();
    return info.managementURL;
  }
}

/// Stub — implement with your HTTP client (dio, http, etc.)
abstract interface class BackendApi {
  Future<void> deleteUserAndRevenueCatSubscriber(String appUserId);
}

sealed class DeletionResult {
  const DeletionResult();
  static const DeletionResult success = _Success();
  // ignore: prefer_const_constructors
  static DeletionResult failure(String reason) => _Failure(reason);
}

class _Success extends DeletionResult {
  const _Success();
}

class _Failure extends DeletionResult {
  const _Failure(this.reason);
  final String reason;
}

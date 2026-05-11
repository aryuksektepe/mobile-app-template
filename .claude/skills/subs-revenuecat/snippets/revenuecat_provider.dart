// Riverpod entitlement provider for RevenueCat.
// Listens to addCustomerInfoUpdateListener so widgets re-render
// automatically on purchase, renewal, expiration, restore, transfer.
//
// Usage in widgets:
//   final isPro = ref.watch(hasProProvider);
//   if (!isPro) return PaywallScreen();
//
// Replace 'pro' with your entitlement identifier from RC dashboard.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const String kProEntitlement = 'pro';

final customerInfoProvider = StreamProvider<CustomerInfo>((ref) {
  final controller = StreamController<CustomerInfo>();

  // Seed with current value so first frame doesn't flash 'no entitlement'.
  Purchases.getCustomerInfo()
      .then(controller.add)
      .catchError((Object e) => controller.addError(e));

  void listener(CustomerInfo info) => controller.add(info);
  Purchases.addCustomerInfoUpdateListener(listener);

  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(listener);
    controller.close();
  });

  return controller.stream;
});

final hasProProvider = Provider<bool>((ref) {
  return ref.watch(customerInfoProvider).maybeWhen(
        data: (info) => info.entitlements.active.containsKey(kProEntitlement),
        orElse: () => false,
      );
});

/// True when entitlement is active AND in the grace period (billing issue
/// but still active for now). Use this to nudge the user to update payment.
final inBillingGraceProvider = Provider<bool>((ref) {
  return ref.watch(customerInfoProvider).maybeWhen(
        data: (info) {
          final ent = info.entitlements.active[kProEntitlement];
          return ent?.billingIssueDetectedAt != null;
        },
        orElse: () => false,
      );
});

/// Most recent expiration timestamp for the pro entitlement (active or not).
/// Useful for showing "Your subscription expires on ..." UI.
final proExpiresAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(customerInfoProvider).maybeWhen(
        data: (info) {
          final ent = info.entitlements.all[kProEntitlement];
          final iso = ent?.expirationDate;
          return iso == null ? null : DateTime.parse(iso);
        },
        orElse: () => null,
      );
});

/// Identify the user with RevenueCat after your auth flow completes.
/// CRITICAL: after this, fetch fresh CustomerInfo from your backend —
/// the TRANSFER webhook does NOT fire on anonymous→identified aliasing
/// (RC community confirmed). Backend must pull, not wait for push.
Future<void> identifyUser(String authUid) async {
  await Purchases.logIn(authUid);
  // Force refresh to bypass cache.
  await Purchases.invalidateCustomerInfoCache();
  await Purchases.getCustomerInfo();
}

/// Sign out from RevenueCat. Call BEFORE you sign out from your auth provider.
/// Returns user to anonymous mode.
Future<void> signOutFromRevenueCat() async {
  // Will throw if user is already anonymous — safe to ignore.
  try {
    await Purchases.logOut();
  } catch (_) {}
}

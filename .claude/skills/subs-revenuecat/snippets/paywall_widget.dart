// Paywall integration with RevenueCat Paywalls v2 (purchases_ui_flutter).
// Requires iOS 15.0+ deployment target.
//
// Two patterns provided:
//  1. presentPaywall — modal sheet, returns result enum
//  2. PaywallView — embed inline as a widget
//
// Defensive: result enum has been buggy on iOS sandbox (pitfall #11).
// Always cross-check entitlements after dismissal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'revenuecat_provider.dart';

/// Show RC paywall as a modal. Returns true if user is now entitled.
Future<bool> showPaywall(BuildContext context, WidgetRef ref) async {
  final offerings = await Purchases.getOfferings();
  final current = offerings.current;

  if (current == null) {
    // No offering configured for this user. Either dashboard misconfig
    // or App Store agreement issue.
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paywall not available right now. Try again later.')),
    );
    return false;
  }

  final result = await RevenueCatUI.presentPaywall(
    offering: current,
    displayCloseButton: true,
  );

  // DO NOT trust the result enum alone (pitfall #11).
  // Always cross-check the entitlement freshly.
  await Purchases.invalidateCustomerInfoCache();
  final info = await Purchases.getCustomerInfo();
  final isPro = info.entitlements.active.containsKey(kProEntitlement);

  // Sanity: log any mismatch between enum and actual state.
  if (isPro && result == PaywallResult.cancelled) {
    debugPrint('[RC] Paywall returned cancelled but entitlement IS active — known iOS sandbox bug.');
  }

  return isPro;
}

/// Show paywall ONLY if user is not already entitled.
Future<bool> showPaywallIfNeeded(BuildContext context, WidgetRef ref) async {
  final offerings = await Purchases.getOfferings();
  final current = offerings.current;
  if (current == null) return false;

  final result = await RevenueCatUI.presentPaywallIfNeeded(
    'pro',
    offering: current,
    displayCloseButton: true,
  );
  return result == PaywallResult.purchased || result == PaywallResult.restored;
}

/// Inline paywall widget — embed in a Scaffold body for full-screen paywall pages.
class InlinePaywall extends ConsumerWidget {
  const InlinePaywall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(_offeringsProvider);
    return offeringsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load paywall: $e')),
      data: (current) {
        if (current == null) {
          return const Center(child: Text('No paywall available.'));
        }
        return PaywallView(
          offering: current,
          onPurchaseCompleted: (info, _) {
            // Force refresh — see pitfall #9 (cache staleness).
            Purchases.invalidateCustomerInfoCache();
          },
          onRestoreCompleted: (info) {
            // iOS doesn't auto-dismiss after restore (pitfall #12).
            // Pop manually if this paywall is on its own route.
            Navigator.of(context).maybePop();
          },
          onDismiss: () => Navigator.of(context).maybePop(),
        );
      },
    );
  }
}

final _offeringsProvider = FutureProvider<Offering?>((ref) async {
  final offerings = await Purchases.getOfferings();
  return offerings.current;
});

// Purchase + restore handlers for RevenueCat.
// Handles every PurchasesErrorCode the user can realistically hit.
//
// Usage:
//   final result = await purchasePackage(package, ref);
//   result.when(
//     success: () => Navigator.pop(context),
//     cancelled: () => null, // user closed sheet, no UI needed
//     pending: () => showSnackBar('Purchase pending — we'll notify you'),
//     failure: (msg) => showSnackBar(msg),
//   );

import 'dart:async';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

sealed class PurchaseOutcome {
  const PurchaseOutcome();

  T when<T>({
    required T Function() success,
    required T Function() cancelled,
    required T Function() pending,
    required T Function(String message) failure,
  }) {
    return switch (this) {
      _Success() => success(),
      _Cancelled() => cancelled(),
      _Pending() => pending(),
      _Failure(:final message) => failure(message),
    };
  }
}

class _Success extends PurchaseOutcome {
  const _Success();
}

class _Cancelled extends PurchaseOutcome {
  const _Cancelled();
}

class _Pending extends PurchaseOutcome {
  const _Pending();
}

class _Failure extends PurchaseOutcome {
  const _Failure(this.message);
  final String message;
}

const String kProEntitlement = 'pro';

/// Purchase a package. Branches on every realistic error code.
Future<PurchaseOutcome> purchasePackage(Package package, Ref ref) async {
  try {
    final result = await Purchases.purchasePackage(package);
    final granted = result.customerInfo.entitlements.active.containsKey(kProEntitlement);
    return granted ? const _Success() : const _Failure('Purchase succeeded but entitlement not granted. Contact support.');
  } on PlatformException catch (e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    return _mapErrorCode(code, e.message ?? 'Unknown error');
  } catch (e) {
    return _Failure('Unexpected error: $e');
  }
}

PurchaseOutcome _mapErrorCode(PurchasesErrorCode code, String fallbackMsg) {
  switch (code) {
    case PurchasesErrorCode.purchaseCancelledError:
      // User tapped cancel / closed sheet. No UI needed — silent.
      return const _Cancelled();

    case PurchasesErrorCode.paymentPendingError:
      // Android: parental approval, slow card auth, wallet pending.
      // Listen on customerInfoUpdates for resolution.
      return const _Pending();

    case PurchasesErrorCode.networkError:
    case PurchasesErrorCode.storeProblemError:
    case PurchasesErrorCode.unknownBackendError:
      return const _Failure('Connection problem. Please try again.');

    case PurchasesErrorCode.productNotAvailableForPurchaseError:
      // Common right after creating the product — propagation lag.
      return const _Failure('This product is temporarily unavailable. Try again in a few minutes.');

    case PurchasesErrorCode.productAlreadyPurchasedError:
      // User already owns it but entitlement check failed → likely Apple ID mismatch
      // or sandbox quirk. Suggest restore.
      return const _Failure('You already own this. Tap "Restore Purchases".');

    case PurchasesErrorCode.receiptAlreadyInUseError:
      // Receipt belongs to another RC user. Common when switching test accounts.
      return const _Failure('This purchase is linked to another account. Sign out and back in to continue.');

    case PurchasesErrorCode.invalidReceiptError:
    case PurchasesErrorCode.missingReceiptFileError:
      return const _Failure('Receipt validation failed. Please reinstall the app.');

    case PurchasesErrorCode.purchaseInvalidError:
    case PurchasesErrorCode.purchaseNotAllowedError:
      // Underage, parental controls, restricted device.
      return const _Failure('Purchases are not allowed on this device. Check device restrictions.');

    case PurchasesErrorCode.invalidCredentialsError:
    case PurchasesErrorCode.configurationError:
      // Dev-side bug. Should not reach end users in prod.
      return _Failure('Configuration error: $fallbackMsg');

    case PurchasesErrorCode.ineligibleError:
      // User is not eligible for the offered intro/trial.
      return const _Failure('You are not eligible for this introductory offer.');

    case PurchasesErrorCode.insufficientPermissionsError:
      // Android: app missing BILLING permission (should not happen with our plugin).
      return const _Failure('Permission missing. Please update the app.');

    case PurchasesErrorCode.unsupportedError:
      return const _Failure('This purchase is not supported on your device.');

    default:
      return _Failure(fallbackMsg);
  }
}

/// Restore purchases. Call from a visible "Restore Purchases" button —
/// Apple App Review requires this on every paywall.
Future<PurchaseOutcome> restorePurchases() async {
  try {
    final info = await Purchases.restorePurchases();
    final restored = info.entitlements.active.containsKey(kProEntitlement);
    return restored
        ? const _Success()
        : const _Failure('No active purchases to restore. Make sure you are signed in with the same account.');
  } on PlatformException catch (e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    return _mapErrorCode(code, e.message ?? 'Restore failed');
  } catch (e) {
    return _Failure('Unexpected error: $e');
  }
}

/// Returns the URL the user should be sent to in order to manage their
/// subscription (cancel, change plan). RC returns the right URL per platform.
/// Returns null if the user has no active subscription.
Future<String?> getManagementUrl() async {
  final info = await Purchases.getCustomerInfo();
  return info.managementURL;
}

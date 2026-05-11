// Type-safe wrapper around FirebaseAnalytics. Forces snake_case event names,
// caps param value lengths, and never logs PII. Add a method per business
// event you track instead of scattering logEvent calls.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService(this._a);
  final FirebaseAnalytics _a;

  // ── Standard events (use built-in helpers when applicable) ──────────────

  Future<void> logSignUp({required String method}) =>
      _a.logSignUp(signUpMethod: method); // method ∈ {'email', 'google', 'apple'}

  Future<void> logLogin({required String method}) =>
      _a.logLogin(loginMethod: method);

  Future<void> logSearch({required String term}) =>
      _a.logSearch(searchTerm: _truncate(term, 100));

  Future<void> logPurchase({
    required String currency,
    required double value,
    String? transactionId,
    List<AnalyticsEventItem>? items,
  }) =>
      _a.logPurchase(
        currency: currency,
        value: value,
        transactionId: transactionId,
        items: items,
      );

  // ── Custom events — define one method per event ─────────────────────────

  Future<void> logOnboardingStepViewed({required int step, required String variant}) =>
      _a.logEvent(
        name: 'onboarding_step_viewed',
        parameters: {'step': step, 'variant': variant},
      );

  Future<void> logOnboardingCompleted({required int totalSteps, required int durationSec}) =>
      _a.logEvent(
        name: 'onboarding_completed',
        parameters: {'total_steps': totalSteps, 'duration_sec': durationSec},
      );

  Future<void> logPaywallShown({required String trigger, required String variant}) =>
      _a.logEvent(
        name: 'paywall_shown',
        parameters: {'trigger': trigger, 'variant': variant},
      );

  Future<void> logPromoRedeemAttempt({required String codeHash}) =>
      _a.logEvent(
        name: 'promo_redeem_attempt',
        parameters: {'code_hash': codeHash}, // hashed, NOT raw code
      );

  // ── User properties (≤25 total per project) ─────────────────────────────

  /// Set opaque hashed user ID — NEVER raw email/UID.
  Future<void> setUserId(String? rawId) async {
    if (rawId == null) {
      await _a.setUserId(id: null);
      return;
    }
    final hashed = sha256.convert(utf8.encode(rawId)).toString().substring(0, 32);
    await _a.setUserId(id: hashed);
  }

  Future<void> setSubscriptionTier(String tier) =>
      _a.setUserProperty(name: 'subscription_tier', value: tier);

  Future<void> setExperimentVariant(String experimentId, String variant) =>
      _a.setUserProperty(name: 'exp_$experimentId', value: variant);

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Truncate to 100 chars (GA4 string param limit).
  String _truncate(String s, int max) => s.length <= max ? s : s.substring(0, max);

  /// Hash an identifier suitable for use as event param (6 chars, low collision).
  static String hashShort(String input) {
    final h = sha256.convert(utf8.encode(input)).toString();
    return h.substring(0, 6).toUpperCase();
  }
}

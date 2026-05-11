// Riverpod PromoController + Flutter input UI.

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromoResult {
  const PromoResult({required this.type, required this.value});
  final String type;
  final num value;
}

// Crockford Base32 — no I/L/O/U
final _validCode = RegExp(r'^[0-9A-HJKMNP-TV-Z]{4,16}$');

String _hash(String input) =>
    sha256.convert(utf8.encode(input)).toString().substring(0, 8).toUpperCase();

class PromoController extends AsyncNotifier<PromoResult?> {
  @override
  Future<PromoResult?> build() async => null;

  Future<void> redeem(String input) async {
    state = const AsyncLoading();
    final code = input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

    if (!_validCode.hasMatch(code)) {
      state = AsyncError('invalid_format', StackTrace.current);
      return;
    }

    // CRITICAL: log only the HASH, never the raw code (pitfall: codes leaking)
    await FirebaseAnalytics.instance.logEvent(
      name: 'promo_redeem_attempt',
      parameters: {'code_hash': _hash(code)},
    );

    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('redeemPromoCode')
          .call({'code': code});

      final data = Map<String, dynamic>.from(res.data as Map);
      final result = PromoResult(
        type: data['type'] as String,
        value: data['value'] as num,
      );

      // Refresh entitlement / customer info — depends on your stack:
      // ref.invalidate(entitlementsProvider);
      // await Purchases.invalidateCustomerInfoCache();   // if using RC

      state = AsyncData(result);

      await FirebaseAnalytics.instance.logEvent(
        name: 'promo_redeem_success',
        parameters: {'type': result.type, 'code_hash': _hash(code)},
      );
    } on FirebaseFunctionsException catch (e) {
      // Map error codes to user-friendly messages.
      // Localize via your l10n.
      final reason = e.message ?? e.code;
      await FirebaseAnalytics.instance.logEvent(
        name: 'promo_redeem_failure',
        parameters: {'reason': reason, 'code_hash': _hash(code)},
      );
      state = AsyncError(reason, StackTrace.current);
    }
  }
}

final promoControllerProvider =
    AsyncNotifierProvider<PromoController, PromoResult?>(PromoController.new);

/// Code input UI — auto-uppercase, allowlist Crockford alphabet, max 16.
class PromoInput extends StatelessWidget {
  const PromoInput({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Promosyon kodu',
        hintText: 'ABC23DEF',
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 16,
      style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
      inputFormatters: [
        // Allow digits + letters; strip ambiguous I/L/O/U via regex
        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]')),
        // Force uppercase
        TextInputFormatter.withFunction((old, n) =>
            n.copyWith(text: n.text.toUpperCase())),
      ],
      onChanged: onChanged,
    );
  }
}

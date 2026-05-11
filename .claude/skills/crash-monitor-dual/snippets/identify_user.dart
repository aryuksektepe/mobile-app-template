// Identify the user for Crashlytics + Sentry using an OPAQUE HASHED ID.
// NEVER pass raw email, UID, phone, or any PII.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

String _hash(String raw) =>
    sha256.convert(utf8.encode(raw)).toString().substring(0, 32);

/// Set opaque hashed user ID across both crash services.
/// Call after auth login, AFTER consent has been granted.
Future<void> identifyCrashUser(String rawUserId) async {
  final hashed = _hash(rawUserId);
  await FirebaseCrashlytics.instance.setUserIdentifier(hashed);
  Sentry.configureScope((s) => s.setUser(SentryUser(id: hashed)));
}

/// Clear user from crash services. Call on logout.
Future<void> clearCrashUser() async {
  await FirebaseCrashlytics.instance.setUserIdentifier('');
  Sentry.configureScope((s) => s.setUser(null));
}

/// Set a custom key on both services. Useful for "feature_flag_x", "ab_variant".
Future<void> setCrashCustomKey(String key, Object value) async {
  await FirebaseCrashlytics.instance.setCustomKey(key, '$value');
  Sentry.configureScope((s) => s.setTag(key, '$value'));
}

/// Add a breadcrumb (Sentry-only — Crashlytics has no equivalent).
void addCrashBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {
  Sentry.addBreadcrumb(
    Breadcrumb(message: message, category: category, data: data),
  );
}

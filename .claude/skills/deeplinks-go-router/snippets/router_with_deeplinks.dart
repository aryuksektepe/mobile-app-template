// go_router with auth gate, deep-link sanitization, and return-to path.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'deeplink_bootstrap.dart';

/// Whitelisted hosts — anything else is rejected.
const _allowedHosts = {'yourdomain.com', 'app.yourdomain.com'};

/// Whitelisted route patterns. Add yours.
final _allowedPathPatterns = [
  RegExp(r'^/promo/[A-Z0-9]{6,16}$'),         // promo code
  RegExp(r'^/share/[a-f0-9-]{36}$'),          // UUID
  RegExp(r'^/post/\d+$'),                      // numeric ID
  RegExp(r'^/user/[a-zA-Z0-9_]{3,32}$'),      // username
];

/// Sanitize an incoming deep link. Returns null if it should be rejected.
String? sanitizeDeepLink(Uri uri) {
  // Only HTTPS or our app schemes — reject javascript:/data:/file: etc.
  if (uri.hasScheme && uri.scheme != 'https') return null;

  // Whitelist hosts (when scheme is present).
  if (uri.host.isNotEmpty && !_allowedHosts.contains(uri.host)) return null;

  // Whitelist paths.
  final path = uri.path;
  if (!_allowedPathPatterns.any((r) => r.hasMatch(path))) return null;

  return path + (uri.hasQuery ? '?${uri.query}' : '');
}

/// Routes that require auth (everything except login + onboarding + root).
bool _requiresAuth(String path) =>
    !path.startsWith('/login') &&
    !path.startsWith('/onboarding') &&
    !path.startsWith('/splash') &&
    path != '/';

/// Compose your GoRouter with this redirect:
///
///   GoRouter(redirect: (ctx, state) => deeplinkAuthRedirect(ctx, state, ref), ...);
String? deeplinkAuthRedirect(
  BuildContext ctx,
  GoRouterState state,
  WidgetRef ref, {
  required bool isLoggedIn,
}) {
  final loc = state.matchedLocation;
  final pending = ref.read(pendingDeepLinkProvider);

  // Avoid infinite redirect on the login page itself.
  if (loc.startsWith('/login')) {
    if (isLoggedIn) {
      final ret = state.uri.queryParameters['return'];
      return ret != null ? Uri.decodeComponent(ret) : '/home';
    }
    return null;
  }

  // 1. Honor pending deep link (cold-start or warm-start).
  if (pending != null) {
    final safe = sanitizeDeepLink(pending);
    ref.read(pendingDeepLinkProvider.notifier).state = null;

    if (safe == null) return '/';     // rejected — go home
    if (!isLoggedIn && _requiresAuth(safe)) {
      return '/login?return=${Uri.encodeComponent(safe)}';
    }
    return safe;
  }

  // 2. Standard auth gate.
  if (!isLoggedIn && _requiresAuth(loc)) {
    return '/login?return=${Uri.encodeComponent(loc)}';
  }

  return null;
}

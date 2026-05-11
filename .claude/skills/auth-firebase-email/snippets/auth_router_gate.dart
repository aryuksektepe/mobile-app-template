// GoRouter auth gate. Routes:
//   /splash    — initial async resolution
//   /login     — sign in / sign up
//   /verify    — email verification waiting screen (shown after signup)
//   /home      — main app (requires logged in + verified)
//
// Combines with onboarding-flow's redirect — chain them in your top-level redirect.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';

/// Drop-in redirect for GoRouter. Returns the path to redirect to,
/// OR null if the current location is allowed.
String? authRedirect(BuildContext ctx, GoRouterState state, WidgetRef ref) {
  final asyncUser = ref.read(authStateProvider);
  if (asyncUser.isLoading) {
    // Still resolving auth state — splash holds.
    return state.matchedLocation == '/splash' ? null : '/splash';
  }

  final User? user = asyncUser.valueOrNull;
  final loc = state.matchedLocation;
  final loggedIn = user != null;

  // Always allow login/signup routes.
  if (loc.startsWith('/login') || loc.startsWith('/signup') || loc.startsWith('/forgot')) {
    if (loggedIn && user.emailVerified) return '/home';
    return null;
  }

  if (!loggedIn) {
    // Save intended destination for post-login replay.
    return '/login?return=${Uri.encodeComponent(loc)}';
  }

  // Email verification gate (toggle off if your app allows unverified users).
  const requireEmailVerified = true;
  if (requireEmailVerified && !user.emailVerified && loc != '/verify') {
    return '/verify';
  }

  if (loc == '/verify' && user.emailVerified) {
    return '/home';
  }

  return null;
}

/// Bridge `Stream<User?>` to a `Listenable` for GoRouter.refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

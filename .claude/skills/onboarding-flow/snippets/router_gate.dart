// GoRouter integration: gate users to /onboarding until completed.
// Stash incoming deep link → replay AFTER complete().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_controller.dart';

/// Stashed deep link arriving DURING onboarding. Replayed after complete().
final pendingDeepLinkProvider = StateProvider<String?>((_) => null);

/// Add to your GoRouter `redirect` callback:
String? onboardingRedirect(BuildContext ctx, GoRouterState state, WidgetRef ref) {
  final ob = ref.read(onboardingControllerProvider).valueOrNull;

  // First-launch async resolution still in flight → splash holds.
  if (ob == null) {
    return state.matchedLocation == '/splash' ? null : '/splash';
  }

  final loc = state.matchedLocation;
  final inOnboarding = loc.startsWith('/onboarding');

  if (!ob.completed && !inOnboarding) {
    // Stash the URL the user TRIED to go to (deep link) for replay later.
    if (loc != '/' && loc != '/splash') {
      ref.read(pendingDeepLinkProvider.notifier).state = loc;
    }
    return '/onboarding';
  }

  if (ob.completed && inOnboarding) {
    final pending = ref.read(pendingDeepLinkProvider);
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    return pending ?? '/home';
  }

  return null;
}

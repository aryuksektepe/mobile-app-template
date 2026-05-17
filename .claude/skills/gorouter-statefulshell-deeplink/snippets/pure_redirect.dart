import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Pure redirect: reads state, returns a path. NO provider mutation here —
// that is the ADR-033 "modified a provider during build" cold-start crash.
GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/', // a deep link replaces this as the cold initial loc
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);            // READ only
      final onboarded = ref.read(onboardingDoneProvider);  // READ only
      final loc = state.matchedLocation;

      if (auth.isLoading) return null;            // stay; no side effect
      if (!auth.isAuthed && !_isPublic(loc)) return '/auth/login';
      if (auth.isAuthed && !onboarded && loc != '/onboarding') {
        return '/onboarding';
      }
      return null; // let the deep target through
    },
    routes: $appRoutes,
  );
}

bool _isPublic(String loc) =>
    loc == '/auth/login' || loc == '/' || loc.startsWith('/legal');

// Side-effects (e.g. consume a one-time deep-link token, mark "seen") belong
// OUTSIDE redirect — in a root ref.listen or a post-frame callback:
//   WidgetsBinding.instance.addPostFrameCallback((_) =>
//       ref.read(deepLinkProvider.notifier).consume());

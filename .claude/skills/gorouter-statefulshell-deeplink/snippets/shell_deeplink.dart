import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Deep link into a tab MUST switch the StatefulShellRoute branch. A bare
// context.go() not under the branch leaves the shell on the old tab (ADR-034).

final shellRoute = StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      ScaffoldWithNav(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/home', builder: _home)]),
    StatefulShellBranch(routes: [
      GoRoute(path: '/lessons', builder: _lessons, routes: [
        // Deep target lives UNDER its branch → shell selects branch 1.
        GoRoute(path: ':lessonId', builder: _lessonDetail),
      ]),
    ]),
    StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: _profile)]),
  ],
);

// Warm deep link from a handler: switch branch explicitly, then navigate.
// `initialLocation: idx == currentIndex` = same semantics as a nav-bar tap
// (repeat target resets the branch root; a different target just activates it).
void openLessonFromLink(
  BuildContext context,
  StatefulNavigationShell shell,
  String lessonId,
) {
  final i = 1; // Lessons branch
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
  // Path is UNDER branch 1, so navigating within it keeps the branch active:
  context.go('/lessons/$lessonId');
}
// For the full process-global holder + cold-start handshake (push/cold start
// where you don't have `shell` in scope), see shell_branch_controller.dart.

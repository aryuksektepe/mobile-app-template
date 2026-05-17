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
void openLessonFromLink(StatefulNavigationShell shell, String lessonId) {
  shell.goBranch(1);                 // make the Lessons tab active
  shell.shellRouteContext... ;       // then go to the detail within it:
  // context.go('/lessons/$lessonId');  // path is under branch 1 → branch stays
}

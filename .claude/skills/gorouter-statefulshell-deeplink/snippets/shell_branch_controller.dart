// Production-hardened StatefulShellRoute branch switch for deep-link/push.
//
// WHY: a redirect (or an ancestor GoRouter.go) that returns a branch location
// updates matchedLocation but does NOT switch the IndexedStack — the shell
// snaps back to branch 0. The ONLY reliable switch is the same call the
// bottom-nav taps make: navigationShell.goBranch(idx, initialLocation: ...).
// That shell only exists inside StatefulShellRoute.builder, so we hold it in a
// process-global holder and consume the pending link OUTSIDE redirect.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── 1. Process-global shell holder ───────────────────────────────────────────
// Assigned in StatefulShellRoute.builder; read by the navigator below. A plain
// holder (NOT a provider) so reading it is never a "ref during build".
class ShellBranchController {
  ShellBranchController._();
  static final ShellBranchController instance = ShellBranchController._();

  StatefulNavigationShell? _shell;
  set shell(StatefulNavigationShell s) => _shell = s;
  bool get isReady => _shell != null;

  /// Switch to [index]. `initialLocation: idx == currentIndex` makes a repeat
  /// target reset the branch to its root (matches bottom-nav tap semantics);
  /// a different target just activates the branch without popping it.
  void goBranch(int index) {
    final s = _shell;
    if (s == null) return; // not mounted yet — caller re-arms (handshake)
    s.goBranch(index, initialLocation: index == s.currentIndex);
  }
}

// In your router:
//   StatefulShellRoute.indexedStack(
//     builder: (context, state, navigationShell) {
//       ShellBranchController.instance.shell = navigationShell; // capture
//       return ScaffoldWithNav(navigationShell: navigationShell);
//     },
//     branches: [...],
//   )

// ── 2. Pending-link slot (consumed OUTSIDE redirect) ─────────────────────────
// A new object every set() so listeners always fire even for an identical path
// (a notifier that notifies on !identical). The consumer guards on `!= null`,
// NOT `next != prev` — value-equality ('/x' != '/x' == false) would swallow a
// re-delivered link and poison the slot (pitfall P9).
class PendingDeepLink {
  PendingDeepLink(this.target); // e.g. branch index + optional sub-path
  final int branchIndex;
  static PendingDeepLink? _building;
}

final pendingDeepLinkProvider =
    StateProvider<int?>((ref) => null); // null = nothing pending

// ── 3. _DeepLinkNavigator: mounted in MaterialApp.router builder ──────────────
// This widget lives OUTSIDE redirect (rule 1) and OUTSIDE the shell, so it can
// drive the shell once it exists. It owns the bounded cold-start handshake.
class DeepLinkNavigator extends ConsumerStatefulWidget {
  const DeepLinkNavigator({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DeepLinkNavigator> createState() => _DeepLinkNavigatorState();
}

class _DeepLinkNavigatorState extends ConsumerState<DeepLinkNavigator> {
  static const _maxArmAttempts = 20; // ~ shell mount budget on cold start
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    // Re-deliver whatever is already pending at first frame (cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryConsume());
  }

  void _tryConsume() {
    final pending = ref.read(pendingDeepLinkProvider);
    if (pending == null) return;

    if (!ShellBranchController.instance.isReady) {
      // Shell not mounted yet. Re-arm — but BOUNDED. When the cap is hit we
      // MUST clear unconditionally, else the slot stays poisoned and every
      // future launch is stuck on this link (pitfall P8).
      if (_attempts++ >= _maxArmAttempts) {
        ref.read(pendingDeepLinkProvider.notifier).state = null; // give up cleanly
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) => _tryConsume());
      return;
    }

    ShellBranchController.instance.goBranch(pending);
    ref.read(pendingDeepLinkProvider.notifier).state = null; // consume once
    _attempts = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Guard on `!= null` only — NOT `next != previous` (P9).
    ref.listen<int?>(pendingDeepLinkProvider, (_, next) {
      if (next != null) _tryConsume();
    });
    return widget.child;
  }
}

// Wire it as MaterialApp.router(builder: (c, child) =>
//   DeepLinkNavigator(child: child!))  — single Router mount (see
// deeplinks-go-router pitfalls: MaterialApp(home:)+nested Router = black screen).

// A push/universal-link handler just parks the target; it never calls
// GoRouter.go for a tab and never mutates a provider inside redirect:
//   ref.read(pendingDeepLinkProvider.notifier).state = resolvedBranchIndex;

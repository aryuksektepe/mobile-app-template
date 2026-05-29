// AppLockGate — MaterialApp.builder overlay.
// Wire as:
//   MaterialApp(
//     builder: (ctx, child) => AppLockGate(child: child ?? const SizedBox()),
//     ...
//   )

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_lock_controller.dart';
import 'lifecycle_tracker.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child, required this.hasSession});
  final Widget child;

  /// Pass from your auth provider — gate only locks when a session exists.
  /// (Don't show the lock screen during onboarding / login.)
  final bool Function() hasSession;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with LifecycleTracker {
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    // Defer init to first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLockControllerProvider.notifier).init();
    });
  }

  @override
  void onRealResume() {
    setState(() => _hidden = false);
    if (widget.hasSession()) {
      ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  @override
  void onMaybeHidden() {
    if (!_hidden) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockControllerProvider);
    final hasSession = widget.hasSession();

    final shouldLock =
        hasSession && state.enabled && state.isLocked && state.initialized;

    // Pre-init cover: hasSession but storage not yet read → prevent content flash.
    final preInitCover = hasSession && !state.initialized;

    return Stack(
      children: [
        widget.child,
        if (_hidden && hasSession) const _PrivacyCover(),
        if (preInitCover) const _PrivacyCover(),
        if (shouldLock)
          const Positioned.fill(child: AppLockScreen()),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();
  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: Icon(Icons.lock_rounded,
            size: 48, color: Theme.of(context).colorScheme.onSurface),
      );
}

/// Replace with your design-system PIN pad. Skeleton only.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});
  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = ref.read(appLockControllerProvider.notifier);
      // Try biometric automatically. iOS 26 transient: returns false → PIN pad.
      await ctrl.tryUnlockWithBiometric();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Your design-system PIN pad + lockout countdown go here.
    return const Scaffold(
      body: Center(child: Text('App Lock — replace with PIN pad UI')),
    );
  }
}

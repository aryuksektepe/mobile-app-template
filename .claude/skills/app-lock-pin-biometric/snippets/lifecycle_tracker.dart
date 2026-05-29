// Lifecycle tracker — distinguishes REAL background (`paused → resumed`)
// from transient interruptions (biometric dialog, control center, notification
// drawer, incoming-call sheet = `inactive → resumed`).
//
// The naive pattern `if (state == resumed) controller.lock()` causes the
// biometric-infinite-loop pitfall (see pitfalls.md #1):
//   Face ID dialog opens  → app `inactive`
//   user authenticates    → dialog closes
//   app `resumed`         → controller.lock() → Face ID dialog opens again → ...
//
// Mixin into your AppLockGate's State.

import 'package:flutter/widgets.dart';

mixin LifecycleTracker<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  AppLifecycleState? _lastMeaningfulState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Override this — called only on REAL background → foreground transition.
  void onRealResume();

  /// Override this — called on any "app might be visible to others" state.
  void onMaybeHidden();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_lastMeaningfulState == AppLifecycleState.paused) {
          onRealResume();
        }
        // inactive → resumed: dialog/control-center close. Do NOT re-lock.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        onMaybeHidden();
        break;
      case AppLifecycleState.detached:
        break;
    }

    // Track only the "meaningful" states (paused/resumed). `inactive` is
    // transient and intentionally ignored as a marker.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _lastMeaningfulState = state;
    }
  }

  // ---- WidgetsBindingObserver no-op defaults (override if needed) ----
  @override
  void didChangeAccessibilityFeatures() {}
  @override
  void didChangeLocales(List<Locale>? locales) {}
  @override
  void didChangeMetrics() {}
  @override
  void didChangePlatformBrightness() {}
  @override
  void didChangeTextScaleFactor() {}
  @override
  void didHaveMemoryPressure() {}
  @override
  Future<bool> didPopRoute() async => false;
  @override
  Future<bool> didPushRoute(String route) async => false;
  @override
  Future<bool> didPushRouteInformation(RouteInformation r) async => false;
  @override
  Future<AppExitResponse> didRequestAppExit() async =>
      AppExitResponse.exit;
  @override
  void didChangeViewFocus(ViewFocusEvent event) {}
  @override
  void handleCancelBackGesture() {}
  @override
  void handleCommitBackGesture() {}
  @override
  bool handleStartBackGesture(PredictiveBackEvent event) => false;
  @override
  bool handleUpdateBackGestureProgress(PredictiveBackEvent event) => false;
}

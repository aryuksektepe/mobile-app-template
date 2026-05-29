// Proof-of-work boot markers. app-bootstrap wires these into the shared
// bootstrap()/each main_<flavor>() entrypoint. They are what makes
// INTEGRATION_SMOKE un-fakeable: the sha comes from the BUILD's --dart-define,
// so a marker with the right sha can only exist if the app was actually built
// at that commit and booted. (CLAUDE.md §3, decisions.md ADR-011.)
//
// Build/run MUST pass it:  --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
// tool/run_smoke.sh does this automatically.

import 'package:flutter/foundation.dart';

/// Injected at build time; defaults to UNKNOWN for plain `flutter run` without
/// the dart-define (which then fails the smoke gate — by design).
const String kGitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'UNKNOWN');

/// Call as the LAST line of main()/bootstrap(), after runApp().
void emitBootOk(String flavor) {
  debugPrint('BOOT_OK flavor=$flavor sha=$kGitSha '
      'ts=${DateTime.now().toIso8601String()}');
}

/// Call once, after the first real screen has rendered. The cleanest place is a
/// post-frame callback on the first non-splash route, e.g. in the root widget:
///
///   WidgetsBinding.instance.addPostFrameCallback(
///     (_) => emitFirstScreenOk(GoRouter.of(context).state.uri.path));
///
/// Emitting it from the SPLASH frame is wrong — a splash that never navigates
/// is not a passing boot. Emit it from the first real destination.
void emitFirstScreenOk(String route) {
  debugPrint('FIRST_SCREEN_OK route=$route sha=$kGitSha');
}

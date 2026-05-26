// update_gate.dart — version comparison + Riverpod state + foreground re-check.
// Wire into go_router redirect:
//
//   redirect: (ctx, state) {
//     final gate = ProviderScope.containerOf(ctx).read(updateGateProvider).valueOrNull;
//     if (gate?.force == true && state.matchedLocation != '/force-update') return '/force-update';
//     return null;
//   }
//
// And mount a Scaffold listener for app-lifecycle resume to refresh.

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateLevel { none, soft, force }

class UpdateGate {
  const UpdateGate({
    required this.level,
    required this.currentVersion,
    required this.minimumVersion,
    required this.recommendedVersion,
    required this.message,
  });
  final UpdateLevel level;
  final String currentVersion;
  final String minimumVersion;
  final String recommendedVersion;
  final String? message;

  bool get force => level == UpdateLevel.force;
  bool get soft => level == UpdateLevel.soft;
}

final updateGateProvider = FutureProvider<UpdateGate>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final rc = FirebaseRemoteConfig.instance;
  // ensureInitialized called at app boot per `remote-config-firebase`
  await rc.fetchAndActivate().catchError((_) => false);

  final minVer = rc.getString('minimum_version');
  final recVer = rc.getString('recommended_version');
  final current = info.version;

  final UpdateLevel level;
  String? message;
  if (minVer.isNotEmpty && _semverLt(current, minVer)) {
    level = UpdateLevel.force;
    message = rc.getString('update_force_message');
  } else if (recVer.isNotEmpty && _semverLt(current, recVer)) {
    level = UpdateLevel.soft;
    message = rc.getString('update_soft_message');
  } else {
    level = UpdateLevel.none;
  }

  return UpdateGate(
    level: level,
    currentVersion: current,
    minimumVersion: minVer,
    recommendedVersion: recVer,
    message: message?.isEmpty == true ? null : message,
  );
});

/// Compares two semver strings (major.minor.patch). Returns true if a < b.
/// Falls back to string compare if either side is not parseable (defensive).
bool _semverLt(String a, String b) {
  final ap = _parse(a), bp = _parse(b);
  if (ap == null || bp == null) return a.compareTo(b) < 0;
  for (var i = 0; i < 3; i++) {
    if (ap[i] < bp[i]) return true;
    if (ap[i] > bp[i]) return false;
  }
  return false;
}

List<int>? _parse(String v) {
  final parts = v.split('+').first.split('-').first.split('.');
  if (parts.length < 3) return null;
  try {
    return parts.take(3).map(int.parse).toList(growable: false);
  } catch (_) {
    return null;
  }
}

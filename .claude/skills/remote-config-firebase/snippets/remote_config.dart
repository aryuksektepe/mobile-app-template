// Typed Remote Config snapshot + Riverpod StreamProvider.
// Re-emits on real-time updates (since firebase_remote_config 4.0.0).
//
// Add a key:
//   1. setDefaults() in init_remote_config.dart
//   2. add field to AppConfig
//   3. add line to AppConfig.fromRemote
//   4. add field to Firebase Console with same key

import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_config.freezed.dart';

@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    required bool featureXEnabled,
    required String paywallVariant,        // 'control' | 'variant_a' | 'variant_b'
    required int minSupportedBuild,
    required bool maintenanceMode,
    required String maintenanceMessage,
  }) = _AppConfig;

  factory AppConfig.fromRemote(FirebaseRemoteConfig rc) => AppConfig(
        featureXEnabled: rc.getBool('feature_x_enabled'),
        paywallVariant: rc.getString('paywall_variant'),
        minSupportedBuild: rc.getInt('min_supported_build'),
        maintenanceMode: rc.getBool('maintenance_mode'),
        maintenanceMessage: rc.getString('maintenance_message'),
      );

  /// Safe defaults — used until first activation, AND if Firebase is offline.
  /// Every value MUST be sane standalone — never depend on remote.
  static const Map<String, Object> defaults = {
    'feature_x_enabled': false,
    'paywall_variant': 'control',
    'min_supported_build': 1,        // never accidentally block users
    'maintenance_mode': false,
    'maintenance_message': '',
  };
}

final remoteConfigProvider = Provider<FirebaseRemoteConfig>(
  (_) => FirebaseRemoteConfig.instance,
);

/// StreamProvider that emits a typed AppConfig snapshot, re-emitting on
/// real-time updates from Firebase Console.
final appConfigProvider = StreamProvider<AppConfig>((ref) async* {
  final rc = ref.watch(remoteConfigProvider);

  // Initial value (uses defaults if not yet fetched).
  yield AppConfig.fromRemote(rc);

  // Subscribe to real-time updates.
  final sub = rc.onConfigUpdated.listen((event) async {
    await rc.activate();
  });

  // Yield on each update.
  await for (final _ in rc.onConfigUpdated) {
    await rc.activate();
    yield AppConfig.fromRemote(rc);
  }

  ref.onDispose(() => sub.cancel());
});

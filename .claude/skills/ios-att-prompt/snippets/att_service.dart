// ATT service — boot once, request from natural moment, expose status as a stream.
// Riverpod-friendly. Idempotent: calling request() after a resolved status is a no-op.
//
// Usage:
//   await AttService.instance.bootstrap();   // in main()
//   final status = await AttService.instance.request();  // from pre-prompt CTA
//
// Reset for QA: xcrun simctl privacy <udid> reset tracking <bundle-id>

import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final attStatusProvider = StateProvider<TrackingStatus>(
  (ref) => TrackingStatus.notDetermined,
);

class AttService {
  AttService._();
  static final instance = AttService._();

  TrackingStatus _status = TrackingStatus.notDetermined;
  TrackingStatus get status => _status;
  bool get granted => _status == TrackingStatus.authorized;
  bool get resolved => _status != TrackingStatus.notDetermined;

  /// Call once from main(). Reads the cached status WITHOUT triggering the system prompt.
  Future<void> bootstrap() async {
    if (!Platform.isIOS) {
      _status = TrackingStatus.authorized; // non-iOS: no ATT regime
      return;
    }
    _status = await AppTrackingTransparency.trackingAuthorizationStatus;
  }

  /// Show the SYSTEM prompt. Call ONLY after the user tapped "Continue" on your
  /// pre-prompt. No-op if already resolved (Apple shows the prompt once per install;
  /// subsequent calls return the cached value).
  Future<TrackingStatus> request() async {
    if (!Platform.isIOS) return TrackingStatus.authorized;
    _status = await AppTrackingTransparency.requestTrackingAuthorization();
    return _status;
  }

  /// IDFA after ATT. Returns all-zeros UUID if denied — never use as user identifier.
  Future<String> advertisingIdentifier() async {
    if (!Platform.isIOS || !granted) return '00000000-0000-0000-0000-000000000000';
    return AppTrackingTransparency.getAdvertisingIdentifier();
  }
}

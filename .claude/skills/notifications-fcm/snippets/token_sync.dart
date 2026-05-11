// FCM token storage with multi-device awareness.
// Tokens are DEVICE-scoped, not user-scoped. A user with phone + tablet has
// 2 tokens, both should receive a personal push.
//
// Server-side schema:
//   user_fcm_tokens (user_id PK, device_id PK, token, platform, updated_at)
// On send: query for all rows where user_id = X, send to each token.
// Cleanup: delete row when send returns FCM `UNREGISTERED` error.
//          OR delete row if updated_at < now() - 30 days.

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class TokenSyncBackend {
  /// PUT /me/fcm-tokens with body { device_id, token, platform }
  Future<void> upsertToken({
    required String deviceId,
    required String token,
    required String platform,
  });

  /// DELETE /me/fcm-tokens/{device_id}
  Future<void> deleteToken({required String deviceId});
}

class TokenSyncService {
  TokenSyncService(this._backend, this._deviceId, this._platform);
  final TokenSyncBackend _backend;
  final String _deviceId;
  final String _platform;     // 'ios' | 'android'

  StreamSubscription<String>? _refreshSub;

  /// Call after user has signed in AND notification permission granted.
  Future<void> startSyncing() async {
    final initial = await FirebaseMessaging.instance.getToken();
    if (initial != null) {
      await _backend.upsertToken(
        deviceId: _deviceId,
        token: initial,
        platform: _platform,
      );
    }

    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _backend.upsertToken(
        deviceId: _deviceId,
        token: token,
        platform: _platform,
      );
    });
  }

  /// Call on logout. Removes this device's token from backend.
  Future<void> stopAndDelete() async {
    await _refreshSub?.cancel();
    _refreshSub = null;

    try {
      await _backend.deleteToken(deviceId: _deviceId);
    } catch (_) {
      // best-effort; backend cleanup will eventually GC stale tokens
    }

    // Optionally also call FirebaseMessaging.instance.deleteToken() —
    // forces a new token on next getToken() call. Use this for full
    // privacy-respecting logout (no future delivery to old token).
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}

// SecureTokenRepository — single source of truth for auth secrets.
// Mutex-serialized refresh prevents concurrent-refresh replay attacks
// (multiple parallel API 401s would otherwise rotate the refresh token
// twice, revoking the second one and forcing a logout).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mutex/mutex.dart';

const _kAccessToken = 'auth.access_token';
const _kRefreshToken = 'auth.refresh_token';
const _kIdToken = 'auth.id_token';

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),  // v10 default = custom RSA+AES, Keystore-backed
    iOptions: IOSOptions(
      // first_unlock_this_device: survives reboot, NOT iCloud restore.
      // Recommended default for refresh tokens — prevents account takeover
      // via restored backup on attacker's device.
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
});

class SecureTokenRepository {
  SecureTokenRepository(this._storage);
  final FlutterSecureStorage _storage;
  final _refreshMutex = Mutex();

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> readIdToken() => _storage.read(key: _kIdToken);

  Future<void> writeTokens({
    required String access,
    required String refresh,
    String? id,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: access),
      _storage.write(
        key: _kRefreshToken,
        value: refresh,
        // Optional biometric protection on Android (v10):
        aOptions: const AndroidOptions(),
      ),
      if (id != null) _storage.write(key: _kIdToken, value: id),
    ]);
  }

  /// Run [refreshFn] under a mutex so concurrent 401s don't both rotate the
  /// refresh token. [refreshFn] receives the OLD refresh token and returns
  /// a new (access, refresh) pair.
  ///
  /// Returns the new access token, or null if refresh failed.
  Future<String?> refreshIfNeeded(
    Future<({String access, String refresh})> Function(String old) refreshFn,
  ) {
    return _refreshMutex.protect(() async {
      final old = await _storage.read(key: _kRefreshToken);
      if (old == null) return null;

      try {
        final pair = await refreshFn(old);
        await writeTokens(access: pair.access, refresh: pair.refresh);
        return pair.access;
      } catch (_) {
        // Refresh failed → tokens are stale. Caller should redirect to login.
        return null;
      }
    });
  }

  /// Wipe ALL token-related entries. Call on logout AND on account deletion.
  /// Critical for KVKK/GDPR-compliant logout.
  Future<void> clearAll() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kIdToken);
  }
}

final tokenRepoProvider = Provider<SecureTokenRepository>((ref) {
  return SecureTokenRepository(ref.watch(secureStorageProvider));
});

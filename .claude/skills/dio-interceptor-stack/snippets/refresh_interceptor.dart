// RefreshTokenInterceptor — mutex-serialized 401 → refresh → replay.
// Prevents the canonical "10 in-flight requests all 401 at once → 10 refresh
// calls → backend rate-limits → cascade failure" bug.
//
// Algorithm:
//   - On 401: acquire mutex. ONE caller does the refresh.
//   - Other 401s block on the mutex; when it releases, they replay with new token.
//   - Refresh failure → sign out + propagate 401.

import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

class RefreshTokenInterceptor extends Interceptor {
  RefreshTokenInterceptor(this._dio);
  final Dio _dio;
  final _lock = Lock();
  bool _hasRefreshedRecently = false;
  Future<void>? _inFlightRefresh;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Avoid loop: if this WAS the refresh call itself, propagate failure
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await _signOutLocal();
      return handler.next(err);
    }

    try {
      // Mutex: only one refresh in flight; others await it
      await _lock.synchronized(() async {
        if (!_hasRefreshedRecently) {
          _inFlightRefresh = _doRefresh();
          await _inFlightRefresh;
          _hasRefreshedRecently = true;
          // Reset the flag after 5s so subsequent 401s try again
          Future.delayed(const Duration(seconds: 5), () => _hasRefreshedRecently = false);
        } else {
          // Another caller already refreshed within the last 5s — wait for it
          await _inFlightRefresh;
        }
      });

      // Replay the original request with new token
      final newToken = await _readAccessToken();
      final retryOpts = Options(
        method: err.requestOptions.method,
        headers: {
          ...err.requestOptions.headers,
          'authorization': 'Bearer $newToken',
        },
      );
      final response = await _dio.request<dynamic>(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: retryOpts,
      );
      return handler.resolve(response);
    } catch (e) {
      // Refresh failed → propagate the original 401, sign user out
      await _signOutLocal();
      return handler.next(err);
    }
  }

  Future<void> _doRefresh() async {
    final refreshToken = await _readRefreshToken();
    if (refreshToken == null) throw Exception('no-refresh-token');
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      // Do NOT include auth interceptor's stale token — refresh is unauthenticated
      options: Options(headers: {'authorization': null}),
    );
    final newAccess = res.data['access_token'] as String;
    final newRefresh = res.data['refresh_token'] as String?;
    await _writeAccessToken(newAccess);
    if (newRefresh != null) await _writeRefreshToken(newRefresh);
  }
}

// Wire these to flutter_secure_storage (per `secure-storage-tokens` skill)
Future<String?> _readAccessToken() async => null;
Future<String?> _readRefreshToken() async => null;
Future<void> _writeAccessToken(String token) async {}
Future<void> _writeRefreshToken(String token) async {}
Future<void> _signOutLocal() async {
  // Clear all auth state — router auth gate will redirect to /welcome
}

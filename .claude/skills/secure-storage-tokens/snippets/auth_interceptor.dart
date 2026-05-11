// Dio AuthInterceptor — auto-injects Bearer token, refreshes on 401, retries.
// Pairs with SecureTokenRepository for safe concurrent refresh handling.

import 'package:dio/dio.dart';

import 'secure_token_repository.dart';

/// [refresh] is your network call that exchanges old refresh token for
/// a new (access, refresh) pair. Implement in your auth API client.
typedef RefreshFn = Future<({String access, String refresh})> Function(String oldRefresh);

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._repo, this._refresh);

  final SecureTokenRepository _repo;
  final RefreshFn _refresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _repo.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Avoid infinite retry on the refresh endpoint itself.
    if (err.requestOptions.extra['skip_auth_retry'] == true) {
      return handler.next(err);
    }

    final newAccess = await _repo.refreshIfNeeded(_refresh);
    if (newAccess == null) {
      // Refresh failed → caller (e.g., auth state listener) should sign out.
      await _repo.clearAll();
      return handler.next(err);
    }

    // Retry the original request with the new token.
    final retryReq = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newAccess'
      ..extra['skip_auth_retry'] = true;

    try {
      final retryDio = Dio(); // detached to avoid recursive interceptor chain
      final response = await retryDio.fetch(retryReq);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

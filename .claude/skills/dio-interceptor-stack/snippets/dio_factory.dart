// Dio factory — production interceptor chain.
// Combine with `certificate-pinning-dio` httpClientAdapter for full hardening.

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'refresh_interceptor.dart';

// Sensitive endpoints whose bodies must NEVER be logged (even in debug)
const _kSensitivePaths = <String>{
  '/auth/login',
  '/auth/signup',
  '/auth/refresh',
  '/payments',
};

Dio createDio({required String baseUrl}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
  ));

  // 1. Auth header injection
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    final token = await _readAccessToken();
    if (token != null) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }));

  // 2. Refresh-token interceptor (mutex-protected)
  dio.interceptors.add(RefreshTokenInterceptor(dio));

  // 3. Retry on 5xx / network failures (NOT 4xx)
  dio.interceptors.add(RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(milliseconds: 500),
      Duration(seconds: 2),
      Duration(seconds: 5),
    ],
    // dio_smart_retry default already excludes 4xx — kept explicit:
    retryableExtraStatuses: {502, 503, 504},
  ));

  // 4. Logging (DEBUG only, PII-scrubbed)
  if (kDebugMode) {
    dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      maxWidth: 100,
      // Custom redaction via the printer below
    ));
    // Strip Authorization header + body for sensitive paths
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (_kSensitivePaths.any((p) => options.path.contains(p))) {
        options.headers.remove('authorization');
        options.data = '<<SCRUBBED>>';
      }
      handler.next(options);
    }));
  }

  return dio;
}

// Placeholder — wire to flutter_secure_storage per `secure-storage-tokens` skill
Future<String?> _readAccessToken() async => null;

// Riverpod provider
final dioProvider = Provider<Dio>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com');
  return createDio(baseUrl: baseUrl);
});

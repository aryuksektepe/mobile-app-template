// PII scrubber for Sentry. Removes/redacts:
// - User email, IP address
// - Authorization headers + Cookie headers
// - Query strings containing token/key/secret
// - Request bodies (entirely — too noisy + risk-prone to whitelist fields)

import 'package:sentry_flutter/sentry_flutter.dart';

const _sensitiveHeaders = {
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
  'proxy-authorization',
};

const _sensitiveQueryParams = {
  'access_token',
  'token',
  'refresh_token',
  'api_key',
  'apikey',
  'secret',
  'password',
};

SentryEvent? sentryBeforeSend(SentryEvent event, Hint hint) {
  // 1. Strip user PII
  if (event.user != null) {
    event = event.copyWith(
      user: event.user!.copyWith(
        email: null,
        ipAddress: null,
        // id/username should already be opaque hash from identify_user.dart
      ),
    );
  }

  // 2. Strip server name (often contains hostname / build host)
  event = event.copyWith(serverName: '');

  // 3. Scrub request headers + query
  if (event.request != null) {
    final req = event.request!;

    final cleanHeaders = <String, String>{};
    req.headers.forEach((k, v) {
      cleanHeaders[k] = _sensitiveHeaders.contains(k.toLowerCase()) ? '<redacted>' : v;
    });

    String? cleanQuery;
    if (req.queryString != null) {
      final pairs = req.queryString!.split('&').map((p) {
        final i = p.indexOf('=');
        if (i < 0) return p;
        final key = p.substring(0, i);
        final value = p.substring(i + 1);
        return _sensitiveQueryParams.contains(key.toLowerCase())
            ? '$key=<redacted>'
            : '$key=$value';
      });
      cleanQuery = pairs.join('&');
    }

    event = event.copyWith(
      request: req.copyWith(
        headers: cleanHeaders,
        queryString: cleanQuery,
        data: null, // body — never send (whitelist approach is too risky)
        cookies: null,
      ),
    );
  }

  return event;
}

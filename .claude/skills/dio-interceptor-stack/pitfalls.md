# Dio Interceptor Stack — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | Backend logs show 10x refresh calls per second after a server outage | No mutex on 401 → concurrent in-flight requests each trigger their own refresh | `synchronized` Lock (snippet); single refresh, others await + replay | [Refresh token best practices](https://oauth.net/2/refresh-tokens/) |
| 2 | App stuck in infinite "refresh → 401 → refresh" loop | Refresh endpoint itself returns 401 (refresh token expired); interceptor calls it again | Detect path is `/auth/refresh` → sign out, don't re-enter the loop | this skill's own pattern |
| 3 | dio retries a 401 with the OLD token, gets 401 again | RetryInterceptor placed BEFORE refresh interceptor → retries before refresh runs | Order: auth → refresh → retry → logging. The order in `createDio()` is critical | [dio interceptor order](https://pub.dev/packages/dio#interceptors) |
| 4 | Logs show user's password in `/auth/login` body | Logging interceptor in debug with no scrub | Scrub sensitive paths' body + Authorization header via separate redact interceptor (per snippet) | OWASP MASVS-PLATFORM |
| 5 | Backend gets killed by retry storm during outage | RetryInterceptor retries 5xx, but with no global circuit breaker | Set `retries: 3` MAX with exponential backoff; do NOT retry 4xx; consider a circuit breaker for repeated failures | [Exponential backoff](https://cloud.google.com/storage/docs/retry-strategy) |
| 6 | Widget disposed but the dio request continues + tries to update an unmounted Provider | Request not cancelled on dispose | Attach `CancelToken` per Riverpod-scoped request; cancel in `ref.onDispose` | [Dio cancel tokens](https://pub.dev/packages/dio#cancellation) |
| 7 | Refresh interceptor causes a race: 2 refreshes BOTH succeed, but tokens written in wrong order | Lock acquired AFTER computing new token rather than around the whole refresh | Wrap the entire fetch+persist inside `_lock.synchronized` (per snippet) | concurrency basics |
| 8 | "ClientException: Connection terminated during handshake" in CI | CI runs on a sandbox without DNS — every test that hits a real URL fails | Mock the dio client at the test boundary; never let unit tests touch real network | this skill's testing guidance |
| 9 | Authorization header sometimes missing | Auth interceptor reads from secure storage; storage returns null on cold start race | Initialize auth state from secure storage in `main()` before `runApp` so the read is cached | per `secure-storage-tokens` |
| 10 | API base URL hardcoded to prod | No `--dart-define` flavor switch | Use `String.fromEnvironment('API_BASE_URL')` + per-flavor build scripts | Flutter flavors guide |

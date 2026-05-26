# Dio Interceptor Stack — Verification Checklist

- [ ] Interceptor order: auth → refresh → retry → (debug-only) logging
- [ ] Mutex (`Lock()`) wraps the refresh path
- [ ] Single in-flight refresh under concurrent 401 (unit-test: 5 simultaneous 401s = 1 refresh)
- [ ] Refresh failure → sign out + propagate original 401 (no loop)
- [ ] RetryInterceptor: 3 retries, exponential, 5xx + network only (NOT 4xx)
- [ ] Logging interceptor disabled in release (`kDebugMode` guard)
- [ ] Sensitive paths body + Authorization header scrubbed in debug logs
- [ ] Base URL from `--dart-define`, per flavor
- [ ] CancelToken pattern documented for Riverpod-scoped requests
- [ ] Unit tests: 401 flow, refresh-fails flow, concurrent 401 mutex
- [ ] Pairs cleanly with `certificate-pinning-dio` HttpClient adapter for prod hardening

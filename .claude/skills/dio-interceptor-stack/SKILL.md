---
name: dio-interceptor-stack
description: Production Dio interceptor stack — auth header injection (from secure-storage-tokens), 401 refresh-token mutex (concurrent-call serialization, no token storms), exponential retry on transient failures, request/response logging with PII scrubbing, cancel-token wiring, base URL switching per flavor, network error normalization. Use whenever the app makes authenticated HTTP calls.
triggers: [dio, dio interceptor, http client, retry interceptor, 401 refresh, refresh token mutex, request logging, response logging, cancel token, dio queued lock, token refresh storm, expired access token, 401 handler]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  dio: "^5.7.0"
  dio_smart_retry: "^7.0.1"
  pretty_dio_logger: "^1.4.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [secure-storage-tokens]
---

# Dio Interceptor Stack

## What this skill does

- **Auth interceptor** — reads access token from `flutter_secure_storage` (per `secure-storage-tokens`), injects `Authorization: Bearer ...`.
- **Refresh-token interceptor with mutex** — on 401, ONE concurrent caller refreshes; others queue and replay with new token. Prevents the "10 in-flight 401s = 10 refresh calls" storm.
- **Retry interceptor** (`dio_smart_retry`) — exponential backoff for 5xx, network errors, timeouts. NOT for 4xx.
- **Logging interceptor** (`pretty_dio_logger`) — disabled in release; PII-scrubbed in debug (no Authorization header, no body if endpoint matches sensitive allowlist).
- **Base URL per flavor** — dev/staging/prod from `--dart-define`.
- **Cancel token** — every Riverpod-scoped request carries a token disposed in `ref.onDispose`.

## What this skill does NOT do

- Does NOT pin certificates (`certificate-pinning-dio`).
- Does NOT handle GraphQL (use `graphql_flutter` separately).
- Does NOT do request caching (use `dio_cache_interceptor` separately if needed).

## Decision tree

**Q1: Concurrent 401 strategy?**
- MUTEX (recommended) — queue concurrent 401s, refresh once, replay all. Implemented here via `synchronized` package.
- DROP — fail concurrent 401s; let UI retry. Simpler but worse UX.

**Q2: Log bodies?**
- DEBUG only, sensitive endpoint allowlist (auth, payments) → body stripped.
- RELEASE — never.

## Quick start

```bash
flutter pub add dio dio_smart_retry pretty_dio_logger synchronized
```

Apply [snippets/dio_factory.dart](snippets/dio_factory.dart). Wire as singleton Riverpod provider; combine with `certificate-pinning-dio` HttpClient adapter for prod hardening.

## Code patterns

| Need | File |
|---|---|
| Dio factory with full interceptor chain | [snippets/dio_factory.dart](snippets/dio_factory.dart) |
| Refresh-token interceptor (mutex) | [snippets/refresh_interceptor.dart](snippets/refresh_interceptor.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. No mutex on 401 → 10 in-flight requests = 10 refresh calls → backend rate-limits → cascade failure.
2. Refresh failure (refresh token expired) not handled → infinite refresh loop.
3. Retrying 4xx (especially 401, 403) → flooding the refresh path.
4. Logging interceptor leaking Authorization header in release.
5. Cancel token not disposed on widget dispose → leaked subscription + request continues to backend.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: `secure-storage-tokens`

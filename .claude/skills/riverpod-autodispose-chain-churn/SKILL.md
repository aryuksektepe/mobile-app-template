---
name: riverpod-autodispose-chain-churn
description: An autoDispose provider chain (or a keepAlive provider watching an autoDispose one) thrashes — dispose/recreate per rebuild → request storms (~30 req/s) and flicker. Use when network calls repeat rapidly, a stream re-subscribes constantly, or currentUser/session is recreated on every screen.
triggers: [autoDispose churn, request storm, keepAlive, ref.watch keepAlive, re-subscribe loop, 30 req/s, provider recreated every rebuild, currentUser not keepAlive, progressStream churn]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Riverpod — autoDispose chain churn

## What this skill does

Fixes ADR-022/025/026: a provider that should live for the session
(`currentUser`, `progressStream`, `progressByLesson`) is `autoDispose` (the
codegen default) or is watched by a `keepAlive` provider through an
`autoDispose` link. Each widget rebuild disposes + recreates it → the
repository re-fetches / the stream re-subscribes on a tight loop → ~30 req/s
storms, flicker, battery drain, backend rate-limit.

## Why it ships green

`ProviderContainer` in a unit test is built once and read once — nothing
disposes/recreates. The churn needs a live widget tree rebuilding. Golden
tests pump once. Invisible until the app runs.

## Decision tree — should this provider be kept alive?

- Session/identity (`currentUser`, auth token, feature flags): **keepAlive**.
- Per-screen ephemeral UI state: autoDispose (correct default).
- A stream consumed across screens (progress, realtime): **keepAlive** + a
  single subscription, not per-listener.
- A `keepAlive` provider MUST NOT `ref.watch` an `autoDispose` provider — that
  re-introduces churn through the back door. Use `ref.read` for one-shot, or
  make the dependency keepAlive too.

## The fix

- riverpod_generator: `@Riverpod(keepAlive: true)` on session/stream providers.
- Manual: `final p = Provider(...)` (no `.autoDispose`), or `ref.keepAlive()`
  inside the body once the value is meaningful.
- Break keepAlive→autoDispose watches; audit the whole chain, not one node.
- Add a rebuild-storm regression test: N invalidations ⇒ exactly 1 remote
  call (mock the datasource only to COUNT calls, then also prove it for real
  at INTEGRATION_SMOKE).

## Code patterns

| Need | File |
|---|---|
| keepAlive session/stream providers | [snippets/keepalive_providers.dart](snippets/keepalive_providers.dart) |
| Storm regression test (call-count bound) | [snippets/storm_test.dart](snippets/storm_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-022/025/026)
- Last verified: 2026-05-16

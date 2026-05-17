---
name: riverpod-fetch-then-subscribe-yield
description: An async* (Stream) provider fetches the initial snapshot but never yields it (await result discarded), then subscribes to realtime — so the UI shows empty until the first realtime event, and a broken realtime subscription means永 nothing renders. Use for async*/StreamNotifier providers that do "fetch then watch".
triggers: [async* provider, stream provider, fetch then subscribe, yield* missing, await result discarded, realtime empty until event, StreamNotifier, supabase stream initial snapshot]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Riverpod — fetch-then-subscribe yield contract

## What this skill does

Fixes ADR-029: an `async*` provider does `final rows = await repo.fetch();`
then `yield* repo.watch();` — the initial `rows` is **never yielded**. UI is
empty until the first realtime event arrives; if the realtime channel is
misconfigured, it stays empty forever. The "fetch" looked done because the
`await` ran — but its result went nowhere.

## Why it ships green

A mocked stream test stubs the stream and asserts it emits; it does not assert
that the *fetched snapshot* was yielded before the subscription. The contract
("emit initial, then live updates") is never tested, so the dropped `yield`
is invisible.

## The anti-pattern

```dart
@riverpod
Stream<List<Lesson>> lessons(LessonsRef ref) async* {
  final initial = await repo.fetchLessons();   // fetched…
  // …and silently dropped — never yielded
  yield* repo.watchLessons();                  // empty until first event
}
```

## The fix

```dart
@riverpod
Stream<List<Lesson>> lessons(LessonsRef ref) async* {
  yield await repo.fetchLessons();   // emit the snapshot first
  yield* repo.watchLessons();        // then live updates
}
```

If `watch` already includes an initial event (some SDKs do), don't double-emit
— but then assert THAT contract instead. The rule: every fetched value an
`async*` provider awaits must be `yield`ed or explicitly justified.

## Code patterns
| Need | File |
|---|---|
| Correct fetch-then-subscribe provider | [snippets/lessons_provider.dart](snippets/lessons_provider.dart) |
| Yield-contract test (snapshot THEN updates) | [snippets/yield_contract_test.dart](snippets/yield_contract_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-029)
- Last verified: 2026-05-16

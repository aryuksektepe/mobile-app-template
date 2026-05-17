---
name: supabase-read-through-cache-mirror
description: A repository read returns only the local cache (Drift) and never falls through to remote on a cache miss, so a fresh user sees "nothing here yet" forever. Use when adding a repository read backed by a local mirror/cache, or when content is empty on first run but exists on the server.
triggers: [read-through cache, cache miss remote fallback, listX returns empty, no lessons yet, drift mirror, local cache fallthrough, offline-first read, repository remote fallback]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Supabase — read-through cache mirror

## What this skill does

Fixes ADR-027: a repository method (`listLessonsForUnit`) reads only the local
Drift mirror and returns `[]` when the mirror is empty — it never fetches from
Supabase on a miss and never backfills the mirror. A fresh install (empty
mirror) shows "no lessons yet" even though the server has data.

## Why it ships green

The fake repository in unit/widget tests stubs `listLessonsForUnit` to return
seeded data, so the missing cache→remote fallthrough is faked away. Coverage
is green; the real read path was never exercised.

## The pattern (offline-first read-through)

```
read(key):
  local = mirror.get(key)
  if local is non-empty: return local        # fast path
  remote = supabase.from(table).select()...  # cache miss → go remote
  mirror.upsert(remote)                       # backfill so next read is local
  return remote
```

Plus realtime/refresh to keep the mirror fresh. The bug is omitting the middle
two lines. Stale-while-revalidate is fine; **miss-returns-empty is not**.

## The rule

A domain repository method backed by a local mirror MUST have a non-mocked
integration test (real local Supabase + empty mirror) proving a cache miss
falls through to remote and backfills. If the fake repo fakes that path, mark
the call site `// CONTRACT-UNTESTED` and run it for real at INTEGRATION_SMOKE
(see `test-writer` Iron Rule #8/#9, `supabase-rls-client-contract`).

## Code patterns
| Need | File |
|---|---|
| Read-through repository impl | [snippets/lesson_repository_impl.dart](snippets/lesson_repository_impl.dart) |
| Non-mocked read-through integration test | [snippets/read_through_integration_test.dart](snippets/read_through_integration_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-027)
- Last verified: 2026-05-16

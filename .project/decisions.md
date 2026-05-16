---
auto_approve: false                    # true to bypass approval gates (except Release); see CLAUDE.md §8.1
auto_approve_set_by: null              # "user" | "agent" | "ci" — who flipped it
auto_approve_reason: null              # one-line reason
auto_approve_set_at: null              # ISO date
---

# Project-Wide Decisions Log (ADR)

> Project-wide architectural / process decisions that don't fit in `architecture.md` (which is feature/code-level). Examples: when CLAUDE.md rules were intentionally overridden, when a new agent / skill was promoted to standard, when scope was expanded.

Format: append-only ADR entries, newest at bottom.

---

## ADR-001 — Initial template adoption
**Date:** {YYYY-MM-DD}
**Status:** Accepted
**Decision:** Adopt the 23-agent Flutter mobile app development template as defined in `CLAUDE.md`.
**Reason:** Solo dev / small team workflow benefits from full pipeline orchestration with quality gates.
**Consequences:** Project follows the state machine, mandatory reviews per phase, skill extraction discipline.

---

## ADR-002 — Mandatory runtime verification gate (`BUILD_VERIFIED`)
**Date:** 2026-05-16
**Status:** Accepted
**Decision:** Add a new, never-skippable pipeline state **`BUILD_VERIFIED`** between `COMPLIANCE_CHECK` and `QA_SMOKE_TEST`. A phase cannot reach `USER_APPROVAL` unless its branch produces a build artifact for each flavor AND boots to first screen on a device/emulator with zero uncaught exceptions, AND every backend-touching feature has at least one non-mocked integration test run against a real local backend. Evidence is recorded in a new required phase-file section `## Build Verification`.

Concrete changes:
- `CLAUDE.md` §3 (state machine + transition table + gate definition), §6 (new required body section), §9 (Runtime quality bar + CI-green rule).
- `.claude/hooks/validate-phase-state.py` + its tests (new state, owner mapping, required section).
- `orchestrator.md` (diagram, dispatch table, never-skippable gate rule incl. autonomous mode, valid-values count 15→16).
- `app-bootstrap.md` (mandatory `flutter build` + on-emulator boot test + local-backend boot before handoff; CI skeleton now includes runtime jobs).
- `task-planner.md` (phase-01 runtime acceptance criteria; walking-skeleton-invariant must be a checkable AC; phase template gains `## Build Verification`).
- `test-writer.md` (Iron Rule: non-mocked integration test mandatory per backend-touching feature; report line vs integration coverage separately).
- `security-reviewer.md` + `db-migration.md` (server-side restriction that breaks a client path ⇒ owned BLOCKER + compensating RPC + non-mocked test in the SAME phase; unowned "RPC TODO" is BLOCK, not a deferral).
- New canonical `.github/workflows/ci.yml` with `analyze-test`, `build-and-boot` (Android), `build-ios`, `backend-integration` (local Supabase) jobs.
- Two pre-seeded skills: `flutter-build-boot-gate`, `supabase-rls-client-contract` (full skill dirs) + `skills/INDEX.md` updated (13→15).

**Reason:** A project produced by this pipeline shipped six consecutive launch-blockers (Android compile defects, a Riverpod scoped-provider first-frame boot abort, client↔backend contract drift where an RLS/column-guard trigger blocked a write whose compensating SECURITY DEFINER RPC was left as an unowned TODO, and missing backend scaffold). Single meta root cause: every quality gate was static or mocked — nothing ever ran `flutter build`, booted the app, or tested against a real backend. High static quality (analyze clean, ~54% coverage) produced false confidence because no test touched real RLS/triggers/schema.

**Consequences:**
- Every phase now pays a build + boot (and, when applicable, local-backend) cost before review/QA — slower per phase, but the entire compile-time/app-boot/real-backend defect class becomes structurally visible instead of shipping.
- The phase-state hook will reject any phase file lacking `## Build Verification`; `task-planner` emits it by default and existing/in-flight phase files must add it.
- Autonomous mode (`auto_approve: true`) bypasses human-approval gates only; it does NOT relax `BUILD_VERIFIED`. Release remains human-only.
- Pre-seeded skills are added directly (not via `skill-extractor`), consistent with the original 13-skill seeding, because they encode a cross-project post-mortem rather than a single-project extraction.

---

(Future ADRs added here.)

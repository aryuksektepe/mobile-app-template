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
**Status:** Superseded by ADR-003 (gate renamed `INTEGRATION_SMOKE`, repositioned before `COMPLIANCE_CHECK`, exit criteria strengthened). Kept for history; the principle stands, the name/position/criteria evolved.
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

## ADR-003 — Runtime gate consolidated, renamed `INTEGRATION_SMOKE`, repositioned + strengthened
**Date:** 2026-05-16
**Status:** Accepted (supersedes ADR-002)
**Decision:** Evolve the ADR-002 runtime gate into a single authoritative state **`INTEGRATION_SMOKE`**, placed **`PERFORMANCE_REVIEW → INTEGRATION_SMOKE → COMPLIANCE_CHECK`** (before compliance/QA, so those gates operate on a verified-running app). The phase-file section is renamed `## Build Verification` → `## Integration Smoke`. Exit criteria, all requiring execution evidence in the phase file: (1) real `flutter build <flavor>` exit 0 per flavor; (2) emulator/device boot with a `BOOT_OK` marker + `splash → first real screen`, no uncaught error, no rebuild/dispose storm; (3) ≥1 NON-MOCKED end-to-end flow per PRD-FR against a real backend with HTTP trace + DB row evidence; (4) every new Edge fn/RPC/migration applied to a real local stack with ≥1 authenticated 2xx call; (5) every new screen reached via an executed concrete tap-path. Never skippable, not even in autonomous mode.

Why a single gate instead of two: keeping ADR-002's `BUILD_VERIFIED` (after compliance) AND adding the brief's `INTEGRATION_SMOKE` (before compliance) would be two redundant runtime gates. Best practice is one authoritative gate; placing it before `COMPLIANCE_CHECK` matches the empirical lesson that compliance/QA must run on a real running app.

Concrete changes (on top of ADR-002):
- `CLAUDE.md` §3 (rename + reposition + 5-criteria definition), §6 (`## Integration Smoke`), §9 (runtime bar incl. contract-parity + reachability; new "CI economy & determinism": batch pushes, deterministic/excluded generated artifacts).
- `validate-phase-state.py` + tests: `BUILD_VERIFIED`→`INTEGRATION_SMOKE`, owner map, `## Integration Smoke` required section, repositioned in VALID_STATUSES.
- `orchestrator.md`: diagram + dispatch table repositioned (perf→INTEGRATION_SMOKE→compliance), gate rule renamed/strengthened.
- `compliance.md` (routing reverted to QA_SMOKE_TEST; now reads `## Integration Smoke` evidence) + `performance-reviewer.md` (advances to INTEGRATION_SMOKE).
- `app-bootstrap.md`: installs the persistent `tool/smoke_boot.sh` + `integration_test/boot_smoke_test.dart` harness with `BOOT_OK` marker; reused every phase.
- `task-planner.md`: Iron Rule #10 reachability; `AC-REACH` per screen-containing FR; `## Integration Smoke` phase template. `architect.md`: navigation skeleton is an explicit artifact ("Reached by" column), pure-redirect rule.
- `test-writer.md`: Iron Rule #9 contract parity — `functions.invoke`/REST method+body assertion, `async*` yield contract, repo read-through, keepAlive rebuild-storm; `any(named:'body')` boundary mocks forbidden.
- `code-reviewer.md`: auto-HIGH triggers — disposed-flag latch, provider mutation in redirect/build, keepAlive↔autoDispose watch, invoke↔fn contract mismatch, `async*` no-yield.
- `db-migration.md`: Stage 5.5 real-stack apply gate + per-Edge-fn authenticated call + LOCAL-STACK-RUNBOOK reference; "written but not applied" = BLOCK.
- `.github/workflows/ci.yml`: `integration-smoke` emulator-matrix job (merge-to-main), generated-clean diff gate with non-deterministic excludes, CI-economy header.
- Skills 15→24: `flutter-build-boot-gate` extended (BOOT_OK harness); 9 new full-dir skills — `riverpod-2x-disposed-flag-guard`, `riverpod-autodispose-chain-churn`, `riverpod-fetch-then-subscribe-yield`, `supabase-read-through-cache-mirror`, `supabase-progress-aggregation-trigger`, `supabase-local-verify-jwt-es256-hs256`, `supabase-functions-client-contract-parity`, `gorouter-statefulshell-deeplink`, `regen-clean-after-diagnostics`; `INDEX.md` + new "Riverpod & Lifecycle" section.

**Reason:** A second project run (Mimirva launch-smoke) marked all 12 phases `DONE` with 608/608 green tests, clean `analyze --fatal-infos`, all reviews PASS — then hit 16 consecutive launch blockers (ADR-020..035 in that project) of three classes: (A) Riverpod/stream lifecycle, (B) client↔backend contract drift where mocks encoded the bug, (C) integration/accessibility gaps (a screen/fn exists but nothing reaches/calls it). Same meta root cause as ADR-002, broader: nothing built, booted, or ran against a real backend; mocks verified nothing; reachability was assumed. The fix generalizes ADR-002 and adds contract-parity + reachability + real-stack-apply + the empirical skill set.

**Consequences:**
- One coherent runtime gate; compliance + QA now always run on an app proven to build/boot/talk-to-backend. Slightly earlier in the pipeline, more cost per phase, far less shipped-broken risk.
- Hook now requires `## Integration Smoke` (not `## Build Verification`); any in-flight phase files must rename the section. `task-planner` emits it by default.
- `any(named:'body')` / unconstrained boundary mocks are now a test-writer BLOCK and a code-reviewer auto-HIGH.
- CI gains an emulator-matrix job on merge-to-main; teams must keep deterministic codegen and batch pushes (Actions-minute discipline) — itself a skill (`regen-clean-after-diagnostics`).
- The 9 new skills are pre-seeded directly (not via `skill-extractor`), consistent with prior seeding, because they encode a cross-project post-mortem.

---

(Future ADRs added here.)

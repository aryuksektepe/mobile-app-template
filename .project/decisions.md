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

## ADR-004 — Responsive + dynamic-type as a wired pipeline concern
**Date:** 2026-05-17
**Status:** Accepted
**Decision:** Add the `responsive-adaptive-layout` skill and wire enforcement into existing gates (no new agent). Best practice (Flutter docs adaptive/responsive + Material 3 window size classes + `MediaQuery.withClampedTextScaling`): layout from `MediaQuery.sizeOf`/`LayoutBuilder` against M3 window size classes (Compact <600 / Medium 600–840 / Expanded >840); never `OrientationBuilder`/`isTablet()`/fixed sizes for layout; OS text scaling respected and root-clamped (`1.0–1.3` default), never disabled; verified by a size×textScale golden matrix ({320×640,390×844,768×1024} × {1.0,1.3,2.0}) asserting no overflow.

Concrete changes:
- New full-dir skill `responsive-adaptive-layout` (SKILL + implementation + pitfalls + checklist + 4 snippets); `INDEX.md` 24→25, section renamed "Forms, UI & Layout".
- `ux-designer.md`: Iron Rule #5 strengthened; design-system.md gains §22 (breakpoint contract + text-scale budget); layouts.md requires a per-screen Responsive field (structure now "22 Sections").
- `architect.md` §14: M3 window size classes + root text-scale clamp are explicit mandatory decisions; single `core/responsive/breakpoints.dart` authority.
- `app-bootstrap.md`: scaffolds the root clamp in `app.dart`, `core/responsive/breakpoints.dart`, and `test/golden/responsive_matrix_test.dart`; also reconciled stale `app_boot_test.dart` → `boot_smoke_test.dart`.
- `code-reviewer.md`: responsive/text-scale anti-patterns are MEDIUM triggers (HIGH if scaling disabled or on critical screen).
- `test-writer.md`: Iron Rule #10 — size×textScale matrix mandatory for every new screen/DS component; missing = BLOCK.
- `qa-test-guide.md`: `device_variance`/`accessibility` categories now require a real-device size×OS-font matrix; mandatory when UI changes.
- `CLAUDE.md` §9: new "Responsive & accessible text" bar + an `INTEGRATION_SMOKE` extreme-cell (smallest device + max text scale, zero overflow) evidence line.

**Reason:** Reported empirical gap: apps break (RenderFlex overflow / clipped UI) on different phone sizes and when the OS font/display size is increased. Same meta-cause as ADR-002/003 — a single fixed-size, textScale-1.0 widget/golden test is green while the running app on a small phone or at "Largest" font shatters. The fix is the reusable how-to (skill) PLUS enforcement at design, review, test, QA, and the runtime gate.

**Consequences:**
- Every UI phase now carries a size×textScale matrix test and a real-device matrix QA scenario; design-system.md must declare the breakpoint + text-scale budget up front.
- Text scaling can never be disabled to "fix" overflow — it must be clamped and the design proven at the clamp max.
- Pre-seeded skill (not via skill-extractor), consistent with prior seeding.

---

## ADR-005 — Behavioral discipline + plugin packaging (Karpathy-derived)
**Date:** 2026-05-17
**Status:** Accepted
**Decision:** Adopt, adapted to this pipeline, the four LLM-coding-discipline principles from `multica-ai/andrej-karpathy-skills` (MIT) and the Claude Code plugin-packaging pattern:
- `CLAUDE.md` §14 **Behavioral Discipline** (Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution) — binding on every agent every turn; cross-references §3/§8/§9 instead of duplicating them. Subagents read CLAUDE.md (not the harness prompt), so this closes a real gap.
- `code-reviewer.md`: MEDIUM trigger group for behavioral violations (drive-by refactor, style drift, speculative abstraction/bloat, deleting pre-existing dead code unasked, task with no verifiable criterion).
- `coder.md`: Iron Rule #8 = simplicity/surgical/goal-driven (Turkish rule → #9).
- `orchestrator.md`: Task dispatch MUST carry the step's verifiable success criterion; no vague "improve/fix X" directives; points agents to §14.
- New `.claude-plugin/plugin.json` + `marketplace.json`: packages the pipeline (24 agents, 7 commands, hooks, 25 skills) as an installable Claude Code plugin/marketplace — directly serves CLAUDE.md §1 "reusable work so future projects benefit".

NOT adopted (Simplicity First applied to ourselves): no duplicate 26th skill restating the principles (would mirror the system prompt + §14), and `EXAMPLES.md`/Cursor/zh variants not imported (generic/Python; our per-skill `pitfalls.md` already carry Flutter-specific examples). The reusable diff-discipline was abstracted into the code-reviewer rubric instead.

**Reason:** Runtime gates (ADR-002/003/004) catch "never ran it / contract drift / breaks on other sizes". They do not catch "assumed wrong silently / overcomplicated / drive-by refactor / no success criterion" — the Karpathy failure class. These are behavioral, cross-agent, and best encoded in the constitution every dispatched agent reads. Plugin packaging makes the whole pipeline portable across projects.

**Consequences:**
- code-reviewer now bounces overcomplication/drive-by edits; expect tighter, request-traceable diffs.
- orchestrator dispatches become goal-explicit (per-task echo of the INTEGRATION_SMOKE evidence philosophy).
- The repo is now installable as a Claude Code plugin; keep `plugin.json` `skills` list in sync when skills are added/removed (skill-extractor / INDEX updates).
- Attribution: principles derived from Andrej Karpathy's observations via `multica-ai/andrej-karpathy-skills` (MIT).

---

## ADR-006 — Deep-link/StatefulShell/cold-start lessons from a real production run (Mimirva)
**Date:** 2026-05-18
**Status:** Accepted
**Decision:** Fold the lessons from a real production deep-link/push campaign (Mimirva — 6-round bug-loop, ~hours each) into the template, generalized + project-agnostic:
- **Enriched** the existing `gorouter-statefulshell-deeplink` skill instead of creating the briefed near-duplicate `gorouter-statefulshell-deeplink-goBranch` (user-approved; Simplicity First + ADR-005). Added: third rule (process-global shell holder + `goBranch(idx, initialLocation: idx==currentIndex)` + bounded cold-start handshake + consume-outside-redirect), new snippet `shell_branch_controller.dart`, pitfalls P6–P10, generalized bug-catalog table, checklist items, fixed the broken pseudo-line in `shell_deeplink.dart`. `recurrence_count` → 1, `last_verified` → 2026-05-18. INDEX count stays 25.
- **`deeplinks-go-router`** pitfalls #17–#21: custom-scheme `-10814` / `CFBundleURLTypes`, `MaterialApp(home:)`+nested-Router black screen, `app_links` `#if DEBUG` cold-start sim trap (Flutter #149214), goBranch cross-ref, `!identical` vs value-`!=` guard. `last_verified` bumped.
- **`notifications-fcm`** pitfalls #15–#16: notification-tap → non-Home tab needs the shell pattern; push-route allowlist must run BEFORE `setPath`. `last_verified` bumped.
- **`CLAUDE.md` §13** new "Debugging discipline (when a bug fights back)" block: research-before-fix + instrument-don't-speculate + deterministic-test-over-device (incl. "mocked StatefulShellRoute nav assertion is false-green") stated in full; trust-but-verify + written≠applied cross-referenced to §9/§14/orchestrator instead of duplicated (user-approved).

NOT adopted (Simplicity First): no separate `-goBranch` skill (would split discovery with overlapping triggers); the 5 disciplines were not restated verbatim where §9/§14/orchestrator already bind them — only the genuinely-new ones are stated fully, the rest cross-referenced.

**Reason:** This failure class (deep-link/push/StatefulShell/cold-start) is high-cost (hours per occurrence) and recurs across projects. Encoding it in skill pitfalls + a debugging-discipline block means the next project's coder catches it at skill-discovery or resolves it in minutes.

**Consequences:**
- Coders wiring bottom-nav deep links/push now get the production-hardened shell-holder + handshake pattern verbatim.
- §13 debugging discipline is binding on every agent in a bug-loop (research/instrument before speculating; deterministic test before device loop).
- Nothing pushed to GitHub (standing user instruction: monthly limit; bulk push next month). Local working tree only.

---

(Future ADRs added here.)

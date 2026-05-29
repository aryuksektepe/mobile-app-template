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

## ADR-007 — Token optimization: modular architecture + phase LIVE/ARCHIVE split + model tier routing
**Date:** 2026-05-26
**Status:** Accepted (auto-approved per user: "optimizasyonu best practice ile uygula ve kalıcı hale getir")

**Decision:** A user-owned project consuming this pipeline was burning excessive tokens — a third-party analysis attributed the dominant cost to repetitive re-reads of monolithic `architecture.md` (~132 KB), bloated late-phase files (412 KB observed), and uniform Opus/Sonnet routing of agents whose tasks were mechanical. After re-grounding the analysis in this template's actual subagent architecture (each `Task()` call is a separate context window — "merge all reviews into one conversation thread" does NOT apply), apply three structural optimizations, refuse a fourth that violates the constitution:

1. **#3 Model tier routing (applied — risk-free, immediate $ savings).** Frontmatter + self-description updated together for consistency:
   - `orchestrator` opus → **sonnet** (highest-frequency agent; routing is mechanical; CAVEAT noted in agent text — user may pin back to opus if state-machine drift observed).
   - `compliance` opus → **sonnet** (checklist-driven mandatory-per-phase; aggressive haiku option rejected for KVKK/GDPR nuance; pin-back path documented).
   - `feature-chronicler` sonnet → **haiku** (template-driven writing).
   - `localization` sonnet → **haiku** (mechanical ARB validation).
   - **Deviation from the user-approved plan: `skill-extractor` stays on opus** (low frequency, but a wrong extraction permanently pollutes the skill index every future coder reads — high downside / low savings; transparent reversal of the original draft).

2. **#1 Phase LIVE+ARCHIVE split (applied — biggest token win on heavy phases).** A phase is now two files:
   - LIVE `phase-XX-{slug}.md`: frontmatter + Goal + Acceptance Criteria + Tasks + Open Questions + Skipped Steps + **Latest Handoff** + **Evidence & History (archived) pointers** + bounded review verdict blocks. Read by default by every agent.
   - ARCHIVE `phase-XX-{slug}-archive.md`: Decisions Log + Integration Smoke evidence + Smoke Test Log + full Handoff Notes history. Opened ONLY by the agent producing the evidence, the orchestrator/qa-test-guide at evidence gates, or skill-extractor/audits.
   - CLAUDE.md §5 (directory), §6 (body sections — rewritten with the split + binding read/write rule), §11 (LIVE is the default for "current phase file"), §12 (handoff = full to archive + latest pointer in live) updated.
   - `orchestrator.md` §2 (reading order), dispatch table (LIVE+ARCHIVE note), INTEGRATION_SMOKE gate cell (evidence is in archive) updated.
   - `task-planner.md` template now scaffolds both files (§B LIVE + §B2 ARCHIVE). **Additive only** — existing LIVE sections were NOT deleted (per user rejection of the destructive surgical edit); the new live sections (Latest Handoff + Evidence & History) were added and the archive template introduced. §6's binding read/write rule resolves any ambiguity in agents' favor of the archive for evidence.
   - **Hook updated.** `.claude/hooks/validate-phase-state.py`: `REQUIRED_BODY_SECTIONS` split into `REQUIRED_LIVE_SECTIONS` (Goal/AC/Tasks/Skipped/Open Q/Latest Handoff/Evidence & History) + `REQUIRED_ARCHIVE_SECTIONS` (Decisions Log/Integration Smoke/Smoke Test Log/Handoff Notes); new `validate_archive()` function; main loop skips `*-archive.md` from state-file validation and validates archive sections only when the archive exists. Test suite updated (`_archive()` helper, repurposed missing-section tests, added archive valid/missing tests). All 36 tests green.

3. **#2 Modular architecture (applied — second-biggest token win, broadest blast radius).** `.project/architecture.md` becomes a lean INDEX (frontmatter incl. `triggers_api_design` + Tech Stack summary + Contents TOC + Open Questions + PRD Revisions + ADR Log + Contracts appendix). The 23 canonical content sections distribute across six slice files under `.project/arch/`:
   - `01-foundation.md` (§1 style, §2 stack, §3 layers, §4 folders)
   - `02-implementation.md` (§5 state, §6 nav, §7 data, §8 networking, §10 errors, §13 codegen)
   - `03-data-and-storage.md` (§9 Drift)
   - `04-security-and-secrets.md` (§11 envs/flavors, §12 secrets)
   - `05-design-and-ux.md` (§14 theming, §15 assets/fonts)
   - `06-quality-and-ops.md` (§16 logging, §17 testing, §18 lint, §19 CI, §20 perf)
   - `architect.md` updated: intro + §2 reading order + §3 workflow + §4 output + §5 doc-completeness rule + new §5a Output File Layout map. Append-mode now edits the specific slice + bumps the index ADR Log.
   - CLAUDE.md §11 carries the binding **slice-ownership table** (consumer-side single source of truth) and a "Write authority" line: ONLY `architect` writes `architecture.md` + `arch/*`; every other agent is read-only on them (globally extends the existing "do not edit architecture.md" prohibition to the full `arch/` tree without 23 per-agent edits).
   - **Eight consumer agents' reading-order lines repointed** to slice files instead of stale `architecture.md §X` references (coder, security-reviewer, performance-reviewer, db-migration, test-writer, code-reviewer, app-bootstrap, ux-designer), plus two misc references (`coder.md` §4 folder check → `arch/01-foundation.md §4`; `test-writer.md` Alchemist check → `arch/06-quality-and-ops.md §17`). One orchestrator dispatch row updated (BOOTSTRAPPING folder-layout check now points to `arch/01-foundation.md` with on-demand-load note).

**NOT adopted (rejected on constitution grounds):**
- **#4 "Merge security + performance + compliance into one `quality-gate` agent"** — would cut their context-reads ~3× but directly violates CLAUDE.md §1 "no step skipped silently" and §3/§9 "security + performance + compliance reviews are MANDATORY per phase" plus loses the per-domain checklist/severity rubric each reviewer carries. The same token win is achieved by #1+#2 without breaking the constitution.
- **Prompt-caching-as-strategy** — the third-party analysis ranked "wrap all reviewers in one conversation thread to keep cache warm" as the #1 lever; this is mis-described for this template. Each subagent is a separate `Task()` call with its own context window; there is no thread to share. Claude Code's automatic 5-minute TTL cache helps within back-to-back invocations but isn't a directly-controllable lever here. The mechanism reduces to "read less per agent" — which is exactly what #1+#2 do.

**Reason:** Per token model (assumptions stated in the planning response): ~12 agent invocations/phase × ~90 K mandatory-read tokens/agent (CLAUDE.md + architecture.md + phase file) ≈ ~1.08 M input tokens/phase from re-reads alone. #1+#2 cut this by ~60–75 % (architecture.md 132 KB → ~5 KB index + ~10–20 KB per loaded slice; late phase 50–103 K → ~2–8 K LIVE). #3 multiplies the saving on light agents by ~5–15× on $/token.

**Consequences:**
- **Sequenced rollout the user can observe** — #3 is risk-free and effective immediately on the next agent invocation; #1+#2 take effect when `task-planner` and `architect` produce new outputs (next phase / next ADR).
- **Modular architecture changes the architect contract** — append-mode now edits the specific slice + bumps the index ADR Log, never duplicates content across slices. Slice files are append-only at the section level the same way the monolith was.
- **One downside accepted by user instruction**: in the LIVE phase template the existing 4 archive-bound section headings (`## Decisions Log`, `## Integration Smoke`, `## Smoke Test Log`, `## Handoff Notes`) remain present as empty stubs because the destructive surgical removal was rejected mid-edit. The §6 binding read/write rule + orchestrator's LIVE+ARCHIVE note resolve writes to the archive globally, so this is cosmetic, not functional. A follow-up phase may clean up the stubs once the convention has been observed in practice.
- **Monitor `orchestrator` on sonnet.** This is the agent the whole pipeline's integrity rides on (state-machine enforcement, trust-but-verify re-checks). If transitions ever drift, pin it back to opus via frontmatter (single-line change, documented in the agent file).
- **Monitor `compliance` on sonnet** on the first high-stakes (fintech/health/children's data) project that runs through the pipeline; same pin-back path.
- **GitHub push deferred (standing user instruction).** Local working tree only — monthly limit exhausted; bulk push next month when the limit resets. Future push must include this ADR's net commit so the optimization lands atomically with its documentation.

---

## ADR-008 — 17 new skills filling store/legal + MASVS + production-recurrence gaps
**Date:** 2026-05-26
**Status:** Accepted (auto-approved per user: "eksik gördüğün skilleri ekle ancak token optimizasyonunu maliyeti gözet, pipeline akışını koru")

**Decision:** Expand the skill library from 25 → 42 (+17) to close the gaps surfaced by a structured audit against (a) CLAUDE.md §9 quality bar items that had no skill, (b) Apple/Play store mandates with no walkthrough, (c) production-recurring pitfalls observed across the template's stack. All 17 added as `validation_status: pre-seeded` (research-based, not yet battle-tested in a shipped real-project run) so the standard ADAPT-not-VERBATIM rule applies until promoted.

**New skills, grouped by tier:**

**Tier 1 — Store/legal critical (4):**
- `ios-att-prompt` — App Tracking Transparency flow with pre-prompt + ATT timing + IDFA gating + Consent Mode v2 coordination. Apple Guideline 5.1.2(i).
- `ios-privacy-manifest` — PrivacyInfo.xcprivacy (Apple mandate since May 1 2024): data types + tracking domains + Required Reason APIs + third-party SDK manifest+signature audit. Closes ITMS-91056/91061/91065 reject paths.
- `account-deletion-cross-cutting` — 9-step orchestrated deletion across auth + RC + FCM + analytics + Crashlytics + Sentry + secure storage + Drift, with Apple SIWA token revocation REST + RC user DELETE REST + supabase soft-delete + 30-day hard-purge cron. Apple 5.1.1(v) + Play "Data deletion" mandate.
- `ios-android-hardening` — release build hardening: `--obfuscate --split-debug-info`, R8/ProGuard keep rules for the full template stack (Firebase/Drift/freezed/RC/Sentry/etc.), iOS Strip Style + dSYM, `verify-release-shrinking.sh` smoke gate.

**Tier 2 — MASVS / production baseline (3):**
- `certificate-pinning-dio` — public-key SPKI pinning via Dio with primary+backup pin, debug bypass, fail-closed, rotation runbook. MASVS-NETWORK-1.
- `force-update-gate` — Remote Config minimum_version + recommended_version flow, blocking modal, store deep link, semver compare, staged rollout, Huawei/Amazon HTTPS fallback.
- `splash-and-launcher-icon` — flutter_native_splash 2.x + flutter_launcher_icons 0.14+: Android 12+ splash API, iOS launch storyboard, dark variants, RTL, adaptive icons + Android 13 themed monochrome.

**Tier 3 — Production-recurrence high (6):**
- `auth-firebase-phone-otp` — phone OTP with reCAPTCHA fallback (iOS), Play Integrity (Android), test phone numbers, SMS auto-retrieval, country picker, account linking. TR/EM markets staple.
- `dio-interceptor-stack` — production interceptor chain: auth header, 401 refresh-token mutex (no token storm), exponential retry, PII-scrubbed logging, cancel tokens, base URL per flavor.
- `drift-schema-migrations` — append-only migration discipline, schema dump per version + generated upgrade tests, FK PRAGMA, type converters (Enum/DateTime/JSON), transaction pattern.
- `freezed-json-serializable` — freezed 3.x sealed unions + json_serializable patterns: @JsonKey snake_case, custom DateTime/Enum converters, @Default null-safe, build_runner workflow, codegen drift catching (pairs with `regen-clean-after-diagnostics`).
- `permission-handler-centralized` — single PermissionService for camera/photos/location/contacts/mic/notifications: soft-ask, just-in-time, settings deep link, iOS Info.plist usage strings, Android 13/14 specifics (POST_NOTIFICATIONS, partial photo access).
- `connectivity-offline-ux` — `connectivity_plus` 6.x stream + global offline banner + queued ops on reconnect, with the critical "interface vs internet reachability" distinction (captive portal trap).

**Tier 4 — Medium-recurrence (4):**
- `media-picker-upload` — image_picker → crop → compress → Firebase/Supabase Storage upload, with EXIF orientation fix, MIME guard, size pre-check, Android 14 partial-photo handling.
- `background-tasks-workmanager` — workmanager 0.6+ for iOS BGAppRefreshTask/BGProcessingTask + Android WorkManager, with explicit "NOT real-time" framing and OEM-battery-kill reality (Xiaomi/Huawei).
- `webview-wrapper` — webview_flutter 4.x with URL allowlist, JS bridge, back-handling, mixed-content guard, and the explicit NO-OAuth-in-webview rule (Apple 4.5.4 + Google blocked).
- `in-app-review-prompt` — in_app_review 2.x with happy-path gating (≥3 positive moments + ≥7 day install age + ≥90 day cooldown), fallback to store listing when API throttled.

**Cross-cutting changes:**
- `.claude/skills/INDEX.md` reorganized: added 5 new sections (Compliance & Security, Models & Codegen, Updates & Lifecycle, Permissions & Platform, Background & Media, WebView & Engagement) and bumped Total to 42. Dependency graph updated. Recommended Phase 01 / Phase 02 / per-feature ordering refreshed to include new foundations (freezed-json-serializable, dio-interceptor-stack, drift-schema-migrations) ahead of feature work.
- No agent definitions modified; no CLAUDE.md edits; no hook changes — additive only, pipeline flow preserved per user instruction ("pipeline akışını koru akışımız bozulmasın").

**Out of scope (rejected with rationale):**
- Charts (fl_chart/syncfusion), PDF gen/view, search (Algolia/Typesense), maps, MFA/TOTP, advanced camera, Stripe non-IAP — all project-dependent; let skill-extractor pull from real phase use when a project actually needs them.

**Reason:** A third-party audit + my own systematic gap analysis identified 17 reusable patterns that (a) every Flutter production app needs, (b) have non-obvious pitfalls or store-policy gotchas, (c) recur across projects. The marginal cost of writing them once (research + code + pitfalls + checklist) is justified by token-saving + consistency every time a coder agent reads INDEX.md and finds a verbatim-applicable skill instead of re-implementing. Specifically validated against CLAUDE.md §9 quality bar items previously missing skill coverage (ATT, Privacy Manifest, certificate pinning, ProGuard/R8, account deletion).

**Consequences:**
- **42 skills total now in the index** (up from 25). Coder agent's INDEX read cost rises (~6 KB → ~12 KB ≈ ~3K extra tokens per coder invocation), but discovery hits are far more likely → fewer "implement from scratch" loops. Net token cost is expected favorable after ≥1 hit per phase.
- **All 17 are `pre-seeded`** — ADAPT not VERBATIM. First real project that uses them must append findings to each skill's `pitfalls.md` and bump `last_verified`. Promotion to `battle-tested` after ≥2 successful real-project deployments (per the INDEX promotion rule).
- **Internal cross-references added** — e.g. `account-deletion-cross-cutting` depends on `auth-firebase-email` + 5 others; `dio-interceptor-stack` pairs with `certificate-pinning-dio`. The dependency graph in INDEX.md is the authoritative source.
- **No breaking change to pipeline** — every existing skill/agent/hook untouched. Additive only.
- **GitHub push deferred (standing user instruction).** Local working tree only — monthly limit exhausted; bulk push next month when the limit resets. Future push must include ADR-007 + ADR-008 net commits.
- **Skill-extractor's job is preserved** — these are seeded gaps the user requested; future organic skills still flow through skill-extractor as usual on `SKILL_EXTRACTED` state.

---

## ADR-009 — Subo v1.2 pipeline knowledge integration (3 new skills + 4 enhanced + 2 agent updates)
**Date:** 2026-05-27
**Status:** Accepted

**Decision:** Bir prod Flutter+Supabase uygulamasının (Subo v1.2 release) `+pipeline-knowledge/` klasöründeki 6 öğrenme dosyasını template'e entegre et — yeni skill'ler, mevcut skill pitfalls'larına ekleme, ve iki agent (qa-test-guide + crash-monitor) güncellemesi olarak.

**Concrete changes:**

*Three new skills (additive — `pre-seeded`):*
- `ios-26-debug-release-only-physical` (DevOps & CI/CD) — iOS 18.4+ Apple `mprotect()` Dart JIT'i reddediyor, fiziksel cihazda DEBUG cold-start crash; release build + `xcrun devicectl install` runbook'u. Pipeline davranışını etkiler: `qa-test-guide` ve INTEGRATION_SMOKE bu cihaz sınıfında release build talimatı verir.
- `app-lock-pin-biometric` (Compliance & Security) — PIN + biyometrik in-app lock; PBKDF2-HMAC-SHA256 120k iter (OWASP 2023), constant-time compare, exponential lockout, **kritik lifecycle ayrımı** `paused→resumed` (gerçek bg) vs `inactive→resumed` (Face ID dialog / control center / notif drawer — re-lock TETİKLEMEZ). Subo'da biyometrik döngüsü bug'ı bu mixin ile çözüldü.
- `intl-currency-locale-resolve` (Forms, UI & Layout) — Dart `intl` kısa locale fallback bug'ı (`'tr'` → `'TRY 79.99'`; doğru `'tr_TR'` → `'₺79,99'`); server-client format parity. Çift bildirim format mismatch'inin tipik nedeni.

*Four existing skills enhanced (pitfalls.md):*
- `notifications-fcm` 14→22 entries: apns-collapse-id + Android `notification.tag` ile OS-level dedup (hibrit local+FCM çift bildirim fix'i), iOS `UNUserNotificationCenter willPresent` delegate (foreground'da banner için ZORUNLU), `flutter_local_notifications.initialize()`'ı background isolate'tan çağırma deadlock'u (#1730), `flutter_timezone` init zorunluluğu, geçmiş `targetDt` silent skip guard'ı. İki yeni snippet eklendi (`AppDelegate.willPresent.snippet.swift`, `edge-fn-dedup-buildFcmMessage.ts`).
- `auth-apple-signin` 18→22 entries: Apple Private Relay (`@privaterelay.appleid.com`) için `auth_email` + `display_name` + opsiyonel `contact_email` UX pattern'i (Spotify/Notion/Linear yaklaşımı), Apple `givenName`+`familyName` only-on-first-sign-in race condition mitigation, **Supabase** `signInWithIdToken` Apple nonce dance (Firebase ile aynı), relay-email bounce risk dokümantasyonu.
- `auth-google-signin` 17→20 entries: **Supabase** "Skip nonce checks" toggle'ı + cache nedeniyle force-refresh trick (OFF→Save→ON→Save→bekle), iOS `GIDClientID` + `GIDServerClientID` Info.plist zorunluluğu (eksikse `[GIDSignIn signInWithOptions:]` NSException crash), `accessToken` Supabase ile birlikte gönderme zorunluluğu.
- `flutter-build-boot-gate` + `ios-android-hardening`: iOS 26 release-only fiziksel cihaz pitfall'u (P7 / #11), Flutter 3.44 SPM auto-integration FlutterFire çakışması (P8 / #12), CocoaPods UTF-8 encoding fix (#13).

*Two agent updates:*
- `qa-test-guide.md` — Iron Rule #9 eklendi (iOS 18.4+ fiziksel cihaz → release build mandate); preamble template'inde `Build modu (BINDING)` bölümü zorunlu artık (debug/release tablosu + iOS 26 talimatı + skill referansı).
- `crash-monitor.md` — yeni §8.1 **iOS `.ips` Crash Log Retrieval (operator runbook)** eklendi: cihazdan `.ips` alma (Settings → Privacy → Analytics Data), macOS TCC sandbox workaround (Finder → /tmp), python3 ile parse + threading info, yaygın imza tanımları (EXC_BAD_ACCESS+VSyncClient = iOS 26 mprotect, vb.).

*INDEX.md:*
- 3 yeni satır eklendi, Total 42→45 pre-seeded güncellendi.
- Dependency graph genişletildi.

**Out of scope (kasıtlı — `+pipeline-knowledge/`'de var ama template'e dahil edilmedi):**
- Riverpod modal `Consumer` wrap pattern'i, `Timer.periodic` countdown ticker, day-overflow `DateTime` guard, SharedPreferences user-scoped key — yeterince genel Flutter pattern'leri, kendi skill'lerini hak etmiyorlar; ihtiyaç olduğu yerde mevcut skill'lerin pitfalls.md'sine eklenebilir (gelecekte organik).
- Git commit convention'ları, pre-commit hook'ları, dart-define-from-file workflow — proje-spesifik bootstrap, agent davranışını değiştirmez.

**Reason:** Subo v1.2 bir release döngüsü boyunca 9 bug + 3 büyük feature'da pattern'ler keşfetti. Üçü (iOS 26 JIT, hibrit notification dedup, Supabase Skip-nonce force-refresh) literatürde yok / yetersiz dokümante; gelecek projelerde aynı kayıpları yaşamamak için template'e ait olmaları lazım. Token disiplini: yeni skill'ler küçük (SKILL.md + pitfalls.md + sade snippet'ler), pitfalls eklemeleri tablo satırları olarak — INDEX read cost'u +~1KB ≈ ~250 token (kabul edilebilir).

**Consequences:**
- INDEX.md 45 skill (önceki 42'den). Coder agent read cost'u marjinal artar, discovery hit oranı yükselir.
- `qa-test-guide` artık iOS 26 fiziksel cihaz testlerinde release build talimatı emit eder (regression önler).
- `crash-monitor` operator'a `.ips` retrieval runbook'u verir (Crashlytics/Sentry'ye düşmeyen crash'ler için escape hatch).
- Hepsi `pre-seeded` — ADAPT not VERBATIM; ilk gerçek projede pitfalls.md güncellenir, `last_verified` bump'lanır, ≥2 başarılı kullanımdan sonra `battle-tested` promotion.
- `+pipeline-knowledge/` klasörü template'e gitmez (kullanıcının notları); template kendi `.claude/skills/` ve `.project/` yapısı üzerinden çalışır. Klasör silinebilir ya da `.gitignore`'a eklenebilir — kullanıcı tercihi.

---

## ADR-010 — Template hijyen + tutarlılık + mekanik guardrail temizliği

**Tarih:** 2026-05-29
**Karar veren:** user (template baştan-sona denetimi sonrası "hepsini uygula")
**Bağlam:** Template baştan sona denetlendi (agent/otomasyon katmanı + doküman/skill katmanı + internet best-practice karşılaştırması). Motor sağlam bulundu; biriken doküman driftı, sızmış geliştirme artefaktları ve "söz verilmiş ama diskte yok" parçalar düzeltildi.

**Yapılanlar (Dalga 1 — hijyen & tutarlılık):**
- Commit'li `__pycache__/*.pyc` `git rm --cached` ile düşürüldü; `.gitignore`'a `__pycache__/` + `*.py[cod]` eklendi (Python hook'lar var, ignore yoktu).
- `.project/MORNING_REPORT.md` + `TASKS_REPORT.md` silindi — bunlar template'i *inşa ederken* tutulan seans loglarıydı, ürünün parçası değil; her yeni projeye sızıyordu.
- `.claude-plugin/plugin.json` senkronlandı: 25→46 skill (diskle birebir parite), açıklamada "24 agent"→23, "25 skill"→46.
- README state diyagramına `INTEGRATION_SMOKE` eklendi (sistemin amiral gemisi gate'i README'de hiç yoktu) + kısa açıklama bloğu.
- `flutter_secure_storage` skill-arası versiyon çakışması çözüldü: `app-lock-pin-biometric` `^9.2.2`→`^10.1.0` (canonical `secure-storage-tokens` ile hizalı; kullanılan read/write/delete API'si 9→10 değişmedi). Verification notu dürüstçe "10.x cihaz re-verify pending" olarak güncellendi.
- Sızmış proje isimleri ("Mimirva", "Subo v1.2") shipped skill body'lerinde anonimleştirildi ("a production run / production Bug N"). `subosito/flutter-action` (gerçek GitHub Action) korundu. ADR başlıkları (ADR-006/009) tarihsel kayıt olarak bırakıldı.
- `_example-skill-template` çelişkisi giderildi: "Delete this directory..." talimatı kaldırıldı, "KEEP — skill-extractor referansı" ile değiştirildi (dizin INDEX'te zaten "koru" diyordu). INDEX "Total skills" satırı 46 olarak netleştirildi.
- `triggers` YAML stili standartlaştırıldı (`scoping-column` block-style → inline array; tüm skill'ler artık inline).

**Yapılanlar (Dalga 2 — mekanik zorlama):**
- **Yeni PreToolUse hook `guard-tool-use.py` (16 test, zero-dep)**: CLAUDE.md'nin prose-only prohibition'larını deterministik hale getirdi. `agent_type` payload alanını kullanarak: (1) `architect` dışındaki agent'ları `architecture.md`/`arch/*` yazımından, (2) read-only reviewer'ları (code/bug/security/performance/compliance) production code (`lib`/`test`/`integration_test`/`ios`/`android`) yazımından, (3) orchestrator'ı Bash'ten + production code yazımından mekanik olarak blokluyor. Main/insan seansı (agent_type yok) hiç kısıtlanmıyor. `settings.json`'a `PreToolUse` matcher `Write|Edit|MultiEdit|NotebookEdit|Bash` ile bağlandı. (Best-practice: "CLAUDE.md advisory'dir, hook deterministiktir".)
- CI dürüstlük düzeltmeleri (`ci.yml`): `backend-integration`'daki `curl ... || true` (asla kırmızı olamayan no-op) kaldırıldı, Edge Function existence-guard'ı ile değiştirildi (fn varsa gerçekten gate'ler, yoksa açıkça atlar). `integration-smoke` iOS dalı artık `xcrun simctl boot` ile **gerçekten** simulator boot ediyor (eskiden sadece `echo` + host'ta test); Android dalı emulator-runner'a taşındı.
- On-demand `.project/` dizinleri tutarlı hale getirildi: `arch/`, `api/`, `legal/`, `l10n-deltas/`, `perf-snapshots/`, `release-notes/` için `.gitkeep` (eskiden sadece `aso/` + `qa-runs/` vardı). `.project/README.md`'ye `arch/` satırı eklendi. CLAUDE.md §11'e "arch slice'ları yoksa atla, dead-path değil — architect post-approval üretir" guard notu eklendi.

**Yapılanlar (Dalga 3 — token & yapısal optimizasyon):**
- **CLAUDE.md güvenli lean trim**: §9 "Runtime — INTEGRATION_SMOKE bar" altındaki 1–5 kriterleri §3'ü kelimesi kelimesine 3. kez tekrar ediyordu; tek satır cross-ref'e indirildi (§3 tek kaynak), §9'a özgü içerik (responsive extreme-cell, contract-parity, walking-skeleton, CI-jobs binding) korundu. Her agent her okumada token kazanır, anlam kaybı yok. CLAUDE.md **çok-dosyaya BÖLÜNMEDİ** — agent'lar dosyanın tamamını okuduğu için bölme parçalanma/okuma round-trip riski getirirdi; lean trim güvenli kazancı parçalanma riski olmadan sağlıyor.
- **23-agent boilerplate konsolidasyonu YAPILMADI (kanıta dayalı karar)**: 244K-token derinlikte bir haritalama, "boilerplate" sanılan blokların ezici çoğunluğunun aslında her agent'ın o kuralı *uygulayan operasyonel spec'i* olduğunu gösterdi (code-reviewer'ın §14 rubric'i, test-writer'ın contract-parity kuralları, orchestrator'ın gate spec'i, task-planner'ın faz şablonları, app-bootstrap/db-migration'ın smoke-evidence prosedürleri). Bunları silmek agent'ları bozar. Tek gerçekten generic dedup (TR/EN tek satırı) ~23 satır için renumbering riski + ihmal edilebilir getiri → yapılmadı. Bu, "her şey profesyonel olsun" hedefinin doğru sonucu: zarar verecek bir refactor'dan kaçınmak.
- **marketplace.json** da senkronlandı (plugin.json'la aynı kusur: "24 agent / 25 skill" → 23 / 46).

**Uçtan-uca doğrulama:** Bağımsız bir consistency audit pipeline'ı baştan sona izledi (`/start-project` → product-analyst → architect → ux-designer → task-planner → faz başına orchestrator döngüsü). State machine 4 kaynakta sıfır-drift (CLAUDE.md §3 / orchestrator.md / hook VALID_STATUSES (16) / README), komut→agent wiring tam, approval gate'leri (5) tutarlı, INTEGRATION_SMOKE §3↔§9↔orchestrator↔CI hizalı, her iki hook doğru bağlı, silinen dosyalara dangling referans yok. Verdict: **end-to-end coherent ve profesyonel.**

**Sonuç/etki:** Template artık kurulabilir artefaktlarıyla (plugin.json + marketplace.json) tutarlı, geliştirme artefaktı sızdırmıyor, en kritik agent prohibition'ları mekanik olarak zorlanıyor, CI job isimleri yaptıkları işe dürüst, anayasa yinelenen kriter tekrarından arındırıldı. Agent sayısı her yerde **23**'e sabitlendi (ADR-005/007'deki "24" tarihsel yazım hatasıydı).

**Ayrı angajman olarak bekleyen:** İlk gerçek pilot proje, 45 `pre-seeded` skill'i `battle-tested`'e taşıyacak gerçek doğrulamayı sağlar (template edit değil, gerçek uygulama build'i).

---

(Future ADRs added here.)

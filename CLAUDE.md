# Mobile App Development Template — System Constitution

This document is the **single source of truth** for how this project is built. Every agent MUST read this file before doing any work. If an instruction here conflicts with a request, surface the conflict to the user instead of silently breaking the rule.

---

## 1. Mission

This template builds **production-grade, senior-level Flutter mobile applications** for both iOS and Android, with a fully orchestrated agent pipeline that enforces quality gates, security, compliance, and reusable knowledge capture.

**Non-negotiables:**
- No step in the pipeline may be skipped silently. If skipped, the reason MUST be logged in the phase file.
- Security and compliance reviews are MANDATORY on every phase, not optional.
- Reusable work MUST be extracted into skills so future projects benefit.
- The user is the only authority who can approve critical gates.

---

## 2. Tech Stack (default)

| Layer | Choice | Notes |
|---|---|---|
| Framework | **Flutter** (latest stable) | Cross-platform, single codebase |
| Language | Dart | |
| State Management | **Riverpod** | Compile-safe, testable |
| Navigation | **go_router** | Declarative, deep-link friendly |
| Networking | **dio** + retry/interceptors | |
| Models | **freezed** + **json_serializable** | Immutable, sealed unions |
| Local Storage | **Drift** (SQL) | Isar abandoned upstream — Drift is the standard. Offline-first by default. |
| Secure Storage | **flutter_secure_storage** | Keychain / Keystore |
| Auth | Firebase Auth (default), Supabase as alternative | |
| Push | **firebase_messaging** + **flutter_local_notifications** | |
| Crash | **firebase_crashlytics** + **sentry_flutter** | |
| Analytics | Firebase Analytics + project-specific (Mixpanel/Amplitude) | |
| Payments | **purchases_flutter** (RevenueCat) | |
| i18n | `flutter gen-l10n` + ARB files | TR + EN minimum |
| Testing | `flutter_test`, `mocktail`, `integration_test` | |
| CI/CD | GitHub Actions + Fastlane | |

**Native escape hatch:** When platform-specific code is needed, write Kotlin (`android/app/src/main/kotlin/...`) or Swift (`ios/Runner/...`) modules and bridge via Flutter platform channels. Document the channel contract in the phase file.

**Backend:** Default to Firebase or Supabase (BaaS). If a custom backend is required, the `architect` agent triggers `api-design` during planning. Otherwise `api-design` is skipped.

---

## 3. The Pipeline — Phase State Machine

Every feature/module is built as a **phase**. Phases are atomic and independently reviewable. Each phase has its own file at `.project/phases/phase-XX-{slug}.md`.

### Phase states

```
DRAFT → PLANNED → BOOTSTRAPPING → IN_PROGRESS → TESTS_WRITTEN
      → CODE_REVIEW → [BUG_HUNT] → SECURITY_REVIEW → PERFORMANCE_REVIEW
      → INTEGRATION_SMOKE → COMPLIANCE_CHECK → QA_SMOKE_TEST → USER_APPROVAL
      → CHRONICLED → SKILL_EXTRACTED → DONE
```

### Transition rules (binding)

| From | To | Triggered by | Skippable? |
|---|---|---|---|
| `DRAFT` | `PLANNED` | task-planner finishes breakdown | NO |
| `PLANNED` | `BOOTSTRAPPING` | only on phase 01 (foundation) | conditional |
| `BOOTSTRAPPING` | `IN_PROGRESS` | app-bootstrap finishes scaffold | NO |
| `IN_PROGRESS` | `TESTS_WRITTEN` | coder finishes implementation | NO |
| `TESTS_WRITTEN` | `CODE_REVIEW` | test-writer finishes | NO |
| `CODE_REVIEW` | `BUG_HUNT` | reviewer risk score = `high` | conditional |
| `CODE_REVIEW` / `BUG_HUNT` | `SECURITY_REVIEW` | review approved | NO |
| `SECURITY_REVIEW` | `PERFORMANCE_REVIEW` | security passed | NO |
| `PERFORMANCE_REVIEW` | `INTEGRATION_SMOKE` | perf passed | NO |
| `INTEGRATION_SMOKE` | `COMPLIANCE_CHECK` | integration smoke evidence complete (build+boot+e2e+contract) | NO |
| `COMPLIANCE_CHECK` | `QA_SMOKE_TEST` | compliance passed | NO |
| `QA_SMOKE_TEST` | `USER_APPROVAL` | qa-test-guide produced scenarios | NO |
| `USER_APPROVAL` | `CHRONICLED` | user typed approval | NO |
| `CHRONICLED` | `SKILL_EXTRACTED` | feature-chronicler updated features.md | NO |
| `SKILL_EXTRACTED` | `DONE` | skill-extractor decided + acted | NO |

### INTEGRATION_SMOKE — the runtime gate (NEVER skippable)

**INTEGRATION_SMOKE** runs *before* `COMPLIANCE_CHECK` so that compliance and QA operate on an app that has actually been built, booted, and exercised against a real backend — not on a declared one. Evidence is recorded in the phase file's `## Integration Smoke` section; the orchestrator will not transition out of this state without it. This gate is NEVER skippable — not conditionally, not via `## Skipped Steps`, not in autonomous mode (`auto_approve: true` bypasses human-approval gates, NOT runtime verification), not for "trivial" phases.

**Exit criteria — ALL must have execution evidence in `## Integration Smoke`:**

1. **Builds.** A real `flutter build <flavor>` is green for each flavor (debug is fine — this is a real compile, NOT `flutter analyze`).
2. **Boots.** The app started on an emulator/simulator or device: boot log + `BOOT_OK` marker (`main()` end emits `debugPrint('BOOT_OK flavor=…')`) + a `splash → first real screen` assertion (no uncaught exception, no rebuild/dispose storm).
3. **Real backend, no mocks.** For each of the phase's PRD-FRs, ≥1 end-to-end flow ran against a real backend (local Supabase / staging) with **no mocked dependency**; HTTP trace (Kong/proxy access log) + DB row evidence pasted into the phase file.
4. **Edge/server work proven.** Every new Edge Function / RPC / migration was applied to a real local stack and received ≥1 real authenticated call returning 2xx (not just "file written").
5. **Reachable.** Every new screen has a verified concrete tap-path from its PRD entry point (`<screen A> → <action> → <this screen>`), executed — "defined route" ≠ "reachable".

**Why this exists:** static gates (`flutter analyze`, mocked unit/widget/golden tests, read-only review, line coverage) structurally cannot see the three empirically-dominant failure classes: (A) Riverpod/stream lifecycle (rebuild/dispose/churn/yield only manifest in a running app), (B) client↔backend contract drift (a mock that encodes the bug instead of verifying the contract), (C) integration/accessibility gaps (a screen exists but no flow reaches it). Green tests + clean analyze + passing reviews are **not a running app**. Until the app is actually built and run against a real backend each phase, `DONE` is a declaration, not evidence.

**Bug loop:** If `BUG_HUNT` finds a bug, state returns to `IN_PROGRESS`. Loop continues until reviewer score ≤ `medium`.

**Skip discipline:** "conditional" steps require an explicit decision to be logged in the phase file's `## Skipped Steps` section with reason. Anything else is a process violation.

---

## 4. Agent Roster (23 total)

Full prompts live under `.claude/agents/`. One-line summary here:

| Agent | Role | Trigger |
|---|---|---|
| `orchestrator` | Reads phase state, dispatches next agent, enforces transitions | Slash command `/continue` or after any agent finishes |
| `product-analyst` | Writes PRD from user intent | `/start-project` |
| `architect` | Tech stack decisions, folder layout, state mgmt, backend choice | After PRD approval |
| `ux-designer` | Screen flows, design system, component inventory | After architecture |
| `task-planner` | Breaks scope into phases, writes phase files | After UX |
| `app-bootstrap` | `flutter create`, deps, lints, base folders | Phase 01 only |
| `api-design` | Designs REST/GraphQL contracts | Conditional: only if architect chose custom backend |
| `coder` | Implements tasks. **MUST read `.claude/skills/INDEX.md` first.** | Phase `IN_PROGRESS` |
| `test-writer` | Unit + widget + integration tests | After coder |
| `code-reviewer` | Quality, conventions, SOLID, Flutter idioms; outputs risk score | After tests |
| `bug-hunter` | Deep bug scan when risk = high | Conditional |
| `bug-report-handler` | Triages user-reported bugs, opens new phases or appends fixes | On `/report-bug` |
| `security-reviewer` | OWASP MASVS, secrets, secure storage, deep links, certificate pinning | MANDATORY each phase |
| `performance-reviewer` | DevTools metrics, jank, memory, build size | MANDATORY each phase |
| `compliance` | KVKK, GDPR, CCPA, ATT, privacy policy, data deletion | MANDATORY each phase |
| `localization` | ARB files, l10n setup, translation coverage | When user-facing strings change |
| `crash-monitor` | Crashlytics + Sentry config, breadcrumbs, alerts | Phase 01 + on demand |
| `db-migration` | Local DB schema migrations (Drift) | When schema changes |
| `qa-test-guide` | Step-by-step manual test scenarios for the user to run | Before user approval |
| `feature-chronicler` | Updates `.project/features.md` with user-facing changes | After user approval |
| `aso` | App Store Optimization: keywords, descriptions, screenshots strategy | Before release |
| `skill-extractor` | Decides if work is reusable; writes new skill + updates INDEX | After chronicler |
| `release-manager` | Version bump, changelog, build, sign, store submission | `/ship` |

---

## 5. Directory Layout

```
mobile-app-development-templates/
├── .claude/
│   ├── agents/              # 23 agent definitions
│   ├── commands/            # slash commands
│   ├── skills/              # reusable knowledge (grows over time)
│   │   └── INDEX.md         # ← coder reads this FIRST
│   └── settings.json        # permissions, hooks
├── .project/
│   ├── README.md            # what every file in here is for
│   ├── prd.md               # product requirements (product-analyst)
│   ├── architecture.md      # LEAN INDEX: frontmatter + TOC + stack summary + ADR log (architect)
│   ├── arch/                # modular architecture slices — agents read only their slice (architect)
│   │   ├── 01-foundation.md         # §1 style, §2 stack, §3 layers, §4 folders
│   │   ├── 02-implementation.md     # §5 state, §6 nav, §7 data, §8 networking, §10 errors, §13 codegen
│   │   ├── 03-data-and-storage.md   # §9 Drift local DB
│   │   ├── 04-security-and-secrets.md  # §11 envs/flavors, §12 secrets
│   │   ├── 05-design-and-ux.md      # §14 theming, §15 assets/fonts
│   │   └── 06-quality-and-ops.md    # §16 logging, §17 testing, §18 lint, §19 CI/CD, §20 perf budgets
│   ├── design-system.md     # colors, typography, components (ux-designer)
│   ├── layouts.md           # text-described per-screen layouts (ux-designer)
│   ├── features.md          # user-facing features, marketing-ready (feature-chronicler)
│   ├── security-checklist.md   # MASVS-based, rolling (security-reviewer)
│   ├── perf-checklist.md       # rolling (performance-reviewer)
│   ├── compliance-checklist.md # rolling (compliance)
│   ├── decisions.md         # project-wide ADR log
│   ├── known-issues.md      # WONTFIX entries, accepted risks
│   ├── handoffs.md          # JSONL append-only inter-agent log
│   ├── phases/
│   │   ├── INDEX.md         # all phases + status board
│   │   ├── phase-XX-{slug}.md          # LIVE working set: Goal/AC/Tasks/Open Q/Skipped/Latest Handoff (≤~8KB)
│   │   └── phase-XX-{slug}-archive.md  # heavy evidence + history (Decisions/Integration Smoke/Smoke Log/Handoff history)
│   ├── api/                 # OpenAPI spec — only if custom backend (api-design)
│   ├── references/          # external rule docs
│   │   ├── appstore-guidelines.md
│   │   └── playstore-guidelines.md
│   ├── legal/               # privacy policy, terms, sdk-inventory (compliance)
│   ├── perf-snapshots/      # user-pasted DevTools measurements
│   ├── l10n-deltas/         # TMS export/import (localization)
│   ├── aso/                 # store metadata, keywords, screenshots (aso)
│   ├── qa-runs/             # pipeline dry-runs, manual QA test logs, test findings
│   └── release-notes/       # per-release per-locale notes (release-manager)
├── lib/                     # Flutter source (created by app-bootstrap)
├── test/
├── ios/, android/
├── CLAUDE.md                # ← this file
└── README.md
```

---

## 6. File Conventions

### Phase file frontmatter (REQUIRED)

Field categories — **persistent** = manually written by `task-planner` and only changed via explicit replan; **computed** = orchestrator/agents update as state changes.

```yaml
---
# --- PERSISTENT (set by task-planner, rarely changes) ---
phase_id: 03                  # persistent: never changes after creation
title: Authentication & Onboarding
slug: auth-onboarding
depends_on: [01, 02]          # persistent
unblocks: [04, 05]            # persistent
linked_frs: [FR-01, FR-02, FR-03]  # persistent
estimated_tasks: 9            # persistent (re-estimate only on replan)
estimated_files: 12           # persistent
walking_skeleton_invariant: "app builds, launches, and passes basic smoke test after this phase"
created: 2026-05-09           # persistent

# --- COMPUTED (updated by orchestrator/agents — DO NOT touch by hand) ---
status: IN_PROGRESS           # computed by orchestrator on state transitions
owner_agent: coder            # computed by orchestrator on dispatch
last_updated: 2026-05-09      # computed: bump on every status change
last_reconciled: 2026-05-09   # computed: bump when planner re-validates against PRD
skills_used: []               # computed by coder
skills_to_extract: []         # computed by coder + skill-extractor
risk_score: null              # computed by code-reviewer: low | medium | high
user_approved: false          # computed by orchestrator on USER_APPROVAL gate
---
```

**`last_updated` vs `last_reconciled`**:
- `last_updated`: bumps on ANY frontmatter change (orchestrator on every state transition, any agent that edits frontmatter).
- `last_reconciled`: bumps ONLY by `task-planner` when it re-validates phase scope against current PRD + architecture + design-system. This happens (a) on initial phase write, (b) on explicit `/replan` invocation, (c) when PRD/architecture has changed since last reconcile and task-planner is asked to verify the phase still maps cleanly. Other agents MUST NOT touch this field.

### Phase file body sections — LIVE + ARCHIVE split (token discipline)

A phase is **two files** so that the 12+ agent invocations per phase read a small working set, not an ever-growing evidence log. (Rationale + savings: decisions.md ADR-007.)

**LIVE file `phase-XX-{slug}.md`** — the working set every agent reads. Keep it lean — bounded reviewer verdict blocks stay here; all UNBOUNDED evidence/logs/history go to the archive. Sections, in this order:

1. `## Goal`
2. `## Acceptance Criteria` (checklist)
3. `## Tasks` (checklist with owner agent + status)
4. `## Open Questions / Blockers`
5. `## Skipped Steps` (with reasons — short; policy-relevant so it stays live)
6. `## Latest Handoff` (ONLY the most recent handoff block — full chronological history lives in the archive)
7. `## Evidence & History (archived)` — one-line pointers into the archive, e.g. `Integration Smoke → phase-XX-{slug}-archive.md#integration-smoke (PASS, 2026-05-26)`

Plus the per-phase **review verdict blocks** — `## Code Review`, `## Bug Hunt`, `## Security Review`, `## Performance Review`, `## Compliance Check` — stay LIVE (bounded, verdict-focused; the next reviewer and the orchestrator's gate checks read them). If a review needs a bulky reproduction log or code dump, that bulk goes to the archive with a one-line pointer in the live block.

**ARCHIVE file `phase-XX-{slug}-archive.md`** — append-only heavy content. Created lazily on first heavy write. Sections:

- `## Decisions Log` (date-stamped, full history)
- `## Integration Smoke` (build + boot + real-backend e2e + contract + reachability evidence — **gates `INTEGRATION_SMOKE`**)
- `## Smoke Test Log` (filled by qa-test-guide)
- `## Handoff Notes` (full chronological history; each agent appends here AND refreshes `## Latest Handoff` in the live file)

**Read/write rule (BINDING):** Agents read the LIVE file by default. The archive is opened ONLY by: (a) the agent producing that evidence (writes to archive), (b) the orchestrator/qa-test-guide when verifying an evidence gate (`INTEGRATION_SMOKE` → archive `## Integration Smoke`; `QA_SMOKE_TEST` → archive `## Smoke Test Log`), (c) skill-extractor and historical audits. When any rule in this file says "the phase file's `## Integration Smoke` / `## Smoke Test Log` / `## Handoff Notes` / `## Decisions Log`", it means **the archive file's** section. Frontmatter always lives in the LIVE file.

### `phases/INDEX.md` format

One row per phase: `| ID | Title | Status | Risk | User Approved |`

---

## 7. Skill System — The Token-Saving Engine

### Discovery rule (BINDING)

**Before writing any implementation code, the `coder` agent MUST:**
1. Read `.claude/skills/INDEX.md`
2. Match the current task against skill descriptions and triggers
3. If a skill matches → read its `SKILL.md` and follow it
4. If no skill matches → implement from scratch, but note in phase's `skills_to_extract`

**Skill format** (Claude Code native):

```
.claude/skills/<skill-slug>/
├── SKILL.md           # frontmatter: name, description, triggers, last_verified
├── implementation.md  # step-by-step
├── snippets/          # ready-to-paste code
└── pitfalls.md        # real bugs encountered, how to avoid
```

**SKILL.md frontmatter:**

```yaml
---
name: notifications-fcm
description: FCM push notifications, local notifications, permission flow, deeplink routing for Flutter. Use when adding push notifications.
triggers: [push notification, fcm, firebase messaging, notification permission, local notification, notification deeplink]
platforms: [ios, android]
last_verified: 2026-05-09
flutter_min: "3.19.0"
---
```

### Extraction rule

After `USER_APPROVAL`, the `skill-extractor` agent inspects what was built and decides:
- Is this reusable across projects? (not project-specific business logic)
- Did we hit non-obvious pitfalls worth documenting?
- Did we make decisions that took multiple iterations?

If yes to any → create skill, update `INDEX.md`. If no → log decision in phase file.

---

## 8. Critical Approval Gates (User Says Yes Required)

Only these moments require user approval. Everything else runs automatically.

| Gate | When |
|---|---|
| **PRD approval** | After `product-analyst` finishes |
| **Architecture & stack approval** | After `architect` finishes |
| **Phase plan approval** | After `task-planner` finishes |
| **Phase smoke test approval** | After `qa-test-guide` produces scenarios — user runs on device, reports back |
| **Release go/no-go** | Before `release-manager` ships |

The orchestrator MUST stop and ask the user at these gates. No auto-advance.

### Approval detection (fuzzy)

Accept any of: `onayla`, `onaylıyorum`, `onaylandı`, `tamam`, `devam`, `devam et`, `approve`, `approved`, `yes`, `ok`, `okay`, `evet` — case-insensitive, anywhere in the user message. If user message contains BOTH approval AND a change request → treat as change request.

If user reply is ambiguous (off-topic, meta-instruction without clear yes/no), agents MUST re-ask explicitly with the ✅/❌ format — never silently advance on implicit approval.

### 8.1. Autonomous mode (CI / dry-run / explicit user opt-out)

Production default: every gate above blocks. Two ways to bypass for CI/test/explicit-opt-out:

1. **Project-wide flag**: `.project/decisions.md` opens with a YAML frontmatter block containing `auto_approve: true`. Format (parseable by hook + agents — never grep body):
   ```yaml
   ---
   auto_approve: false                    # true to bypass all approval gates except Release
   auto_approve_set_by: null              # "user" | "agent" | "ci" — who flipped it
   auto_approve_reason: null              # one-line reason
   auto_approve_set_at: null              # ISO date
   ---
   ```
2. **Per-conversation override**: user types something like "onay almana gerek yok", "best practice ile devam", "auto-approve all gates". Agent treats this exactly like flag=true for the rest of the conversation but does NOT mutate decisions.md unless user confirms persistence.

When autonomous mode is active:
- Agents skip the explicit user-ask, set `status: approved` + `approved_by: auto` + `approved_at: <today>` in the relevant doc's frontmatter.
- Each auto-approval MUST be appended to `.project/decisions.md` ADR Log section as: `## ADR-NNN — Auto-approval applied ({gate_name})` with date, reason, consequences.
- For the "Release go/no-go" gate: autonomous mode is FORBIDDEN. Release always requires explicit human approval.

---

## 9. Senior-Level Quality Bar

Every agent must enforce these baselines. Violations block progression.

### Code (every PR-equivalent)
- Null-safety enabled, no `!` without justification
- All public APIs have doc comments only when behavior is non-obvious
- `const` constructors wherever possible
- No business logic in widgets — extract to providers/notifiers
- All async operations have error handling and loading states
- All resources (controllers, streams, timers) disposed
- No hardcoded strings — go through l10n

### Testing
- Each notifier/repository has unit tests
- Each non-trivial widget has a widget test
- Critical user flows have integration tests
- Coverage target: ≥70% on `lib/` excluding generated files
- Line coverage from mocked tests ≠ integration coverage. A feature that touches a backend is NOT "tested" until its real backend path is exercised once (see Runtime below).

### Runtime — the `INTEGRATION_SMOKE` bar (every phase — enforced, not aspirational)
- `flutter build <flavor>` (real compile, not `flutter analyze`) green for each flavor; iOS equivalent in CI
- App boots on an emulator/device: `BOOT_OK` marker + `splash → first real screen`, no uncaught exception, no rebuild/dispose storm
- ≥1 NON-MOCKED end-to-end flow per phase FR against a real backend (`supabase start` / staging); HTTP trace + DB row evidence pasted into `## Integration Smoke`
- Every new Edge Function / RPC / migration applied to a real local stack with ≥1 real authenticated call → 2xx (not just "file written")
- Every new screen has an executed, concrete tap-path from its PRD entry point ("defined route" ≠ "reachable")
- **Responsive/dynamic-type extreme cell:** the worst combination (smallest target device + max clamped OS text scale) boots and the phase's screens render with ZERO `RenderFlex`/overflow on a real emulator — evidence pasted
- **Contract parity (no mock may encode a bug):** every `functions.invoke` / REST call has a test asserting HTTP method + body field names against the real Edge/OpenAPI signature; every `async*` provider has a yield-contract test; boundary mocks (`any(named:'body')`) at the client↔backend edge are forbidden — assert the contract or defer it to `INTEGRATION_SMOKE`
- `walking_skeleton_invariant` is VERIFIED by this gate, never merely declared
- The CI runtime jobs (`build-and-boot`, `build-ios`, `backend-integration`, `integration-smoke`) MUST be green before a phase leaves `INTEGRATION_SMOKE`. Static green (analyze + mocked tests + line coverage) is necessary but NOT sufficient — it is not a running app.

### Responsive & accessible text (every UI phase)
- Layout decided from available space (`MediaQuery.sizeOf` / `LayoutBuilder` / `core/responsive`), Material 3 window size classes (Compact <600 / Medium 600–840 / Expanded >840). No `OrientationBuilder`/`isTablet()` for layout, no fixed sizes on must-fit content, no full-width gobble on large screens.
- OS text scaling RESPECTED and root-clamped via `MediaQuery.withClampedTextScaling` (default `1.0–1.3`, = design-system §22). Disabling text scaling is forbidden (accessibility + store risk).
- Every new screen / design-system component has a size×textScale golden matrix test ({320×640,390×844,768×1024} × {1.0,1.3,2.0}) asserting no overflow at every cell (test-writer Iron Rule #10). `qa-test-guide` mirrors it on a real device (smallest + largest OS font). Skill: `responsive-adaptive-layout`.

### Security (MASVS-aligned)
- No secrets in source — use `--dart-define` + secure CI vars
- `flutter_secure_storage` for tokens, never `SharedPreferences`
- Certificate pinning on production API calls
- Jailbreak/root detection on sensitive screens (auth, payments)
- Biometric auth via `local_auth` for re-auth on sensitive actions
- Deep link validation — never trust incoming URLs blindly
- Release builds use `--obfuscate --split-debug-info`
- Android: ProGuard/R8 rules verified
- iOS: ATT prompt before any tracking
- Privacy manifest (`PrivacyInfo.xcprivacy`) on iOS

### Compliance
- KVKK + GDPR consent flows for EU/TR users
- "Delete my account" + data export must work
- Privacy policy + terms accessible in-app
- Children data handling (if app targets <13)

### Performance
- 60fps scroll on a mid-tier device (Pixel 4a equivalent)
- Cold start <2s on mid-tier device
- App size <50MB initial install (target)
- No memory leaks across navigation cycles
- Network calls batched, cached, deduplicated

### CI economy & determinism
- **Batch, don't spray.** Run the full gate set locally; push in batches and let CI confirm once per batch — not a CI run per commit. Per-commit-push CI burns the Actions minute budget fast (a real incident: ~2000 CI minutes drained by per-commit pushes in one session).
- **Generated artifacts must be deterministic or excluded.** A repo-wide `git diff --exit-code` gate must NOT trip on non-deterministic generated files (timestamped audit reports, etc.). Either generate them deterministically (fixed timestamp/seed) or exclude them from the diff gate. Non-deterministic generated diffs are a recurring false-fail source.
- After running diagnostics/codegen, regenerate clean: `.g.dart`/`.freezed.dart` hashes must match a fresh `build_runner` (`regen-clean-after-diagnostics` skill).

---

## 10. Slash Commands

| Command | What it does |
|---|---|
| `/start-project` | Kicks off PRD → architecture → phase planning |
| `/continue` | Reads current phase state, dispatches next agent |
| `/start-phase <id>` | Begins a specific phase |
| `/report-bug` | Triages a user-reported bug |
| `/extract-skill` | Manually run skill-extractor on a finished phase |
| `/ship` | Triggers release-manager |
| `/status` | Prints phase index + current state summary |

---

## 11. Reading Order for Agents

When any agent starts, it MUST read in this order:
1. `CLAUDE.md` (this file)
2. `.project/architecture.md` — this is now a **lean INDEX** (TOC + stack summary + ADR log), NOT the full spec. Do NOT read the whole `arch/` tree.
3. **Only the `arch/` slice(s) your role owns** (table below). Load another slice **on demand** if a task genuinely needs it — never read all slices "to be safe".
4. The current phase file — the **LIVE** `phase-XX-{slug}.md` only. Open `phase-XX-{slug}-archive.md` ONLY when you must verify/append evidence (see §6 read/write rule).
5. Any agent-specific files referenced in its own definition
6. `.claude/skills/INDEX.md` (coder reads FIRST per §7; others may reference)

### Architecture slice ownership (single source of truth)

| Agent | Primary `arch/` slice(s) beyond the index |
|---|---|
| `coder` | `02-implementation` + load `03`/`04`/`05` per the task's surface |
| `test-writer` | `06-quality-and-ops` + the slice(s) under test |
| `code-reviewer`, `bug-hunter` | index + the slice(s) the phase touched |
| `db-migration` | `03-data-and-storage` |
| `security-reviewer` | `04-security-and-secrets` (+ `02` for networking) |
| `compliance` | `04-security-and-secrets` |
| `performance-reviewer` | `06-quality-and-ops` |
| `ux-designer` | `05-design-and-ux` (+ `02` for navigation) |
| `app-bootstrap` | `01-foundation` + `04-security-and-secrets` + `06-quality-and-ops` |
| `crash-monitor`, `release-manager` | `06-quality-and-ops` (+ `04` for envs/secrets) |
| `api-design` | `02-implementation` (networking) |
| `task-planner` | index + load slices as scope demands |
| `orchestrator`, `feature-chronicler`, `aso`, `localization`, `product-analyst` | index only (load a slice only if a specific check needs it) |
| `architect` | producer — writes the index + all slices (see architect.md) |

**Write authority (BINDING):** ONLY `architect` writes `.project/architecture.md` and `.project/arch/*` (post-approval changes go through ADRs — see architect.md). Every other agent is READ-ONLY on the index and all slices, same as the existing "do not edit architecture.md" rule in each agent's prohibitions — it now covers the whole `arch/` tree.

---

## 12. Communication Style

- All agent responses to the user MUST be in **Turkish** by default (this user prefers Turkish). Code, identifiers, file names stay in English.
- Be concise. No filler. Lead with the result.
- When asking for approval, give the user a clear yes/no question.
- When handing off to another agent: append the full handoff to the **archive** file's `## Handoff Notes` AND refresh the **live** file's `## Latest Handoff` block (most recent only) — do NOT bury context in chat-only output. (See §6 LIVE+ARCHIVE split.)

---

## 13. When Things Go Wrong

- **A required step was skipped:** Stop. Reset state to before the skip. Re-run the missing agent. Log the incident in `.project/decisions.md`.
- **Two agents disagree:** Surface to user with both positions. Do not auto-resolve.
- **A skill turned out wrong:** Update the skill's `pitfalls.md`, bump `last_verified`, fix in current project.
- **The user contradicts a rule in CLAUDE.md:** Confirm explicitly that the user wants to override the rule for this project, then update `.project/decisions.md`. Do NOT silently override.

### Debugging discipline (when a bug fights back)

Triggered when a fix didn't take, a bug reproduces after a "fix", or you are >1 iteration into a platform/SDK/native/cold-start issue. These exist because a real run (Mimirva deep-link campaign) burned ~hours on each: the cure was a discipline, not more code.

1. **Research before fix.** For a platform / SDK / native / config bug, verify the official doc + the *exact* error code/string via WebSearch BEFORE writing a fix (e.g. Apple "Defining a custom URL scheme", the Flutter issue tracker, the package CHANGELOG / `pubspec.lock` pin — confirm, don't assume the version). A speculative fix to a misdiagnosed platform bug is the canonical hours-burner. (This is the concrete debugging form of §14.1 "Think before coding".)
2. **Instrument, don't speculate.** When the console is detached (cold start, push-launched, release-mode boot) you cannot see logs — so don't guess. Add a temporary file-trace helper (`getApplicationDocumentsDirectory()/trace.log`), reproduce, then pull it (`xcrun simctl get_app_container <udid> <bundle> data` / `adb`). Measure the actual path; remove the helper before the phase closes.
3. **Deterministic test over device.** If a defect is provable by a deterministic widget/unit test, write that test FIRST — do not wait on a device smoke loop to see it. **A mocked `StatefulShellRoute` navigation assertion is false-green**: assert the state machine / branch index, not a mocked widget tree. (Per-task expression of §9 "Runtime" + test-writer Iron Rules; the false-green nuance is binding on test-writer + code-reviewer.)
4. **Trust but verify (orchestrator).** A coder/agent "all gates passed / done" is a claim, not evidence — the orchestrator independently re-checks the diff + the gate before advancing. (Already binding via orchestrator STEP 8 + §14.4; restated here as a debugging-loop guard.)
5. **Written ≠ applied (server/backend).** Every RPC / trigger / RLS / cron / Edge fn must be an *applied* migration under `supabase/migrations/` AND proven by ≥1 real authenticated call — never SQL dropped in `supabase/functions/`, never "file written". (Already enforced by §9 "Runtime" + INTEGRATION_SMOKE criterion 4 + the `supabase-*` skills; restated here because it is the #1 "fixed it but it never ran" trap.)

---

## 14. Behavioral Discipline (every agent, every turn)

This is HOW agents work, distinct from the WHAT-gates in §3/§9. It exists because the runtime gates catch "never ran it"; these catch "assumed wrong / overcomplicated / drive-by-refactored / no success criterion". Subagents read this file, not the harness prompt — so it is binding here. (Derived from Andrej Karpathy's LLM-coding-pitfall observations; adapted to this pipeline.)

1. **Think before coding.** Don't assume on the user's behalf and run with it. State assumptions explicitly; if multiple readings exist, surface them — don't pick silently; if a simpler path exists, say so and push back; if something is unclear or inconsistent, stop and ask. This refines, not overrides, §8 autonomous mode: autonomy bypasses approval *gates*, never the duty to surface a real ambiguity or contradiction.
2. **Simplicity first.** Minimum code that solves the stated problem. No feature, abstraction, "flexibility", or error-handling for impossible cases beyond what was asked. Single-use code gets no abstraction. If 200 lines could be 50, rewrite. Test: "would a senior Flutter dev call this overcomplicated?" — if yes, simplify. (A bloated construction is itself a code-reviewer finding.)
3. **Surgical changes.** Touch only what the task requires. No "improving" adjacent code/comments/formatting, no refactor of things that aren't broken, match existing style even if you'd do it differently. Remove only the imports/vars/functions *your* change orphaned; pre-existing dead code is *mentioned* (handoff notes / `## Open Questions`), not deleted unless asked. Every changed line must trace to the request or the active phase's tasks. Read-only agents stay read-only.
4. **Goal-driven execution.** Convert each task into a verifiable success criterion before acting ("add validation" → "tests for invalid input fail, then pass"; "fix bug" → "a test reproduces it, then passes; suite still green"). State a brief `step → verify` plan for multi-step work and loop until the verify passes. This is the per-task expression of the §3 evidence philosophy (INTEGRATION_SMOKE = the per-phase one): a claim without a verification is not done.

Working if: diffs contain only request-traceable lines, fewer rewrites from overcomplication, and clarifying questions arrive *before* implementation, not after a wrong assumption shipped. For genuinely trivial tasks, use judgment — don't bureaucratize a one-liner.

---

*This file is versioned. Material changes require a note in `.project/decisions.md`.*

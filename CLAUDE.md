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
│   ├── architecture.md      # tech decisions (architect)
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
│   │   └── phase-XX-{slug}.md  # one file per phase (task-planner)
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

### Phase file body sections (REQUIRED in this order)

1. `## Goal`
2. `## Acceptance Criteria` (checklist)
3. `## Tasks` (checklist with owner agent + status)
4. `## Decisions Log` (date-stamped)
5. `## Skipped Steps` (with reasons)
6. `## Open Questions / Blockers`
7. `## Integration Smoke` (build + boot + real-backend e2e + contract + reachability evidence — gates `INTEGRATION_SMOKE`)
8. `## Smoke Test Log` (filled by qa-test-guide)
9. `## Handoff Notes` (each agent leaves notes for the next)

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
- **Contract parity (no mock may encode a bug):** every `functions.invoke` / REST call has a test asserting HTTP method + body field names against the real Edge/OpenAPI signature; every `async*` provider has a yield-contract test; boundary mocks (`any(named:'body')`) at the client↔backend edge are forbidden — assert the contract or defer it to `INTEGRATION_SMOKE`
- `walking_skeleton_invariant` is VERIFIED by this gate, never merely declared
- The CI runtime jobs (`build-and-boot`, `build-ios`, `backend-integration`, `integration-smoke`) MUST be green before a phase leaves `INTEGRATION_SMOKE`. Static green (analyze + mocked tests + line coverage) is necessary but NOT sufficient — it is not a running app.

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
2. `.project/architecture.md`
3. The current phase file
4. Any agent-specific files referenced in its own definition
5. `.claude/skills/INDEX.md` (coder only — but others may reference)

---

## 12. Communication Style

- All agent responses to the user MUST be in **Turkish** by default (this user prefers Turkish). Code, identifiers, file names stay in English.
- Be concise. No filler. Lead with the result.
- When asking for approval, give the user a clear yes/no question.
- When handing off to another agent, write to the phase file's `## Handoff Notes` — do NOT bury context in chat-only output.

---

## 13. When Things Go Wrong

- **A required step was skipped:** Stop. Reset state to before the skip. Re-run the missing agent. Log the incident in `.project/decisions.md`.
- **Two agents disagree:** Surface to user with both positions. Do not auto-resolve.
- **A skill turned out wrong:** Update the skill's `pitfalls.md`, bump `last_verified`, fix in current project.
- **The user contradicts a rule in CLAUDE.md:** Confirm explicitly that the user wants to override the rule for this project, then update `.project/decisions.md`. Do NOT silently override.

---

*This file is versioned. Material changes require a note in `.project/decisions.md`.*

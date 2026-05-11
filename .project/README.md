# `.project/` — Living Project Knowledge

This directory contains the source-of-truth documents that every agent reads. Files are populated/updated as the project progresses through the pipeline.

## Files (created on demand by agents)

| File | Created by | Purpose |
|---|---|---|
| `prd.md` | product-analyst | Product Requirements Document |
| `architecture.md` | architect | Tech stack, layers, contracts (append-only after first write) |
| `design-system.md` | ux-designer | Color/typography/spacing tokens, component inventory |
| `layouts.md` | ux-designer | Per-screen text-described layouts |
| `features.md` | feature-chronicler | User-facing features in marketing-ready language |
| `security-checklist.md` | security-reviewer | Rolling MASVS L1/L2 audit per phase |
| `perf-checklist.md` | performance-reviewer | Rolling NFR budget tracking per phase |
| `compliance-checklist.md` | compliance | Rolling KVKK/GDPR/ATT/Play DS per phase |
| `decisions.md` | (manual) ADR log for project-wide decisions outside architecture.md |
| `known-issues.md` | bug-report-handler | WONTFIX entries (user-acknowledged) |
| `handoffs.md` | orchestrator | Append-only JSONL log of every agent dispatch |
| `legal/sdk-inventory.md` | compliance / security-reviewer | Third-party SDK list with privacy justification |

## Subdirectories

| Path | Purpose |
|---|---|
| `phases/` | One file per phase + INDEX.md |
| `api/` | OpenAPI spec + README (only if architect set triggers_api_design=true) |
| `references/` | External rule docs (App Store guidelines, Play Store guidelines) |
| `legal/` | Templates for aydınlatma metni, privacy policy, terms — placeholders for lawyer to fill |
| `perf-snapshots/` | User-pasted performance measurements per phase |
| `l10n-deltas/` | TMS-ready ARB delta exports per phase |
| `release-notes/` | Per-release notes per locale per store |
| `aso/` | App Store Optimization metadata + screenshots brief |
| `qa-runs/` | Pipeline dry-runs, manual QA test logs, test findings reports (e.g. `test-findings-{date}.md`) |

## Convention

- All technical content in English
- User-facing prose (when displayed to user) in Turkish
- Append-only files: `architecture.md` (after approval), `handoffs.md`, `features.md` Changelog section, `known-issues.md`, security/perf/compliance checklist Pre-Release Audit Logs
- Mutable files: phase files (until DONE), feature-chronicler's marketing surfaces (Headline/Core Features/Highlights)

## Initialization

Run `/start-project` to bootstrap. Agents create files as needed.

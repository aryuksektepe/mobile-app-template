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

(Future ADRs added here.)

# Project Learnings — in-project memory (read before you build)

> **Purpose:** the project's running memory. Every phase, agents append non-obvious
> lessons here (a pattern that worked, a pitfall hit, a decision that took >1 try,
> a package/API quirk specific to THIS project). The `coder` reads this FIRST on
> every phase (before INDEX.md), so the pipeline stops re-learning the same thing
> across a long auto-mode run.
>
> **This vs other knowledge files (don't duplicate):**
> - `learnings.md` (this file) = **project-specific**, fast-moving, append-only notes. Cheap to write.
> - `.claude/skills/` = **cross-project** reusable knowledge (skill-extractor promotes a learning here only if it generalizes).
> - `decisions.md` = project-wide **architectural/process ADRs** (heavier, dated, consequence-bearing).
> - `known-issues.md` = **accepted/WONTFIX** issues and live workarounds.
>
> **Read rule (BINDING):** `coder` MUST read this file before writing code each phase.
> **Write rule:** `coder`, `bug-hunter`, `test-writer`, `db-migration` append an entry
> whenever they hit a non-obvious, reusable-within-this-project lesson. Keep each entry
> to 2–5 lines. Newest at the bottom of each section. Don't log the obvious.

---

## How to write an entry

```
### L-NN — <one-line title>  [phase XX, YYYY-MM-DD, <agent>]
- Context: <where/when it bites>
- Lesson: <what to do / avoid — concrete>
- Trigger: <keywords so a future search finds this> (e.g. "supabase realtime, yield, empty list")
```

Give each entry a stable `L-NN` id (increment). If a learning recurs across ≥2 phases,
flag it `[recurrence: N]` — that is skill-extractor's signal to promote it to a real skill.

---

## Architecture & state (Riverpod, navigation, lifecycle)

_(no entries yet)_

## Data, backend & contracts (Supabase/Firebase, Drift, RPC, migrations)

_(no entries yet)_

## UI, responsive & accessibility

_(no entries yet)_

## Build, tooling, platform & native (iOS/Android, codegen, flavors)

_(no entries yet)_

## Testing & the runtime smoke gate

_(no entries yet)_

# Known Issues — accepted risks & WONTFIX (user-acknowledged)

> **Purpose:** issues we have CONSCIOUSLY decided not to fix right now, plus their
> live workarounds. Distinct from `learnings.md` (lessons that improve future work)
> and `decisions.md` (architectural/process ADRs). An entry here means: "we know,
> we chose to live with it, here's why and what to do meanwhile."
>
> **Write rule:** `bug-report-handler` adds a WONTFIX entry ONLY after explicit user
> acknowledgement (CLAUDE.md §13). Other agents may PROPOSE an entry (mark it
> `status: proposed`) but it is not accepted until the user confirms.

---

## How to write an entry

```
### KI-NN — <one-line title>
- status: accepted | proposed | workaround-only
- severity: low | medium | high
- area: <auth | payments | sync | ui | platform | ...>
- description: <what the issue is, observable symptom>
- why not fixed now: <cost / scope / upstream-blocked / accepted-risk>
- workaround: <what users/devs do meanwhile, or "none">
- revisit: <condition or date to reconsider, or "—">
- acknowledged by: <user | —>  on <YYYY-MM-DD>
```

---

_(no accepted issues yet)_

---
description: Pipeline'ı bir adım ilerlet — orchestrator state'e bakıp sıradaki agent'ı dispatch eder.
allowed-tools: Task, Read, Edit
---

# /continue

Pipeline'ı bir adım ilerlet. **orchestrator** agent'ını dispatch et — o state'i okur, sıradaki agent'ı seçer, çağırır, handoff'u kaydeder.

## Talimat

`orchestrator` Task'ını başlat:

```
subagent_type: orchestrator
description: Advance pipeline one step
prompt: Read CLAUDE.md, .project/architecture.md, .project/phases/INDEX.md, then find the active phase per §3 of orchestrator.md, validate frontmatter, verify previous-agent artifacts, decide next agent per §4 dispatch table, and dispatch ONE Task. If approval gate (USER_APPROVAL), STOP and produce the approval question per §6.
```

Orchestrator dispatched ne yaptıysa onu user'a kısaca bildir.

User input: $ARGUMENTS

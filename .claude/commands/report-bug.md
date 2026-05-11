---
description: Dış kullanıcıdan / QA / production crash gelen bug raporunu triage et — bug-report-handler agent'ına dispatch.
allowed-tools: Task, Read, Write, Edit
---

# /report-bug

Bug raporunu triage et. **bug-report-handler** agent'ı bug'ı sınıflandırır:
- New hotfix phase (kritik + DONE phase'de)
- Append to in-flight phase
- Need more info
- Not-a-bug
- Duplicate
- Wontfix proposed
- False positive candidate

## Talimat

`bug-report-handler` Task'ını başlat:

```
subagent_type: bug-report-handler
description: Triage incoming bug report
prompt: User submitted a bug report via /report-bug. The report is in $ARGUMENTS (or in the user's most recent message if $ARGUMENTS is empty). Triage per bug-report-handler.md §3-§6:
1. Field completeness check
2. If insufficient → batched clarification request (5 max)
3. If sufficient → triage decision tree
4. Execute action (create hotfix phase / append to in-flight / etc.)
5. Output result + caveat
```

User input (bug report): $ARGUMENTS

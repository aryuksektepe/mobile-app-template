---
description: Belirli bir fazı başlat (faz id verilir, o faz IN_PROGRESS'e geçer).
allowed-tools: Task, Read, Edit
---

# /start-phase

Belirli bir fazı (id ile) başlat. Fazın status'unu PLANNED'den ilerlet.

## Talimat

User input ($ARGUMENTS) faz id'sini içeriyor (örn: "03" veya "phase-03-auth").

1. `.project/phases/INDEX.md` ve hedef phase dosyasını oku
2. Faz status'u PLANNED ise → orchestrator'ı dispatch et, o phase'i ilerletsin
3. Faz status'u DONE veya başka bir aktif state'te ise → kullanıcıya bildir, doğru komutu öner

`orchestrator` Task'ını başlat:

```
subagent_type: orchestrator
description: Start phase {id}
prompt: User explicitly named phase {id} (per /start-phase command). Use that as the active phase per orchestrator.md §3 resolution rule #1. Validate, dispatch next agent.
```

User input: $ARGUMENTS

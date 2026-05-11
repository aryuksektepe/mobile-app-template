---
description: Proje durumunu özetle — phase index, aktif faz, outstanding security/perf/compliance items.
allowed-tools: Read, Glob, Bash
---

# /status

Proje durumunu özetle. Hiçbir agent dispatch etmez — sadece okur ve raporlar.

## Talimat

Şu dosyaları oku ve özetle:

1. `.project/phases/INDEX.md` → toplam faz, faz durumları (PLANNED/IN_PROGRESS/DONE), faz coverage
2. Her aktif faz için (status != DONE):
   - phase_id, title, status, owner_agent, last_updated
   - Acceptance criteria sayısı vs tick'li sayısı
   - Risk score
3. `.project/security-checklist.md` → outstanding HIGH/BLOCKER count
4. `.project/perf-checklist.md` → en son ölçüm tarihi + budget aşımı var mı
5. `.project/compliance-checklist.md` → outstanding BLOCK count + 🔍 needs human items
6. `.project/handoffs.md` → son 5 dispatch (orchestrator log)

Çıktı formatı (Türkçe, tablo + bullet karışımı):

```markdown
## 📊 Proje Durumu

**Aktif faz:** {id} - {title} ({status}) — {owner_agent}
**Toplam faz:** {N} ({M} DONE, {K} aktif, {L} planned)

### Outstanding
- Security: {N} BLOCKER, {M} HIGH
- Compliance: {N} BLOCK, {M} 🔍 needs human (lawyer)
- Performance: {N} measurement stale (>7d), {M} NFR violation
- Phase coverage: {X}/{Y} FRs mapped

### Son aktivite (son 5)
{from handoffs.md tail}

### Sıradaki
{infer from active phase status — next agent per orchestrator §4 dispatch table}
```

User input: $ARGUMENTS (yok sayılabilir — bu komut argümansız çalışır)

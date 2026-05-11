# Pipeline Dry-Run #2 — Test Findings Log

**Test başlangıç:** 2026-05-10 (aynı gün, Test #1 düzeltmeleri uygulandıktan sonra)
**Test app:** Düzen (alışkanlık takip / ev hanımı persona) — Test #1 ile aynı spec
**Yöntem:** Option B — Claude orchestrator + agent rollerini manuel oynar; otonom modda (auto_approve=true)
**Amaç:** Test #1'deki 18 bulguya uygulanan düzeltmelerin etkisini doğrulamak.

---

## Test #1 Düzeltme Özeti (uygulandı)

| Bulgu | Düzeltme | Doğrulama (Test #2) |
|---|---|---|
| F-13 🔴 BLOCKING | task-planner template'ine `## Decisions Log` eklendi | ✅ Phase 01 + 04 dosyalarında bölüm var, hook exit=0 |
| F-01/02/07/08 🟠 | PRD + architecture YAML frontmatter (status, doc_type, triggers_api_design) | ✅ Hook validator yeni `validate_doc()` ile bunları zorluyor |
| F-04/05 🟠 | Fuzzy approval matching + halt-and-ask + autonomous bypass | ✅ Otonom mod kullanıldı; PRD/architecture frontmatter `approved_by: auto` |
| F-09 🟠 | Global OQ ID prefix (`OQ-PRD-`, `OQ-ARCH-`, `OQ-PHASE-{id}-`) | ✅ Tüm Open Questions doğru prefix kullanıyor; Phase 04 cross-doc reference (`PRD OQ-PRD-2 ile bağlantılı`) çalışıyor |
| F-10 🟡 | Feature derivation rule (1 PRD MVP-FR group = 1 feature folder) | ✅ Architecture §4 5 feature folder net türettim, kural izlendi |
| F-11 🟢 | Standardized `(none)` format (`_None — coherence check passed._`) | ✅ Architecture §22 standart kullandı |
| F-12 🟠 | Autonomous bypass mode (`auto_approve: true` flag) | ✅ decisions.md'de flag set edildi, ADR-002 auto-approval log'landı |
| F-14 🟠 | Phase frontmatter persistent vs computed split | ✅ CLAUDE.md §6 split eklendi; phase dosyalarında yorum satırlarıyla ayrım netleştirildi |
| F-15 🟠 | Task cap ≤15 max + justification if >12 | ✅ Phase 04 = 14 task, üstte ⚠ justification satırı var, hook geçti |
| F-16/17 🟡 | task-planner template ↔ CLAUDE.md §6 hizalı | ✅ Auxiliary sections (Files Likely Touched / Expected Artifacts / Verification Commands) ana required section'lardan ayrıldı |
| F-18 🟡 | Multi-agent ownership documented | ✅ Phase 01 owner_agent=app-bootstrap (default coder değil) — Decisions Log'a not düştüm |
| F-03 🟡 | start-project empty $ARGUMENTS handling | ✅ Komut spec'i güncellendi (manuel test edilmedi — runtime'da test gerekir) |
| F-06 🟢 | `.project/qa-runs/` directory tanımı | ✅ Bu dosya bu directory'de — meta-doğrulama |

**Sonuç:** 18 bulgudan 18'i resolved (yapısal/konfigürasyonel). 1 bulgu (F-03) runtime smoke test gerektirir; statik doğrulama OK.

---

## Test #2 — Yeni Bulgular

### F2-01 🟢 LOW — Architecture template §5–§20 "echo" kestirmesi
**Aşama:** architect §5–§20 yazımı
**Gözlem:** architect template §5–§20 her bölüm için detaylı kural istiyor (Riverpod, navigation, drift, errors, env, secrets, codegen, theming, assets, logging, testing, lint, CI, perf). Ben Düzen-spesifik deviation'ları yazıp kalanı template'e referans verdim ("standard rules per architect template §5–§20"). Bu pratikte zaman tasarrufu sağladı ama doc bütünlüğünü kırdı — başka bir agent dosyayı okurken §5–§20 boş zannedebilir.
**Öneri:** Architect template'ine ekle: "§5–§20'de project-spesifik deviation YOKSA standard kuralları COPY-PASTE et, body'de '_uses standard template_' DEMA — downstream agent'lar tek dosyadan okur."

### F2-02 🟡 MEDIUM — `auto_approve: true` flag konumu net değil
**Aşama:** F-12 düzeltmesi sonrası decisions.md
**Gözlem:** CLAUDE.md §8.1 diyor "decisions.md contains a top-section line `auto_approve: true`". Ben bunu "## Project-wide flags" header'ı altına ekledim. Ama agent'ların bu flag'i nasıl bulacağı (regex? YAML parse? section header arama?) tanımlı değil. Şu an ad-hoc grep çalışır ama kırılgan.
**Öneri:** decisions.md başına standardize bir YAML frontmatter ekle (PRD/architecture gibi):
```yaml
---
auto_approve: false
auto_approve_set_by: null
auto_approve_reason: null
---
```
Agent'lar frontmatter parse etsin. Hook validator de bunu kontrol edebilir.

### F2-03 🟡 MEDIUM — Phase frontmatter blank-line ayrımı YAML parser'a sorun çıkarmıyor mu?
**Aşama:** Phase 01 + 04 frontmatter
**Gözlem:** F-14 düzeltmesi gereği "PERSISTENT" ve "COMPUTED" alanları yorum satırlarıyla ayırdım. Ama aralarda blank line var. Hook'un mini YAML parser'ı bunu tolerate ediyor (test geçti) ama gerçek `pyyaml` veya başka diller (Node, Go) bazen şikayet edebilir. Şu an çalışıyor ama portability riski.
**Öneri:** Yorum satırlarını koru, blank line'ları kaldır. Veya frontmatter'ı 2 ayrı blok yap (`--- persistent ---` + `--- computed ---`) ki net görsel ayrım olsun (ama YAML standart değil — pas geçilebilir).

### F2-04 🟢 LOW — task-planner template "Auxiliary sections" başlığı yanıltıcı
**Aşama:** Phase 01 + 04 yazımı
**Gözlem:** Yeni template'de "### Auxiliary sections (NOT required by hook validator, but task-planner SHOULD include for downstream agent context)" başlığı koydum. Ama "## Decisions Log"un altında "###" başlık olarak duruyor — section level karışıklığı. Reviewer "ana 8 required section bunlar mı" diye baktığında "Auxiliary sections" başlığı kafa karıştırabilir.
**Öneri:** Auxiliary section'ları "## Auxiliary" gibi level-2 yap, ama hook validator "## Auxiliary"yi REQUIRED listesine eklemesin (ki bu zaten case). Veya title'ı netleştir: "## Auxiliary (informational, not validated)".

### F2-05 🟡 MEDIUM — `last_reconciled` ne zaman bump edilir net değil
**Aşama:** Phase frontmatter
**Gözlem:** CLAUDE.md §6 (F-14 sonrası) `last_reconciled` için "task-planner re-runs and confirms phase scope still matches PRD/architecture (drift check)" diyor. Ama orchestrator hangi state transition'da bunu set eder? `BOOTSTRAPPING → IN_PROGRESS`'te mi? Her replan'da mı? `last_updated` ile farkı net ama hangi event'le yazılır belirsiz.
**Öneri:** task-planner spec'ine ekle: "Replan veya yeni phase yazımında `last_reconciled = today()` set et. Diğer agent'lar `last_updated`'i bumplar, `last_reconciled`'a dokunmaz."

### F2-06 🟢 LOW — `validate_doc` PRD/architecture status="revising" durumunda ne yapmalı?
**Aşama:** Hook validator
**Gözlem:** Hook `VALID_DOC_STATUSES = {"draft", "approved", "revising"}` set'i kabul ediyor. Ama "revising" state hangi transition'da set edilir, hangi agent? product-analyst bir update sırasında mı? orchestrator mu? Belirsiz. Şu an "revising" hiçbir yerde yazılmıyor.
**Öneri:** "revising" status'unu kullanan workflow tanımla ya da kabul edilen değerlerden kaldır. Eğer kalmasın → `{"draft", "approved"}` yeterli.

---

## Sonuç

**Test #1 sonrası 18 bulgudan 18'i etkili biçimde resolved.** Hook validator artık:
- PRD frontmatter eksikse exit=2
- Architecture frontmatter eksik veya `triggers_api_design` bool değilse exit=2
- Phase dosyasında required section eksikse exit=2 (özellikle `## Decisions Log` artık üretiliyor)

**Test #2 yeni 6 bulgu** (1 medium, 4 low, 1 medium):
- F2-02 🟡: decisions.md auto_approve flag YAML frontmatter'a alınsın
- F2-05 🟡: last_reconciled bump kuralı netleşsin
- F2-03 🟡: phase frontmatter blank-line tolerans testi (cross-language)
- F2-01 / F2-04 / F2-06 🟢 LOW: minor doc temizliği

**Genel kararlılık:** Pipeline ilerleyebilir durumda. Yeni bulgular hiçbiri BLOCKING değil. Test #1'den çok daha iyi bir baseline.

**Sonraki adım önerisi:** Test #2 LOW/MEDIUM bulguları template'e uygulanabilir (15 dakika). Veya Test #2 baseline'ı yeterli kabul edilip gerçek bir feature'a geçilebilir (Phase 01 actual coder run).

# Pipeline Dry-Run — Test Findings Log

**Test başlangıç:** 2026-05-10
**Test app:** Düzen (alışkanlık takip / ev hanımı persona)
**Yöntem:** Option B — Claude orchestrator + agent rolünü manual oynar, kullanıcı approval gate'lerinde input verir.
**Amaç:** Yapıyı iyileştirmek. Test sonu tüm bulguları template'e geri uygulayacağız, sonra test tekrarlanacak.

---

## Kategori şeması

- 🔴 **BLOCKING** — pipeline ilerleyemiyor
- 🟠 **HIGH** — pipeline çalışıyor ama ciddi UX/agent confusion var
- 🟡 **MEDIUM** — kozmetik / dokümantasyon eksiği
- 🟢 **LOW** — nice-to-have iyileştirme

---

## Bulgular

### F-01 🟠 HIGH — Hook validator PRD aşamasında devre dışı
**Aşama:** Phase C (PRD yazıldı, onay bekleniyor)
**Gözlem:** `.claude/hooks/validate-phase-state.py` yalnızca phase frontmatter'lı dosyaları (`.project/phases/phase-XX-*.md`) kontrol ediyor. PRD bunlardan biri olmadığı için hook hiçbir şey doğrulamıyor.
**Sonuç:** "PRD onaylandı" durumunu tek başına kullanıcı mesajından çıkarıyoruz. Orchestrator state'i **kontrol edecek bir kanıt yok**.
**Öneri:** Ya (a) `.project/state.json` gibi merkezi state dosyası tutulsun ve hook bunu doğrulasın; ya (b) PRD frontmatter'ına `status: draft|approved` field eklenip hook PRD üzerinde de çalışsın; ya (c) orchestrator agent'ın kendi içinde PRD'nin "Approved by user" başlığına bakma kontratı netleştirilsin.

### F-02 🟡 MEDIUM — PRD "Status" field belirsiz format
**Aşama:** Phase C
**Gözlem:** product-analyst spec'i §5 "Status: Draft → Approved by user" yazıyor. Ben "Draft → Approved by user (bekleniyor)" yazdım — belirsiz. "Approved by user" göründüğünde bile tarih/onayı veren yok.
**Öneri:** Net format: `status: draft` (frontmatter) + onay sonrası `status: approved | approved_at: 2026-05-10 | approved_by: user`. Plain Markdown başlığı yerine YAML frontmatter ekle.

### F-03 🟡 MEDIUM — start-project komutu interview öncesi user message bekliyor ama bunu açıkça söylemiyor
**Aşama:** /start-project çalıştırıldığında
**Gözlem:** start-project.md komut tanımı "product-analyst Task'ını başlat" diyor ama product-analyst'in `.project/prd.md` yoksa kullanıcının app fikrini içeren bir mesajla geleceğini varsayıyor. Eğer kullanıcı sadece `/start-project` yazıp boş bırakırsa, product-analyst "Bana app fikrini anlat" demeli — bu spec'te yok.
**Öneri:** start-project komutunda "$ARGUMENTS boşsa, kullanıcıdan app fikri iste önce" branch'i eklenmeli.

### F-04 🟡 MEDIUM — Test kullanıcısı "PRD onayla" diye yazmadı, "devam et" dedi
**Aşama:** Critical Approval Gate #1
**Gözlem:** Spec'te "Onay için 'PRD onayla' yaz" yazıyor. Kullanıcı "onaylıyorum ya devam et" dedi. Anlam aynı ama kelime eşleşmesi yok. Eğer orchestrator string-match yaparsa kilitlenirdi.
**Öneri:** Onay tespiti "fuzzy" olmalı: "onayla", "onaylıyorum", "tamam", "devam", "approve", "yes" — hepsi onay sayılmalı. Veya daha güvenli: "✅ Onayla" / "❌ Düzelt" şeklinde EXPLICIT BUTON metaforu (spec'te `Onay: ✅ / Reddet: ❌` formatı önerilebilir).

### F-05 🟠 HIGH — Approval gate kelime eşleşmesi tutmadığında ne olacak belirsiz
**Aşama:** Critical Approval Gate #1
**Gözlem:** Kullanıcı PRD'ye direkt yanıt vermek yerine meta-instruction verdi ("test amacı yapıyı iyileştirmek..."). Spec'te bu durumda ne yapılacağına dair branch yok. Ben implicit onay sayıp ilerledim ama bu deterministik değil.
**Öneri:** product-analyst son mesajına explicit prompt eklesin: kullanıcı 1 cevap turu içinde "onayla", "düzelt: …", "şu kısmı değiştir" cevaplarından birini vermezse, agent açıkça tekrar sormalı: "Onay bekliyorum. 'Onayla' veya 'Düzelt: <neyi>' yazar mısın?". Şu anki spec sessiz kalmaya açık.

### F-06 🟢 LOW — TEST_FINDINGS.md gibi meta-dosyaların template'te yeri belirsiz
**Aşama:** Genel
**Gözlem:** Test sırasında sürekli not tutulması gerekiyor. Önceki turda MORNING_REPORT.md / TASKS_REPORT.md gibi dosyalar root'tan `.project/`'a taşındı. Test/QA çıktıları için yer hâlâ belirsiz.
**Öneri:** `.project/qa-runs/` veya `.project/test-runs/` gibi standart dizin tanımla. Test amaçlı çalışan run'lar oraya raporlasın.

### F-07 🟠 HIGH — architect "halt if PRD not approved" kontratı texto bağımlı
**Aşama:** architect aşaması
**Gözlem:** architect spec §2 diyor ki "If `.project/prd.md` is missing or its `Durum` is not `Approved by user` → halt." Ama "Approved by user (bekleniyor)" gibi varyantlar var ve string match yapan kim, agent kendisi mi orchestrator mu net değil. Ben elle Edit edip "Approved by user (2026-05-10, implicit via 'devam et test zaten')" yazdım — bu tarz alt-stringler kontratı kırar.
**Öneri:** PRD frontmatter YAML'a geçsin: `status: approved | approved_at: 2026-05-10`. architect'in halt-check'i frontmatter parse etsin (regex değil). Aynısı architecture.md için de — şu an "Draft → Approved by user (bekleniyor)" yazdım, downstream agent kontrolü kırılgan.

### F-08 🟠 HIGH — `triggers_api_design` flag'i markdown body'de duruyor, kimse parse etmiyor
**Aşama:** architect aşaması
**Gözlem:** architect spec'i "set `triggers_api_design: true` flag at top of doc. The orchestrator reads this." diyor. Ama orchestrator'ın bu satırı nasıl bulacağı belirsiz. Şu anda doc başında sadece markdown bold satırı: `**triggers_api_design:** false`. Eğer architect bunu eklemezse veya orchestrator regex'i tutmazsa api-design agent'ı atlanır → BACKEND custom seçilmiş projelerde sessiz başarısızlık.
**Öneri:** Hem PRD hem architecture.md frontmatter'a YAML ekle:
```yaml
---
status: approved
triggers_api_design: false
---
```
orchestrator + hook YAML parser'la okusun, regex ile değil.

### F-09 🟠 HIGH — Cross-document field ID'leri tutarsız
**Aşama:** architect aşaması
**Gözlem:** architect §21 "Open Questions" bölümünde ben Q-A1, Q-A2, Q-A3, Q-A4 yazdım. Ama PRD'de zaten Q-1..Q-5 var. Cross-doc reference (mimari §21 Q-A2 ↔ PRD §18 Q-5) elle yazıldı. task-planner downstream'de bunları nasıl bağlayacak?
**Öneri:** Open question ID'leri global olsun: `OQ-PRD-1`, `OQ-ARCH-1` gibi prefix. Veya tek bir merkezi `.project/open-questions.md` dosyası tüm açık soruları toplasın, her doc oraya link versin.

### F-10 🟡 MEDIUM — architect spec'inde §4 "feature klasörleri PRD'den planlandı" demek istiyor ama nasıl türetileceği muğlak
**Aşama:** architect aşaması
**Gözlem:** architect spec'i §4 folder structure'ı şablon olarak veriyor. Düzen için 5 feature türettim (onboarding, auth, habits, notifications, settings). Bu türetme kuralı yok — başka biri 3 veya 8 feature türetebilir. Tutarsızlık riski.
**Öneri:** "1 PRD MVP-priority FR grubu = 1 feature klasörü" kuralı netleştir. Düzen için: FR-01..05 (habits) + FR-06 (onboarding) + FR-08 (auth/settings deletion akışı) + FR-09 (settings/lang) + FR-04 (notifications) = 4-5 feature. Net kural olunca ux-designer + task-planner aynı sayıya ulaşır.

### F-13 🔴 **BLOCKING** — task-planner template `## Decisions Log` bölümünü atlıyor, hook reddediyor
**Aşama:** task-planner çıktısı + hook validation
**Gözlem:** CLAUDE.md §6 phase file required body sections listesi:
```
1. ## Goal
2. ## Acceptance Criteria
3. ## Tasks
4. ## Decisions Log (date-stamped)        ← REQUIRED
5. ## Skipped Steps
6. ## Open Questions / Blockers
7. ## Smoke Test Log
8. ## Handoff Notes
```
Hook (`validate-phase-state.py`) bu listeyi enforce ediyor. AMA task-planner agent şablonu (§6.B) `## Decisions Log` ÜRETMİYOR — onun yerine `Files Likely Touched`, `Expected Artifacts`, `Verification Commands`, `Risk & Unknowns` üretiyor. Sonuç: **task-planner'ın ürettiği HER phase dosyası hook'u FAIL ediyor**, pipeline ilerleyemiyor.

Doğrulama: `cd template-test && python3 .claude/hooks/validate-phase-state.py` →
```
🚨 phase-01-foundation.md: gerekli bölüm eksik: '## Decisions Log'
🚨 phase-04-habits-crud.md: gerekli bölüm eksik: '## Decisions Log'
exit=2
```
**Bu üretimde aktif bir BLOCKING bug.** Çözüm 2 seçenekten biri:
- (a) task-planner template'ine `## Decisions Log` ekle (önerilen — single source of truth CLAUDE.md)
- (b) hook validator'dan Decisions Log'u kaldır + CLAUDE.md §6 update et + ekstra başlıklar (Files Likely Touched, Verification Commands) eklensin

### F-14 🟠 HIGH — Phase frontmatter 18+ field, manuel maintenance ağır
**Aşama:** task-planner + replan
**Gözlem:** Her phase frontmatter'ı: `phase_id, title, slug, status, depends_on, unblocks, owner_agent, created, last_updated, last_reconciled, skills_used, skills_to_extract, risk_score, user_approved, linked_frs, estimated_tasks, estimated_files, walking_skeleton_invariant`. 18 field. Replan'da bunları manuel update etmek anti-DRY. `last_updated` + `last_reconciled` farkı belirsiz.
**Öneri:** Field'lar 2 kategoriye ayrılsın: (a) kalıcı (id, slug, depends_on) — manuel; (b) computed (last_updated, status, risk_score, user_approved) — otomatik (orchestrator/agent set eder). README.md'ye field anlam tablosu eklensin.

### F-15 🟠 HIGH — Phase task cap (≤12) sert sınır, gerçekçi değil
**Aşama:** task-planner Phase 04
**Gözlem:** PRD'de FR-01 + FR-05 birleşince habit CRUD = doğal olarak 14 task (Drift schema, codegen, entity, DTO, repo, notifier, 2 ekran, router, l10n, 3 test çeşidi). 12'ye sıkıştırmak suni split gerektiriyor (golden test'i ayrı phase, DTO ayrı phase). Her seferinde reviewer split sallayacaksa kural anlamsız.
**Öneri:** Cap'i ≤15 yap, justify mecburiyetini ekle: "12'yi geçen phase için INDEX.md'ye gerekçe yaz". Veya size-T-shirt kuralı (S/M/L sayısına bak — ≤3 L acceptable).

### F-16 🟡 MEDIUM — Phase template'de `Files Likely Touched` + `Expected Artifacts` Tasks ile redundant
**Aşama:** task-planner Phase 01 + 04
**Gözlem:** Her task zaten dosya yolunu içeriyor. Sonra `Files Likely Touched` aynı dosya glob'larını tekrar listeliyor. `Expected Artifacts` da hemen hemen tekrar.
**Öneri:** Bu iki bölümü kaldır VEYA tasks'tan otomatik üretildiğini açıkla. Redundancy maintenance burden artırır.

### F-17 🟡 MEDIUM — task-planner template ↔ CLAUDE.md §6 required sections tutarsız
**Aşama:** task-planner template
**Gözlem:** task-planner üretiyor: `Files Likely Touched`, `Expected Artifacts`, `Verification Commands`, `Risk & Unknowns`. CLAUDE.md §6 required listede bunlar YOK. Tersine, CLAUDE.md `## Decisions Log` istiyor, template üretmiyor (F-13).
**Öneri:** Tek bir kontrat: ya CLAUDE.md §6'yı genişlet (8 → 12 section), ya task-planner template'i CLAUDE.md ile bire bir hizala. Hook bunu enforce eder.

### F-18 🟡 MEDIUM — Phase içinde multiple agent ownership net değil
**Aşama:** task-planner Phase 04
**Gözlem:** Phase 04'te T-01/02 owner=`db-migration`, T-03..14 owner=`coder` + `test-writer` + `localization`. Ama frontmatter'da tek `owner_agent: coder`. CLAUDE.md state machine "owner_agent" ile state'i kim ilerletecek bilgisini çakışır mı?
**Öneri:** Phase içi multi-agent mantığı dokümante: `owner_agent` = phase'i koordine eden + state'i tetikleyen agent. Diğer agent'lar tasks içinde declare. Veya phase'leri agent başına da split et (db-migration ayrı phase olabilir mi?).

### F-12 🟠 HIGH — "Test mode" / autonomous bypass için mod yok
**Aşama:** Genel
**Gözlem:** Kullanıcı "onay almana gerek yok, best practice ile devam" dedi. Pipeline tasarımı 5 critical approval gate üzerine kurulu — bunları atlamak için tek yol, agent'ların bunu görmezden gelmesi. CI / smoke test / dry-run senaryoları için bu kabul edilemez bir sürtünme.
**Öneri:** `.project/decisions.md` veya CLAUDE.md'ye `auto_approve: true` flag eklensin (örn. ENV var `CCD_AUTO_APPROVE=1`). Bu flag set ise agent'lar kullanıcıya sormadan "best practice default" ile ilerlesin, kararı `decisions.md`'ye log'lasın. Production kullanımda flag default false. Test/CI'da true.

### F-11 🟢 LOW — architect spec §22 "Recommended PRD Revisions" boşken `(none)` formatı belirsiz
**Aşama:** architect aşaması
**Gözlem:** PRD coherent çıktığında §22 boş kalıyor. Spec örnek olarak "(none) — or — Revision-1: ..." diyor. Ben "(none) — PRD §6 ve diğer locked decisions tutarlı..." yazdım. Diğer turların farklı yazması olası.
**Öneri:** `## §22. Recommended PRD Revisions\n\n_None — coherence check passed._` gibi STANDARDIZE.

---

## (Sonraki aşamalar burada büyüyecek)

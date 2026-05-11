# Pipeline Dry-Run #3 — Test Findings Log

**Test başlangıç:** 2026-05-10 (Test #2 düzeltmeleri uygulandıktan sonra)
**Test app:** Düzen — aynı spec
**Yöntem:** Otonom mod, decisions.md `auto_approve: true`
**Amaç:** Test #2'nin 6 yeni bulgusuna uygulanan F2 düzeltmelerinin doğrulanması.

---

## Test #2 Düzeltme Özeti (uygulandı)

| Bulgu | Düzeltme | Test #3 doğrulaması |
|---|---|---|
| F2-01 🟢 | architect template'e copy-paste kuralı (§5–§20 inline) | ✅ architecture.md §5–§20 inline yazıldı, downstream agent tek dosyadan okuyabilir |
| F2-02 🟡 | decisions.md YAML frontmatter (auto_approve flag) + hook validation | ✅ `validate_decisions()` hook'a eklendi; auto_approve=true ile pipeline ilerledi |
| F2-03 🟡 | Phase frontmatter blank-line YAML compatibility test | ✅ Ruby YAML 1.2 parser ile test edildi → blank-line + comment fully compliant; **false alarm**, action gerekmedi |
| F2-04 🟢 | "Auxiliary sections" → `## Auxiliary` level-2 başlık | ✅ Phase 01 + 04'te `## Auxiliary (informational, not validated by hook)` formatında |
| F2-05 🟡 | last_reconciled bump kuralı CLAUDE.md §6'da netleşti | ✅ CLAUDE.md "Other agents MUST NOT touch this field" eklendi |
| F2-06 🟢 | "revising" status kaldırıldı | ✅ Hook VALID_DOC_STATUSES = {"draft", "approved"}; product-analyst + architect template'lerinden silindi |

**Bonus düzeltme (Test #3 sırasında ortaya çıktı):**
- Hook `parse_frontmatter` mini parser inline `# yorum` strip etmiyordu → `false  # comment` string olarak parse'lanıyordu. `_strip_inline_comment()` helper eklendi (quoted-string aware). Production-grade YAML parser değil ama bu pipeline için yeterli ve standart YAML davranışıyla uyumlu.

---

## Test #3 — Yeni Bulgular

(Hiç BLOCKING / HIGH yok.)

### F3-01 🟢 LOW — `parse_frontmatter` mini parser üretim ortamı için yeterince robust mu?
**Aşama:** Hook validator bonus fix sırasında
**Gözlem:** Mini parser şu an: blank line, `#` yorum (full-line + inline), bool, null, list (`[a, b]`), quoted string handle ediyor. Multi-line string, nested map, anchor/alias YOK. Pipeline için yeterli ama eğer ileride frontmatter'a multi-line `walking_skeleton_invariant` (üç satır) gerekirse parser kırılır.
**Öneri:** Şu an action gerekmiyor (kullanım case'i basit). Multi-line ihtiyacı çıkarsa `pyyaml` dep'i ekle (system Python'da default yok; venv ya da `--break-system-packages` ile).

### F3-02 🟢 LOW — Hook test senaryoları yok
**Aşama:** Genel
**Gözlem:** `validate-phase-state.py` 250+ satır, ama unit test yok. Test #1-3 boyunca manuel test ettim ama regression riski var (örneğin gelecekte `_strip_inline_comment`'ı değiştiren biri quoted-string case'ini kıramaz mı?).
**Öneri:** `.claude/hooks/test_validate_phase_state.py` ekle — fixture-based: 4-5 örnek frontmatter (good, missing-key, wrong-status, inline-comment, list-empty) ile assert. CI'da `pytest .claude/hooks/` çalışsın.

### F3-03 🟢 LOW — Test klasörü cleanup zamanı
**Aşama:** Genel
**Gözlem:** `/Users/aryuksektepe/Developer/template-test-2026-05-10/` 3 test çalıştırması sonrası `qa-runs/` 3 rapor topladı. User "test sonrası sileriz" demişti. Pipeline yapı testleri stabil — gerçek feature build'e geçilebilir veya klasör silinebilir.
**Öneri:** Kullanıcıya cleanup için sor, ya da test-03 raporunu template repo'sundaki `qa-runs/` örnekleri olarak taşı (öğretici).

---

## Sonuç

**Test #2 sonrası 6 bulgudan 6'sı resolved** (1 false alarm, 5 gerçek düzeltme + 1 bonus parser fix).

**Test #3 yeni 3 bulgu — tümü 🟢 LOW** ve hiçbiri pipeline'ı etkilemiyor:
- F3-01: parser robustness future concern
- F3-02: hook için unit test yok (CI hijyeni)
- F3-03: test klasörü cleanup

**Genel kararlılık:** Pipeline production-ready. Hook validator artık 4 kategori doğruluyor:
1. PRD frontmatter (status, doc_type, app_name, version)
2. architecture frontmatter (yukarıdakiler + triggers_api_design bool)
3. decisions.md frontmatter (auto_approve bool)
4. Phase dosyaları (frontmatter required keys, status enum, owner_agent matching, 8 required body sections including ## Decisions Log)

Inline `#` yorum stripping fix'i ile production'da quoted/unquoted scalar değerler doğru parse oluyor.

**Sonraki adım önerisi:**
- (a) Test klasörünü sil + gerçek bir mobil app projesinde `/start-project` ile gerçek run yap
- (b) F3-02 düzelt (hook için pytest fixtures) ve `.claude/settings.json`'a CI hook ekle
- (c) Pipeline yapısı yeterince stabil — başka bir konuya geç (skill catalog genişletme, ASO research, vb.)

# Mobile App Development Template (Flutter)

> Production-grade Flutter (iOS + Android) mobil uygulama geliştirme template'i.
> 23 specialized AI subagent + state-machine pipeline + skill-based knowledge accumulation.

> **Bu repo bir kurs materyalidir.** *Claude Code ile Yazılım Geliştirme* kursunun
> **Bölüm 11**'inde (Capstone 2 — Flutter üretim pipeline'ı) ekranda incelenen sistem budur.
> Kursu izlemiyorsanız da kullanabilirsiniz; template kendi başına çalışır. Kurstaysanız
> bölüm boyunca burayı açık tutmanız yeterli, klonlamak zorunda değilsiniz.

---

## Ne işe yarar?

Bu template, Claude Code ile çalışan **23 subagent** içerir. Her agent net bir aşamaya bağlı:
- Planlama (PRD → mimari → UX → faz planı)
- Implementation (foundation scaffold → coder → test-writer)
- Quality gates (code review → bug hunt → security → performance → compliance → localization)
- Verification (QA smoke test — kullanıcı cihazda)
- Knowledge capture (feature chronicler → skill extractor)
- Release (ASO → release manager)

Hiçbir adım atlanmıyor (CI hook + state machine), kullanıcı sadece **5 kritik onay noktasında** durduruluyor:
1. PRD onayı
2. Mimari + tech stack onayı
3. Faz planı onayı
4. Her fazın smoke test onayı
5. Release go/no-go

## Hızlı Başlangıç

### Yeni proje açma (template kullanarak)

```bash
# GitHub'da template repo'dan yeni repo aç:
gh repo create my-new-app --template=<your-org>/mobile-app-development-templates --private --clone

# Veya web'den: GitHub → "Use this template" → Create new repository

cd my-new-app

# Claude Code aç ve başlat
claude  # veya açıksa /clear
```

Claude Code açıldıktan sonra:

```
/start-project
```

→ product-analyst seninle PRD'yi konuşur, sonra orchestrator pipeline'ı yürütür.

### Mevcut bir projeye agent eklemek

Bu template'in `.claude/`, `.project/`, `CLAUDE.md` dosyalarını mevcut Flutter projene kopyala, sonra `/start-project` veya `/continue` ile başlat.

## Tech Stack (default)

Detay: [CLAUDE.md §2](CLAUDE.md#2-tech-stack-default)

| Layer | Choice |
|---|---|
| Framework | Flutter (latest stable) |
| State | Riverpod (`@riverpod` codegen) |
| Navigation | go_router |
| Networking | dio + retry |
| Models | freezed + json_serializable |
| Local DB | Drift |
| Secure Storage | flutter_secure_storage |
| Auth (default) | Firebase Auth |
| Push | firebase_messaging + flutter_local_notifications |
| Crash | firebase_crashlytics + sentry_flutter |
| Payments | RevenueCat |
| i18n | flutter gen-l10n |
| Testing | flutter_test, mocktail, integration_test, alchemist |
| CI/CD | GitHub Actions + Fastlane |

## Klasör Yapısı

```
mobile-app-development-templates/
├── CLAUDE.md                       # Sistemin anayasası — her agent okur
├── README.md                       # Bu dosya
├── .gitignore
├── .claude/
│   ├── settings.json               # Permissions, hooks
│   ├── agents/                     # 23 agent definition
│   ├── commands/                   # Slash commands (/start-project, /continue, ...)
│   ├── skills/                     # Reusable knowledge — büyür zamanla
│   │   └── INDEX.md                # coder ZORUNLU bunu okur
│   └── hooks/
│       ├── validate-phase-state.py # Stop/SubagentStop'ta faz state validator (36 test)
│       └── guard-tool-use.py       # PreToolUse: agent prohibition'larını mekanik zorlar (16 test)
├── .project/                       # Living project knowledge
│   ├── README.md
│   ├── prd.md                      # (oluşturulacak — product-analyst)
│   ├── architecture.md             # (oluşturulacak — architect)
│   ├── design-system.md            # (oluşturulacak — ux-designer)
│   ├── layouts.md                  # (oluşturulacak — ux-designer)
│   ├── features.md                 # (oluşturulacak — feature-chronicler)
│   ├── security-checklist.md       # (rolling — security-reviewer)
│   ├── perf-checklist.md           # (rolling — performance-reviewer)
│   ├── compliance-checklist.md     # (rolling — compliance)
│   ├── decisions.md                # ADR log
│   ├── known-issues.md             # WONTFIX entries
│   ├── handoffs.md                 # JSONL append-only log
│   ├── phases/                     # Per-phase files
│   │   ├── INDEX.md                # Phase board
│   │   └── phase-XX-{slug}.md      # task-planner ekler
│   ├── api/                        # OpenAPI (only if custom backend)
│   ├── references/                 # External rule docs
│   │   ├── appstore-guidelines.md
│   │   └── playstore-guidelines.md
│   ├── legal/                      # Templates (lawyer fills)
│   ├── perf-snapshots/             # User-pasted measurements
│   ├── l10n-deltas/                # TMS export
│   ├── aso/                        # App Store Optimization
│   └── release-notes/              # Per-release per-locale
├── lib/                            # (app-bootstrap creates)
├── test/
├── integration_test/
├── ios/                            # (flutter create)
├── android/                        # (flutter create)
└── pubspec.yaml                    # (app-bootstrap)
```

## Pipeline Akışı

CLAUDE.md §3'te tam state machine:

```
DRAFT → PLANNED → BOOTSTRAPPING → IN_PROGRESS → TESTS_WRITTEN
      → CODE_REVIEW → [BUG_HUNT] → SECURITY_REVIEW → PERFORMANCE_REVIEW
      → INTEGRATION_SMOKE → COMPLIANCE_CHECK → QA_SMOKE_TEST → USER_APPROVAL
      → CHRONICLED → SKILL_EXTRACTED → DONE
```

Her agent state'i okur, çalışır, frontmatter'ı günceller, orchestrator sıradakini dispatch eder.

**`INTEGRATION_SMOKE` — runtime gate (asla atlanmaz):** Compliance ve QA, *gerçekten build edilip boot etmiş ve gerçek backend'e karşı çalıştırılmış* bir uygulama üzerinde çalışsın diye `COMPLIANCE_CHECK`'ten önce gelir. Statik gate'ler (`flutter analyze` + mock'lu testler + line coverage) çalışan bir uygulama değildir; bu gate gerçek `flutter build` + emülatörde `BOOT_OK` + mock'suz uçtan-uca backend akışı kanıtı ister. Detay: [CLAUDE.md §3](CLAUDE.md#3-the-pipeline--phase-state-machine).

## Slash Commands

| Komut | Ne yapar |
|---|---|
| `/start-project` | Yeni proje — PRD → architecture → UX → faz planı |
| `/continue` | Pipeline'ı bir adım ilerlet |
| `/start-phase {id}` | Belirli bir fazı başlat |
| `/report-bug` | Dış bug raporunu triage et |
| `/extract-skill {phase-id?}` | Manuel skill extraction |
| `/skill-freshness` | Skill pinlerini pub.dev'e karşı denetle (aylık önerilir) |
| `/ship` | Release pipeline |
| `/status` | Proje durumu özeti |

## Agent Modelleri (cost vs quality)

| Agent grubu | Model | Gerekçe |
|---|---|---|
| Orchestrator | sonnet | En sık çağrılan agent; routing mekanik — gate zorlaması hook'larda (gerekirse opus'a pinlenebilir, bkz. orchestrator.md) |
| Architect, Product Analyst, Task Planner, API Design | opus | Mimari hatalar her yere yayılır |
| Coder | sonnet | Workhorse default |
| Reviewers (Code, Security, Performance, Bug Hunt) | opus | Verification bottleneck |
| Compliance | sonnet | Kural-listesi yürütme (jurisdiksiyon kontrol listeleri), yaratıcı muhakeme değil |
| Test Writer, QA Test Guide, DB Migration, Crash Monitor | sonnet | Disiplinli + yaratıcı |
| App Bootstrap, UX Designer | sonnet | Yapı + yaratıcı karışım |
| ASO, Bug Report Handler | sonnet | Yazım + triage |
| Feature Chronicler, Localization | haiku | Düşük-muhakeme metin dönüşümü (changelog dili, ARB anahtarları) |
| Skill Extractor | opus | Yanlış extract pahalı (kalıcı) |
| Release Manager | opus | Production'a son kapı |

## Onay Noktaları (sadece bunlarda durulur)

1. **PRD onayı** (product-analyst sonrası)
2. **Mimari + tech stack onayı** (architect sonrası)
3. **Faz planı onayı** (task-planner sonrası)
4. **Her fazın smoke test onayı** (qa-test-guide sonrası)
5. **Release go/no-go** (release-manager öncesi)

Diğer tüm geçişler otomatik. Hook + orchestrator state validator hiçbir adımın atlanmasına izin vermiyor.

## Skill Sistemi (Token Tasarrufu)

Her coder turu önce `.claude/skills/INDEX.md` okur. Match varsa o skill'i uygular. Yoksa scratch'ten yapar, sonunda `skill-extractor` reusable mı diye bakar — uygunsa kalıcılaştırır.

Zamanla bu klasör birikir → her yeni projede aynı şeyleri sıfırdan yapmak yerine var olan skill'lere döner. Token tasarrufu + tutarlılık.

## Quality Bar

CLAUDE.md §9'da tam liste. Özet:

- **Code:** null-safety, const constructors, no setState (Riverpod arch), dispose discipline, no hardcoded strings (l10n)
- **Testing:** ≥70% coverage, Mocktail, Alchemist (golden), integration_test
- **Security:** OWASP MASVS L1+ (L2 fintech), no secrets in repo, cert pinning prod, biometric reauth, ATT/Privacy Manifest
- **Compliance:** KVKK + GDPR + Apple ATT + Play DS + account deletion (Apple+Google policy)
- **Performance:** cold start <2s, 60fps scroll, app size <50MB, crash-free ≥99.5%

## Cybersecurity (özellikle vurgulanan)

Her fazda **security-reviewer ZORUNLU** çalışır (skip yok). Pre-release modunda ek "penetration mindset" check'leri:
- Decompile inspection (obfuscation çalışıyor mu)
- gitleaks history scan
- Dependency vulnerability scan
- Auth boundary matrix
- Cert pinning live test
- Deep link fuzz

Detay: `.claude/agents/security-reviewer.md`

## Smoke Test Disiplini

Her faz `QA_SMOKE_TEST` state'inde durur. **qa-test-guide** 5-8 senaryo üretir (golden path + edge + lifecycle + a11y + phase-specific). Sen cihazda çalıştırırsın, YAML'da PASS/FAIL/BLOCKED işaretlersin, geri yapıştırırsın. Hepsi PASS → faz CHRONICLED. Herhangi FAIL → bug-hunter'a yönlenir.

## Marketing-Ready Output

Her faz sonunda **feature-chronicler** `.project/features.md`'ye user-benefit dilinde yazıyor. Proje sonunda bu dosya doğrudan App Store description'a + reklam metnine kopyalanabilir hale geliyor.

**aso** agent metadata'yı (App Store + Play Store) her ikisi için + locale'ler için hazırlıyor.

## Geliştirme

Bu template kendi içinde bir Flutter projesi DEĞİL — boş başlar. İlk fazda `app-bootstrap` agent'ı `flutter create` çalıştırır.

## Güncelleme

Template'e yeni skill veya agent ekledikçe: kendi GitHub template repo'nu güncelle. Eski projeler `git remote add template <url>` ile cherry-pick edebilir.

## Lisans

Template (this repo): MIT
Agent prompt'ları: Free to use, modify, share
Üretilen proje kodu: Senin (template'in kullanım modeli budur)

## İlgili kaynaklar

- [Claude Code Subagents docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Skills docs](https://code.claude.com/docs/en/skills)
- [Flutter docs](https://docs.flutter.dev)
- [Riverpod docs](https://riverpod.dev)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)

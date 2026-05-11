---
description: Kicks off a new project — runs product-analyst (PRD), then architect, then ux-designer, then task-planner. Stops at each critical approval gate.
allowed-tools: Task, Read, Write, Edit
---

# /start-project

Bu komut yeni bir proje başlatır. PRD'den faz planına kadar tüm planlama aşamalarını sırasıyla yürütür.

## Akış

1. **product-analyst** çalışır → `.project/prd.md` üretir → **kritik onay** (PRD onayı)
2. **architect** çalışır (PRD onaylandıktan sonra) → `.project/architecture.md` üretir → **kritik onay** (mimari onayı)
3. **ux-designer** çalışır (architect onaylandıktan sonra) → `.project/design-system.md` + `.project/layouts.md` üretir → kullanıcı onayı (kritik değil ama beklenir)
4. **task-planner** çalışır → `.project/phases/` dosyalarını üretir → **kritik onay** (faz planı onayı)

## Talimat

Sıradaki adımı belirle:

**ÖZEL DURUM — `.project/prd.md` yoksa:**
- Eğer `$ARGUMENTS` boş VEYA çok kısa (<20 char) ise → `product-analyst` Task'ını başlatma. Bunun yerine kullanıcıya tek bir mesaj gönder: "Hangi uygulamayı yapmak istiyorsun? Bir-iki cümlede anlat (kim için, ne işe yarayacak, en önemli 1-2 özellik). Sonra PRD interview'ına geçeceğim." Sonra dur.
- Eğer `$ARGUMENTS` doluysa → `product-analyst` Task'ını başlat, kullanıcının fikrini prompt'a ekle.

**Diğer durumlar (frontmatter status alanını OKU — gövdeyi regex ile tarama):**

- PRD var ama frontmatter `status` ≠ `approved` ise → durdur, kullanıcıdan onay iste
- PRD onaylı (`status: approved`), `.project/architecture.md` yoksa → `architect` Task'ını başlat
- architecture var ama frontmatter `status` ≠ `approved` ise → durdur, onay iste
- architecture onaylı, `.project/design-system.md` yoksa → `ux-designer` Task'ını başlat
- design-system var ama kullanıcı reddetti / değişiklik istiyor → ona göre yönlendir
- design-system OK, `.project/phases/INDEX.md` yoksa → `task-planner` Task'ını başlat
- phases var ama onaylı değil → durdur, onay iste
- Hepsi onaylı → `/continue` çalıştır mesajı ver

**Otonom mod (F-12):** Eğer `.project/decisions.md` içinde `auto_approve: true` flag'i varsa veya kullanıcı bu konuşmada açıkça "onay almana gerek yok" / "best practice ile devam" benzeri talimat verdiyse → onay gate'lerinde durmadan ilerle, her geçilen gate'i `.project/decisions.md`'ye `auto-approved-at: <date> by: agent-name reason: AUTO_APPROVE_FLAG_SET` olarak log'la.

User input: $ARGUMENTS

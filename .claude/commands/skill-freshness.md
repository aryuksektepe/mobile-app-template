---
description: Skill kütüphanesi tazelik auditi — tüm package_versions pinlerini pub.dev'e karşı tara, STALE/MAJOR-drift skill'leri raporla. Aylık çalıştırılması önerilir.
allowed-tools: Read, Edit, Bash, Glob, Grep, WebFetch
---

# /skill-freshness

Skill kütüphanesindeki sürüm pinlerinin gerçeklikten ne kadar koptuğunu ölçer ve raporlar (INDEX.md freshness rule / ADR-016'nın kütüphane-geneli denetimi). SDK'lar yürür, pinler durur — bu komut driftin sessizce birikmesini engeller.

## Talimat

1. **Topla:** `.claude/skills/*/SKILL.md` dosyalarından frontmatter'daki `package_versions:` map'lerini ve `last_verified:` tarihlerini çıkar (`_example-skill-template` hariç). Aynı paketi pinleyen TÜM skill'leri grupla (skill-arası çakışma tespiti için).

2. **Doğrula:** her benzersiz paket için `https://pub.dev/api/packages/<name>` çek (Bash `curl -s` veya WebFetch), `latest.version`'ı al. Erişilemeyen paket → `FETCH_FAIL` olarak işaretle, uydurma.

3. **Sınıflandır (paket bazında):**
   - `OK` — pin caret aralığı latest'i kapsıyor (aynı major)
   - `MINOR-DRIFT` — aynı major ama pin minimumu belirgin geride (bilgi amaçlı)
   - `MAJOR-DRIFT` — latest farklı major'da → skill'in snippet'leri kırılmış olabilir
   - `CONFLICT` — iki skill aynı paketi farklı major'a pinliyor (pubspec çözülemez)

4. **Raporla (Türkçe, tablo):** `paket | pinleyen skill'ler | pin | latest | durum`. Ardından: `last_verified` >90 gün olan skill'lerin listesi (bugünün tarihine göre hesapla — `date +%F`).

5. **Uygula (yalnızca güvenli işlemler):**
   - `CONFLICT` → pinleri canonical skill'e hizala (hangisinin canonical olduğunu `depends_on` yönü belirler), düzeltilen SKILL.md'ye tek satır gerekçe yorumu ekle.
   - `MAJOR-DRIFT` → **pini KÖRLEMESİNE BUMP'LAMA.** Skill'in SKILL.md metadata bölümüne `⚠️ STALE (major drift: X→Y, YYYY-MM-DD)` notu ekle; CHANGELOG doğrulaması + snippet uyarlaması ayrı bilinçli iştir (coder ilk kullanımda yapar — INDEX freshness rule).
   - Pini `OK` çıkan ve içeriği değişmeyen skill'lerde `last_verified`'ı bugüne bump'la (pin doğrulaması yapıldı — dürüst bump).
6. **Kapanış:** özet (kaç OK / drift / conflict / stale) + değişen dosyalar. Kullanıcı onayı olmadan commit ETME.

User input: $ARGUMENTS

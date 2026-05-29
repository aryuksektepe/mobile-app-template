# iOS 26 Release-Only Physical — Verification Checklist

For `qa-test-guide` + `INTEGRATION_SMOKE` runtime gate operators.

```
[ ] Cihaz iOS 18.4+ (Settings → General → About → iOS Version)
[ ] Cihaz Xcode'a tanıdık (Window → Devices and Simulators → "✓ Connected")
[ ] Provisioning profile valid (Xcode → Signing & Capabilities → "Automatically manage signing")
[ ] .env mevcut, secrets dolu (SUPABASE_URL, GOOGLE_SERVER_CLIENT_ID, etc.)
[ ] ./snippets/install-ios-release.sh çalıştı, "✓ Installed" gördüm
[ ] Cihazdan Home screen tap → app açıldı (beyaz ekran YOK, crash YOK)
[ ] Splash → ilk gerçek ekran geçişi pürüzsüz (BOOT_OK eşdeğeri davranış)
[ ] Phase'in PRD-FR'larından ≥1 e2e flow gerçek backend ile çalıştı
[ ] HTTP trace + DB row evidence phase archive'a yapıştırıldı
[ ] Crash log retrieval workflow biliniyor:
    Settings → Privacy & Security → Analytics & Improvements → Analytics Data
    → Runner-*.ips → AirDrop / Share → Finder ile /tmp/'ye kopyala
[ ] (Opsiyonel) idevicesyslog grep ile cihaz log'u alındı
```

## Eğer cihaz yoksa

- Simulator + debug ile yap, phase notunda `physical device unavailable, simulator smoke only` işaretle
- Release-mode davranışı simulator'da farklıdır (ARM-only release iOS sim'de çalışmaz) — production fidelity için cihaz şart, smoke için simulator yeterli olabilir

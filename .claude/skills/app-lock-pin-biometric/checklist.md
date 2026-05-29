# App Lock — Cihazda Test Matrisi

10 madde. Cihazda gerçek manuel test, simulator yeterli değil (Face ID yok, lifecycle farklı).

```
[ ] Settings → Uygulama Kilidi aç → PIN kur (4-8 hane), confirm + biometric opt-in
[ ] App background → foreground → PIN screen + biometric prompt TEK SEFER (loop yok)
[ ] Cold-start (kill + tekrar aç): kilitli açılır, content flash YOK (preInitCover çalışıyor)
[ ] iOS app-switcher kartı: blur/lock overlay görünür (privacy cover)
[ ] 3 yanlış PIN → lockout countdown başlar → sayaç her saniye azalır (Timer.periodic OK)
                  → süre dolunca PIN pad auto-enable
[ ] "PIN unuttum" → signOut → clearOnSignOut() → re-login → kilit YOK
                  (storage temizlendi, yeni kullanıcı eski PIN'i miras almıyor)
[ ] Settings'te biometric toggle anlık çalışır (Consumer ile sarılmış modal)
[ ] Onboarding/login akışında kilit ekranı ASLA çıkmaz (session-gated)
[ ] iOS Face ID device'da ikon `Icons.face_rounded` (NOT fingerprint)
    Android fingerprint device'da ikon `Icons.fingerprint_rounded`
[ ] Android: MainActivity FlutterFragmentActivity extend ediyor (BiometricPrompt çalışır)
```

## iOS 26 transient biometric ekstra test

```
[ ] Cold-start sonrası ilk biometric prompt false dönerse:
    → PIN pad otomatik göster (auto-fallback)
    → sol-alt biometric ikona basınca retry (manuel)
    → bu davranış "iOS 26 transient bug" — Apple radar
```

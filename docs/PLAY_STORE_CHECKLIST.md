# PlanToPlate — Play Store hazırlık kontrol listesi

## Güvenlik / anahtarlar
- [x] `.env` dosyası **APK asset’i değil** (pubspec’te yok); anahtarlar `--dart-define-from-file=.env` ile veriliyor
- [ ] `.env` içinde yayın için doldur:
  - `GEMINI_API_KEY` (AI)
  - `REVENUECAT_API_KEY` (public Android key)
  - `ADMOB_BANNER_AD_UNIT_ID` / `ADMOB_REWARDED_AD_UNIT_ID` (release birimleri)
  - `SENTRY_DSN` (crash)
  - `PRIVACY_POLICY_URL` (web’de yayınlı politika)
  - `AFFILIATE_REF_ID` / `AFFILIATE_TAG` (opsiyonel)
- [ ] Gemini anahtarı AAB’ye gömülür — uzun vadede sunucu proxy düşün

## İmza
- [x] Kod: `android/key.properties` varsa release imza kullanılır
- [x] Keystore yedek yolu (yerel): `Documents\PlanToPlate-keystore-backup`
- [ ] `.\scripts\build_aab.ps1` ile imzalı AAB üretildi
- [ ] Play Console → App signing → upload key kaydı

## Yasal / Store
- [x] Ayarlar → Gizlilik politikası linki (`PRIVACY_POLICY_URL` doluysa)
- [x] AD_ID izni manifest’te
- [x] Şablon: `docs/privacy_policy_tr.md`
- [ ] Gizlilik politikası **web’de** yayınlandı → URL `.env`’e yazıldı
- [ ] Play Console: Veri güvenliği (AI, reklam, IAP, kamera, mikrofon, bildirim)
- [ ] Play Console: Reklam kimliği (AD_ID) beyanı
- [ ] Store listing: kısa/uzun açıklama, ekran görüntüleri, ikon, feature graphic
- [ ] Kamera / mikrofon izin gerekçeleri listing metninde

## Kalite (yayın öncesi)
- [x] `flutter analyze` temiz
- [x] Unit testler geçiyor
- [ ] Keşfet / Gece krizi telefonda açılıyor
- [ ] Alışveriş → Markette ara (Getir / … / Trendyol Go)
- [ ] Sentry test hatası (Ayarlar → Geliştirici) görünüyor
- [ ] Premium satın alma sandbox
- [ ] Bildirim izni Android 13+
- [ ] Release APK/AAB smoke test (ProGuard crash yok)

## Komutlar
```powershell
# Geliştirme
.\scripts\run_dev.ps1

# Play’e yüklenecek AAB
.\scripts\build_aab.ps1
```

AAB çıktısı: `build\app\outputs\bundle\release\app-release.aab`

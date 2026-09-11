# 🕹️ Neon Jump

Flutter + Flame Engine ile geliştirilmiş, tek elle oynanan, zamanla
zorlaşan hyper-casual bir endless-runner mobil oyunu.

## Özellikler

- ✅ Tek dokunuşla zıplama kontrolü — ilk 5 saniyede öğrenilir
- ✅ Zamanla artan hız ve engel sıklığı (zorluk eğrisi)
- ✅ Skor sistemi + en yüksek skorun cihazda kalıcı saklanması (`shared_preferences`)
- ✅ Duraklatma / devam ettirme
- ✅ Yeniden başlatma
- ✅ Ses aç/kapat, titreşim aç/kapat (ayarlar menüsünde kalıcı)
- ✅ Basit ayarlar ekranı
- ✅ AdMob ve uygulama içi satın alma için hazır altyapı (bkz. aşağıda)
- ✅ GitHub Actions ile Android Studio kurmadan otomatik APK derleme

## Proje Yapısı

```
lib/
  main.dart                     → Uygulama girişi
  game/
    neon_jump_game.dart         → Ana Flame oyun motoru, zorluk/skor mantığı
    components/                 → Player, Obstacle, Spawner, Background
    managers/                   → Storage (skor), Settings (ses/titreşim), Audio
  screens/
    home_screen.dart            → Ana menü
    game_screen.dart            → Oyun ekranı (GameWidget host)
    settings_screen.dart        → Ayarlar
    overlays/                   → Ready, HUD, Pause, GameOver overlay'leri
android/                        → Standart Flutter Android projesi
.github/workflows/build_apk.yml → GitHub Actions APK derleme workflow'u
ASSETS_TODO.md                  → Gerçek asset listesi ve kaynak önerileri
```

## GitHub Üzerinden APK Derleme (Android Studio Gerekmez)

1. Bu klasörü bir GitHub reposuna push edin:
   ```bash
   git init
   git add .
   git commit -m "Neon Jump - ilk sürüm"
   git branch -M main
   git remote add origin <REPO_URL>
   git push -u origin main
   ```
2. GitHub reponuzda **Actions** sekmesine gidin.
3. "Build Android APK" workflow'u push sonrası otomatik başlar (veya
   "Run workflow" ile manuel tetikleyebilirsiniz).
4. Derleme bitince workflow sayfasındaki **Artifacts** bölümünden
   `neon-jump-release-apk` dosyasını indirin — içinde hem
   `app-release.apk` (universal) hem de ABI'ye özel küçük APK'lar olacak.

> Not: `android/app/build.gradle` içinde release build şu an **debug
> imzalama anahtarı** ile imzalanıyor. Bu, test ve GitHub Actions
> derlemesi için sorunsuz çalışır. **Play Store'a yüklemeden önce**
> kendi keystore'unuzu oluşturup `key.properties` + `signingConfigs.release`
> ayarlarını eklemeniz gerekir (Flutter resmi dokümantasyonu:
> "Build and release an Android app").

## Yerelde Çalıştırma (opsiyonel)

```bash
flutter pub get
flutter run
```

## İleride Eklenecekler İçin Hazır Altyapı

### AdMob
- `pubspec.yaml` içinde `google_mobile_ads` bağımlılığı yorum satırı
  olarak hazır, açmanız yeterli.
- `AndroidManifest.xml` içinde `INTERNET` izni zaten ekli ve AdMob
  `APPLICATION_ID` meta-data satırı yorum olarak hazır.
- Önerilen entegrasyon noktası: `GameOverOverlay` gösterildiğinde
  interstitial reklam, `HomeScreen`'de banner reklam.

### Uygulama İçi Satın Alma
- `pubspec.yaml` içinde `in_app_purchase` bağımlılığı yorum satırı
  olarak hazır.
- Önerilen kullanım: reklamları kaldırma, kozmetik karakter skinleri
  (`Player` sınıfı zaten `Sprite` ile değiştirilmeye hazır yapıda).

## Lisans / Asset Notu

Placeholder görseller kod ile çizilmiştir (telifsiz). Gerçek asset
entegrasyonu için `ASSETS_TODO.md` dosyasına bakın — tüm önerilen
kaynaklar (Kenney.nl) CC0 lisanslıdır ve ticari kullanıma uygundur.

# Asset Notu — Neon Dash (v2)

Bu sürüm **hiçbir dış görsel veya ses dosyası kullanmıyor** — oyuncu,
engeller, arka plan ve yıldızlar tamamen kod (Flutter `CustomPainter`)
ile çiziliyor. Bu, önceki sürümde yaşanan kütüphane uyumluluk
sorunlarını ortadan kaldırmak için bilinçli bir tercih.

## İleride gerçek sprite/ses eklemek isterseniz

1. `pubspec.yaml`'a şunu ekleyin:
   ```yaml
   flutter:
     assets:
       - assets/images/
       - assets/audio/
   ```
2. `assets/images/` ve `assets/audio/` klasörlerini oluşturup dosyaları koyun
   (Kenney.nl CC0 paketleri önerilir — ticari kullanıma uygun, ücretsiz).
3. `lib/screens/game_screen.dart` içindeki `_GamePainter.paint()` metodundaki
   `canvas.drawRRect(...)` / `canvas.drawPath(...)` çağrılarını
   `ui.Image` tabanlı `canvas.drawImageRect(...)` ile değiştirin.
4. Ses için `audioplayers` paketini ekleyip zıplama/çarpma anlarında
   `AudioPlayer().play(AssetSource('jump.mp3'))` gibi çağırabilirsiniz.

Bu değişiklikler isteğe bağlıdır — oyun şu anki haliyle tamamen
çalışır ve derlenebilir durumdadır.

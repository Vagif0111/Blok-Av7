import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/managers/settings_manager.dart';
import 'game/managers/storage_manager.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Oyun dikey modda ve tek elle oynanacağı için ekranı dikeye kilitliyoruz.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Tam ekran, immersive mod (üst/alt sistem çubuklarını gizle).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Uygulama başlamadan önce ayarları ve en yüksek skoru diskten yükle.
  await StorageManager.instance.init();
  await SettingsManager.instance.init();

  runApp(const NeonJumpApp());
}

class NeonJumpApp extends StatelessWidget {
  const NeonJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blok Av',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F5FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

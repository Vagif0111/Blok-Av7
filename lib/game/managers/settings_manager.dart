import 'package:shared_preferences/shared_preferences.dart';

/// Ses ve titreşim tercihlerini yöneten, kalıcı olarak saklayan singleton.
class SettingsManager {
  SettingsManager._internal();
  static final SettingsManager instance = SettingsManager._internal();

  static const _kSoundKey = 'neon_jump_sound_enabled';
  static const _kVibrationKey = 'neon_jump_vibration_enabled';

  late SharedPreferences _prefs;

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _soundEnabled = _prefs.getBool(_kSoundKey) ?? true;
    _vibrationEnabled = _prefs.getBool(_kVibrationKey) ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _prefs.setBool(_kSoundKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs.setBool(_kVibrationKey, value);
  }

  Future<void> toggleSound() => setSoundEnabled(!_soundEnabled);
  Future<void> toggleVibration() => setVibrationEnabled(!_vibrationEnabled);
}

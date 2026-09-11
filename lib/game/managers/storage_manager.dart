import 'package:shared_preferences/shared_preferences.dart';

/// En yüksek skoru cihazın yerel deposunda (SharedPreferences) tutan
/// singleton yönetici. İleride toplam coin / satın alma verisi de
/// buraya kolayca eklenebilir.
class StorageManager {
  StorageManager._internal();
  static final StorageManager instance = StorageManager._internal();

  static const _kHighScoreKey = 'neon_jump_high_score';
  static const _kTotalRunsKey = 'neon_jump_total_runs';

  late SharedPreferences _prefs;
  int _highScore = 0;
  int _totalRuns = 0;

  int get highScore => _highScore;
  int get totalRuns => _totalRuns;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _highScore = _prefs.getInt(_kHighScoreKey) ?? 0;
    _totalRuns = _prefs.getInt(_kTotalRunsKey) ?? 0;
  }

  /// Yeni skor, eski rekoru geçtiyse kaydeder ve true döner.
  Future<bool> submitScore(int score) async {
    _totalRuns += 1;
    await _prefs.setInt(_kTotalRunsKey, _totalRuns);

    if (score > _highScore) {
      _highScore = score;
      await _prefs.setInt(_kHighScoreKey, _highScore);
      return true;
    }
    return false;
  }
}

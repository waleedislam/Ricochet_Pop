import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes persisted player progress: high score and the best
/// level reached so far.
class HighScoreService {
  static const _scoreKey = 'bouncing_rush_high_score';
  static const _levelKey = 'bouncing_rush_best_level';

  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  /// Saves [score] if it beats the stored high score.
  /// Returns true if a new high score was set.
  static Future<bool> saveIfHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_scoreKey) ?? 0;
    if (score > current) {
      await prefs.setInt(_scoreKey, score);
      return true;
    }
    return false;
  }

  /// The furthest level the player has reached. Starts at 1.
  static Future<int> getBestLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1;
  }

  /// Saves [level] if it's further than the stored best level.
  static Future<void> saveIfBestLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_levelKey) ?? 1;
    if (level > current) {
      await prefs.setInt(_levelKey, level);
    }
  }
}

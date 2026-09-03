import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level_progress.dart';

/// Reads and writes per-level results (stars + best score for every level
/// the player has completed at least once).
///
/// This is deliberately still just `shared_preferences`, not a real
/// database: even at 1000 levels, the whole progress map is only a few
/// KB of JSON in a single key. A SQL/NoSQL database would add real cost
/// (bigger app, native dependencies, schema migrations) for data this
/// small and this simple — there's no querying, filtering, or relational
/// structure here that would actually benefit from one.
class LevelProgressService {
  static const _key = 'bouncing_rush_level_progress';

  /// Loads the full progress map: level number -> [LevelProgress].
  /// Corrupted or missing data is treated as "no progress yet" rather
  /// than thrown — a save-format hiccup should never crash the app or
  /// lock the player out of their save.
  static Future<Map<int, LevelProgress>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (levelStr, value) => MapEntry(
          int.parse(levelStr),
          LevelProgress.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Records a result for [level], keeping the better of the new and any
  /// previously-saved stars/score independently.
  static Future<void> saveResult(
    int level, {
    required int stars,
    required int score,
  }) async {
    final all = await getAll();
    final incoming = LevelProgress(stars: stars, bestScore: score);
    final existing = all[level];
    all[level] = existing == null ? incoming : existing.mergeBetter(incoming);

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      all.map((level, progress) => MapEntry('$level', progress.toJson())),
    );
    await prefs.setString(_key, encoded);
  }
}

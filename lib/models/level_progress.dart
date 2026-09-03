/// A player's saved result for one level: how well they did (stars) and
/// their best score on it. Stars are 1–3, based on how many shots were
/// left over when the board was cleared — more leftover shots means a
/// more efficient clear.
class LevelProgress {
  final int stars; // 1..3
  final int bestScore;

  const LevelProgress({required this.stars, required this.bestScore});

  Map<String, int> toJson() => {'stars': stars, 'score': bestScore};

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        stars: json['stars'] as int? ?? 1,
        bestScore: json['score'] as int? ?? 0,
      );

  /// Merges a new result with the existing one, keeping whichever is
  /// better on each field independently (best stars, best score) —
  /// so replaying a level and doing worse never erases a past best.
  LevelProgress mergeBetter(LevelProgress other) => LevelProgress(
        stars: stars > other.stars ? stars : other.stars,
        bestScore: bestScore > other.bestScore ? bestScore : other.bestScore,
      );

  /// Computes a star rating from how many shots were left when a level
  /// was cleared, relative to how many shots the level started with.
  /// 3 stars: cleared with at least half the shots still in hand.
  /// 2 stars: cleared with at least a quarter left.
  /// 1 star: cleared at all, however narrowly.
  static int starsForClear({
    required int shotsRemaining,
    required int totalShots,
  }) {
    if (totalShots <= 0) return 1;
    final ratio = shotsRemaining / totalShots;
    if (ratio >= 0.5) return 3;
    if (ratio >= 0.25) return 2;
    return 1;
  }
}

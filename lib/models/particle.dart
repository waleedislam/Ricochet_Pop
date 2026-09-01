import 'dart:ui';

/// A single spark used for the bubble-pop burst effect.
class Particle {
  Offset position;
  Offset velocity;
  final Color color;
  double life; // seconds remaining
  final double maxLife;
  final double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
    required this.size,
  }) : maxLife = life;

  /// 0 (just spawned) -> 1 (about to be removed).
  double get progress => (1 - (life / maxLife)).clamp(0.0, 1.0);
}

/// A floating "+30" style popup shown above a pop location.
class ScorePopup {
  final Offset position;
  final int amount;
  double life;
  final double maxLife;

  ScorePopup({
    required this.position,
    required this.amount,
    this.life = 0.9,
  }) : maxLife = life;

  double get progress => (1 - (life / maxLife)).clamp(0.0, 1.0);
}

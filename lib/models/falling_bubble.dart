import 'dart:ui';

/// A bubble that has been cut loose from the grid (no longer connected to
/// the ceiling) and is now tumbling down under gravity instead of just
/// vanishing. Purely visual — the grid cell it came from is already
/// cleared by the time this exists.
class FallingBubble {
  Offset position;
  Offset velocity;
  final Color color;
  final double radius;
  double rotation;
  final double angularVelocity;
  double life; // seconds remaining as a safety-net despawn
  final double maxLife;

  FallingBubble({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    this.rotation = 0,
    this.angularVelocity = 0,
    this.life = 2.4,
  }) : maxLife = life;

  /// Fades out over the final [fadeWindow] seconds of life, in case a
  /// bubble somehow never leaves the visible board.
  double opacityFor({double fadeWindow = 0.35}) {
    if (life >= fadeWindow) return 1.0;
    return (life / fadeWindow).clamp(0.0, 1.0);
  }
}

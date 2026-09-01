import 'dart:ui';
import 'power_up.dart';

/// Visual/state model for the player's ball.
/// Movement logic now lives in GameScreen (bounce rhythm + drag control).
class Ball {
  Offset position;
  Offset velocity; // kept for possible future use / effects
  final double radius;
  final Color color;

  /// Which special power-up this ball carries, if any. [PowerUpType.none]
  /// for an ordinary colored ball.
  final PowerUpType powerUp;

  Ball({
    required this.position,
    this.velocity = Offset.zero,
    this.radius = 20,
    this.color = const Color(0xFFE53935),
    this.powerUp = PowerUpType.none,
  });
}

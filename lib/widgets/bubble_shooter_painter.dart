import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/bubble_grid.dart';
import '../models/ball.dart';
import '../models/falling_bubble.dart';
import '../models/particle.dart';
import '../models/power_up.dart';

/// Renders the whole play-field: background, bubble grid, laser aim guide,
/// shooter ball, danger line, particle bursts and floating score popups.
class BubbleShooterPainter extends CustomPainter {
  final BubbleGrid grid;
  final Ball shooterBall;
  final Offset shooterPosition;
  final double? aimAngle;
  final List<Offset>? aimPath;
  final List<Particle> particles;
  final List<ScorePopup> scorePopups;
  final List<FallingBubble> fallingBubbles;
  final int dangerRow;
  final double dangerPulse; // animated 0..1 value driving the warning line
  final bool canSwap; // whether tapping the shooter ball swaps its color
  final double animT; // continuously-increasing clock for power-up FX

  BubbleShooterPainter({
    required this.grid,
    required this.shooterBall,
    required this.shooterPosition,
    required this.aimAngle,
    required this.aimPath,
    required this.particles,
    required this.scorePopups,
    required this.fallingBubbles,
    required this.dangerRow,
    required this.dangerPulse,
    this.canSwap = true,
    this.animT = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawDangerLine(canvas, size);
    _drawGrid(canvas);
    _drawFallingBubbles(canvas);
    _drawAimLaser(canvas);
    _drawSwapHint(canvas);
    _drawBall(canvas, shooterBall, glow: true);
    _drawParticles(canvas);
    _drawScorePopups(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Center drifts a touch with the animation clock for a slow living feel.
    final driftX = math.sin(dangerPulse * math.pi) * 0.06;
    final gradient = RadialGradient(
      center: Alignment(driftX, -0.6),
      radius: 1.3,
      colors: const [Color(0xFF203756), Color(0xFF0A0F17)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Twinkling starfield: fixed positions (seeded), animated brightness.
    final rnd = math.Random(7);
    for (int i = 0; i < 60; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.5 + 0.4;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final twinkle = (math.sin(dangerPulse * 2 * math.pi + phase) + 1) / 2;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()..color = Colors.white.withOpacity(0.03 + twinkle * 0.09),
      );
    }
  }

  void _drawDangerLine(Canvas canvas, Size size) {
    final y = grid.yForRow(dangerRow) + grid.radius;
    if (y < -20 || y > size.height + 20) return;

    // Tinted zone below the line to make the danger area unmistakable.
    final zoneRect = Rect.fromLTWH(0, y, size.width, size.height - y);
    canvas.drawRect(
      zoneRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.withOpacity(0.10 + dangerPulse * 0.06),
            Colors.red.withOpacity(0.0),
          ],
        ).createShader(zoneRect),
    );

    // Glow behind the line.
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = Colors.redAccent.withOpacity(0.35 + dangerPulse * 0.25)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Crisp bright core line.
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = Color.lerp(Colors.red.shade300, Colors.redAccent, dangerPulse)!
        ..strokeWidth = 2.5,
    );
  }

  void _drawGrid(Canvas canvas) {
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final color = grid.cells[r][c];
        if (color == null) continue;
        final center = Offset(grid.xForCell(r, c), grid.yForRow(r));
        _drawBubble(canvas, center, grid.radius, color);
      }
    }
  }

  /// Bubbles that lost their ceiling connection, tumbling down with a
  /// gentle spin (the spin shows because [_drawBubble]'s highlight sits
  /// off-center) and fading out only in their last moments as a safety
  /// net for ones that never leave the visible board.
  void _drawFallingBubbles(Canvas canvas) {
    for (final b in fallingBubbles) {
      final opacity = b.opacityFor();
      canvas.save();
      canvas.translate(b.position.dx, b.position.dy);
      canvas.rotate(b.rotation);
      if (opacity < 1.0) {
        canvas.saveLayer(
          Rect.fromCircle(center: Offset.zero, radius: b.radius * 2.2),
          Paint()..color = Colors.white.withOpacity(opacity),
        );
      }
      _drawBubble(canvas, Offset.zero, b.radius, b.color);
      if (opacity < 1.0) {
        canvas.restore();
      }
      canvas.restore();
    }
  }

  void _drawBubble(Canvas canvas, Offset center, double radius, Color color) {
    // Soft drop shadow.
    canvas.drawCircle(
      center.translate(0, radius * 0.12),
      radius * 0.96,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final gradient = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      colors: [
        Color.lerp(color, Colors.white, 0.45)!,
        color,
        Color.lerp(color, Colors.black, 0.25)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius * 0.92),
        ),
    );

    // Glossy highlight.
    canvas.drawCircle(
      center.translate(-radius * 0.32, -radius * 0.32),
      radius * 0.26,
      Paint()..color = Colors.white.withOpacity(0.55),
    );

    // Thin rim for definition.
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withOpacity(0.15),
    );
  }

  void _drawBall(Canvas canvas, Ball ball, {bool glow = false}) {
    final powerUp = ball.powerUp;
    final glowColor = powerUp.isPowerUp ? powerUp.info.accent : ball.color;
    if (glow) {
      // Breathing double-layer glow so the shooter ball reads as "alive".
      // Power-up balls get an extra-hot glow so they read as special from
      // across the board.
      final breathe = (math.sin(dangerPulse * 2 * math.pi) + 1) / 2;
      final extra = powerUp.isPowerUp ? 0.3 : 0.0;
      canvas.drawCircle(
        ball.position,
        ball.radius * (1.9 + breathe * 0.25 + extra),
        Paint()
          ..color = glowColor.withOpacity(0.14 + breathe * 0.06 + extra * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(
        ball.position,
        ball.radius * (1.5 + extra * 0.5),
        Paint()
          ..color = glowColor.withOpacity(0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    if (powerUp.isPowerUp) {
      _drawPowerUpBubble(canvas, ball.position, ball.radius, powerUp);
    } else {
      _drawBubble(canvas, ball.position, ball.radius, ball.color);
    }
  }

  /// Renders a special power-up ball: a color-bomb, line-blast, or rainbow
  /// wildcard. Shares the base bubble treatment (shadow, gloss, rim) but
  /// swaps the fill for something that reads as "not an ordinary bubble"
  /// and overlays an identifying icon plus a slowly spinning energy ring.
  void _drawPowerUpBubble(
    Canvas canvas,
    Offset center,
    double radius,
    PowerUpType powerUp,
  ) {
    final info = powerUp.info;

    canvas.drawCircle(
      center.translate(0, radius * 0.12),
      radius * 0.96,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final rect = Rect.fromCircle(center: center, radius: radius * 0.92);
    late final Shader shader;
    if (powerUp == PowerUpType.rainbow) {
      // Slowly cycling hue sweep so the wildcard ball visibly shimmers
      // through every color it could become.
      final hueShift = (animT * 70) % 360;
      final colors = List.generate(7, (i) {
        final hue = (hueShift + i * 360 / 6) % 360;
        return HSVColor.fromAHSV(1, hue, 0.7, 1).toColor();
      });
      shader = SweepGradient(colors: colors).createShader(rect);
    } else {
      shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [
          Color.lerp(info.accent, Colors.white, 0.4)!,
          info.accent,
          Color.lerp(info.accent, Colors.black, 0.4)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    }
    canvas.drawCircle(center, radius * 0.92, Paint()..shader = shader);

    // Glossy highlight, matching regular bubbles.
    canvas.drawCircle(
      center.translate(-radius * 0.32, -radius * 0.32),
      radius * 0.26,
      Paint()..color = Colors.white.withOpacity(0.55),
    );

    // Bright rim so it separates cleanly from the board behind it.
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withOpacity(0.6),
    );

    // Slowly rotating dashed energy ring — the "this one is special" tell.
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    const dashCount = 14;
    final rotation = animT * 1.4;
    for (int i = 0; i < dashCount; i++) {
      if (i.isOdd) continue;
      final a0 = rotation + (i / dashCount) * 2 * math.pi;
      final a1 = rotation + ((i + 0.6) / dashCount) * 2 * math.pi;
      final r = radius * 1.3;
      canvas.drawLine(
        center + Offset(math.cos(a0), math.sin(a0)) * r,
        center + Offset(math.cos(a1), math.sin(a1)) * r,
        ringPaint,
      );
    }

    _drawGlyphIcon(canvas, center, info.icon, radius * 1.05, Colors.white);
  }

  /// Paints a Material [IconData] glyph directly onto the canvas (icon
  /// fonts render like any other text glyph), used for power-up markers.
  void _drawGlyphIcon(
    Canvas canvas,
    Offset center,
    IconData icon,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// Hint ring + icon around the shooter ball showing it can be tapped
  /// to instantly swap its color with the "next" ball.
  void _drawSwapHint(Canvas canvas) {
    if (!canSwap || aimPath != null) return; // hide while actively aiming
    final r = shooterBall.radius * 1.45;
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dashCount = 18;
    for (int i = 0; i < dashCount; i++) {
      if (i.isOdd) continue;
      final a0 = (i / dashCount) * 2 * math.pi;
      final a1 = ((i + 1) / dashCount) * 2 * math.pi;
      final p0 = shooterPosition + Offset(math.cos(a0), math.sin(a0)) * r;
      final p1 = shooterPosition + Offset(math.cos(a1), math.sin(a1)) * r;
      canvas.drawLine(p0, p1, dashPaint);
    }
  }

  /// Bright glowing laser-sight guide showing where the ball will travel,
  /// including reflections off the side walls.
  void _drawAimLaser(Canvas canvas) {
    final path = aimPath;
    if (path == null || path.length < 2) return;

    const laserColor = Color(0xFF64FFDA);

    // Outer soft glow.
    final glowPaint = Paint()
      ..color = laserColor.withOpacity(0.35)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = 0; i < path.length - 1; i++) {
      canvas.drawLine(path[i], path[i + 1], glowPaint);
    }

    // Sharp bright dashed core.
    final corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < path.length - 1; i++) {
      _drawDashedSegment(canvas, path[i], path[i + 1], corePaint);
    }

    // Impact marker at the end of the path.
    canvas.drawCircle(path.last, 5, Paint()..color = laserColor.withOpacity(0.9));
    canvas.drawCircle(
      path.last,
      9,
      Paint()
        ..color = laserColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawDashedSegment(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 9.0;
    const gapLength = 7.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    double travelled = 0;
    while (travelled < total) {
      final segEnd = math.min(travelled + dashLength, total);
      canvas.drawLine(a + dir * travelled, a + dir * segEnd, paint);
      travelled += dashLength + gapLength;
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final opacity = (1 - p.progress).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.position,
        p.size * (1 - p.progress * 0.4),
        Paint()..color = p.color.withOpacity(opacity),
      );
    }
  }

  void _drawScorePopups(Canvas canvas) {
    for (final s in scorePopups) {
      final opacity = (1 - s.progress).clamp(0.0, 1.0);
      final dy = -34 * s.progress;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '+${s.amount}',
          style: TextStyle(
            color: Colors.amberAccent.withOpacity(opacity),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        s.position.translate(-textPainter.width / 2, dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BubbleShooterPainter oldDelegate) => true;
}

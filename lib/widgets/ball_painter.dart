import 'package:flutter/material.dart';
import '../models/ball.dart';

class BallPainter extends CustomPainter {
  final Ball ball;

  BallPainter({required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ball.color.withOpacity(1.0),
          ball.color.withOpacity(0.7),
        ],
      ).createShader(
        Rect.fromCircle(center: ball.position, radius: ball.radius),
      );

    canvas.drawCircle(ball.position, ball.radius, paint);

    // Small highlight for a glossy look.
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(
      ball.position.translate(-ball.radius * 0.3, -ball.radius * 0.3),
      ball.radius * 0.25,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BallPainter oldDelegate) => true;
}

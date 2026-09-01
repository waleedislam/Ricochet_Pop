import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bubble_grid.dart';

/// Computes the polyline points of the aim-preview path: a straight shot
/// from [start] at [angle] (radians from vertical), reflecting off the
/// side walls, and stopping as soon as it would hit the ceiling or an
/// existing bubble. Used to draw the dashed aiming guide while the
/// player is dragging.
List<Offset> computeAimPath({
  required Offset start,
  required double angle,
  required Size boardSize,
  required BubbleGrid grid,
  required double ballRadius,
  int maxBounces = 3,
}) {
  final points = <Offset>[start];
  var pos = start;
  var dir = Offset(math.sin(angle), -math.cos(angle));
  var bounces = 0;

  while (bounces <= maxBounces) {
    double tWall = double.infinity;
    if (dir.dx > 1e-6) {
      tWall = (boardSize.width - ballRadius - pos.dx) / dir.dx;
    } else if (dir.dx < -1e-6) {
      tWall = (ballRadius - pos.dx) / dir.dx;
    }

    double tCeil = double.infinity;
    if (dir.dy < -1e-6) {
      tCeil = (ballRadius - pos.dy) / dir.dy;
    }

    final tEnd = math.min(tWall, tCeil);
    if (!tEnd.isFinite || tEnd <= 0) break;

    // Sample along this segment to see if it hits an existing bubble first.
    const sampleStep = 5.0;
    double travelled = 0;
    Offset? collisionPoint;
    while (travelled < tEnd) {
      travelled = math.min(travelled + sampleStep, tEnd);
      final p = pos + dir * travelled;
      if (_hitsBubble(grid, p)) {
        collisionPoint = p;
        break;
      }
    }

    if (collisionPoint != null) {
      points.add(collisionPoint);
      return points;
    }

    final endPoint = pos + dir * tEnd;
    points.add(endPoint);

    if (tEnd == tCeil) break; // reached ceiling: stop here

    // Reflect off the side wall and keep going.
    dir = Offset(-dir.dx, dir.dy);
    pos = endPoint;
    bounces++;
  }
  return points;
}

bool _hitsBubble(BubbleGrid grid, Offset p) {
  for (int r = 0; r < grid.rows; r++) {
    for (int c = 0; c < grid.cols; c++) {
      if (grid.cells[r][c] == null) continue;
      final center = Offset(grid.xForCell(r, c), grid.yForRow(r));
      if ((center - p).distance < grid.radius * 1.9) return true;
    }
  }
  return false;
}

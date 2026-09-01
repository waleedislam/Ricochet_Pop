// Unit tests for computeAimPath — the dashed aim-guide line the player
// sees while dragging. Covers the three ways a shot can end: hitting the
// ceiling straight on, bouncing off a side wall first, and stopping early
// because it would hit an existing bubble.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ricochet_pop/game/bubble_grid.dart';
import 'package:ricochet_pop/game/trajectory.dart';

void main() {
  final boardSize = const Size(400, 600);

  group('computeAimPath', () {
    test('a straight shot up the middle goes directly to the ceiling', () {
      final grid = BubbleGrid(cols: 8, rows: 10, radius: 20);
      final path = computeAimPath(
        start: const Offset(200, 580),
        angle: 0, // straight up
        boardSize: boardSize,
        grid: grid,
        ballRadius: 12,
      );

      // start point + one ceiling-hit point, no wall bounces needed.
      expect(path.length, 2);
      expect(path.first, const Offset(200, 580));
      // Ends at the ceiling (y == ballRadius) still centered on x.
      expect(path.last.dy, closeTo(12, 0.5));
      expect(path.last.dx, closeTo(200, 0.5));
    });

    test('an angled shot bounces off a side wall before reaching the ceiling',
        () {
      final grid = BubbleGrid(cols: 8, rows: 10, radius: 20);
      final path = computeAimPath(
        start: const Offset(200, 580),
        angle: 70 * math.pi / 180, // steep angle toward the right wall
        boardSize: boardSize,
        grid: grid,
        ballRadius: 12,
      );

      // At least one bounce point plus the final ceiling point: 3+ points.
      expect(path.length, greaterThanOrEqualTo(3));
      // The bounce point should sit right at the wall.
      final bouncePoint = path[1];
      expect(bouncePoint.dx, closeTo(boardSize.width - 12, 0.5));
    });

    test('the path stops early when it would hit an existing bubble', () {
      final grid = BubbleGrid(cols: 8, rows: 10, radius: 20);
      // Place a bubble directly in the path of a straight-up shot.
      grid.cells[5][4] = const Color(0xFFE53935);
      final blockingCenter = Offset(grid.xForCell(5, 4), grid.yForRow(5));

      final path = computeAimPath(
        start: Offset(blockingCenter.dx, 580),
        angle: 0,
        boardSize: boardSize,
        grid: grid,
        ballRadius: 12,
      );

      // Should stop at (or very near) the blocking bubble, well short of
      // the ceiling.
      expect(path.length, 2);
      expect(path.last.dy, greaterThan(12 + 1));
      expect(path.last.dy, lessThan(580));
    });

    test('respects maxBounces and terminates instead of looping forever',
        () {
      final grid = BubbleGrid(cols: 8, rows: 10, radius: 20);
      // A very shallow, near-horizontal angle bounces back and forth a lot.
      final path = computeAimPath(
        start: const Offset(200, 580),
        angle: 89 * math.pi / 180,
        boardSize: boardSize,
        grid: grid,
        ballRadius: 12,
        maxBounces: 2,
      );

      // Must finish (not hang) and never produce more segments than
      // maxBounces + 2 endpoints (start + one per bounce + final).
      expect(path.length, lessThanOrEqualTo(2 + 2 + 1));
      expect(path, isNotEmpty);
    });
  });
}

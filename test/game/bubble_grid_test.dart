// Unit tests for BubbleGrid — the core grid/matching logic that the whole
// game is built on. These don't need a widget tree at all, so they run
// fast and pin down the rules that decide whether a shot pops bubbles,
// whether bubbles fall, and whether the board is cleared.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ricochet_pop/game/bubble_grid.dart';

void main() {
  group('BubbleGrid geometry', () {
    test('new grid starts completely empty', () {
      final grid = BubbleGrid(cols: 8, rows: 10, radius: 20);
      expect(grid.isEmpty, isTrue);
      for (int r = 0; r < grid.rows; r++) {
        for (int c = 0; c < grid.cols; c++) {
          expect(grid.isOccupied(r, c), isFalse);
        }
      }
    });

    test('inBounds rejects out-of-range coordinates', () {
      final grid = BubbleGrid(cols: 5, rows: 5, radius: 20);
      expect(grid.inBounds(0, 0), isTrue);
      expect(grid.inBounds(4, 4), isTrue);
      expect(grid.inBounds(-1, 0), isFalse);
      expect(grid.inBounds(0, -1), isFalse);
      expect(grid.inBounds(5, 0), isFalse);
      expect(grid.inBounds(0, 5), isFalse);
    });

    test('odd rows are horizontally offset by one radius (hex packing)', () {
      final grid = BubbleGrid(cols: 5, rows: 5, radius: 20);
      final evenRowX = grid.xForCell(0, 0);
      final oddRowX = grid.xForCell(1, 0);
      expect(oddRowX - evenRowX, closeTo(20, 0.001));
    });

    test('yForRow increases by rowHeight per row', () {
      final grid = BubbleGrid(cols: 5, rows: 5, radius: 20);
      final y0 = grid.yForRow(0);
      final y1 = grid.yForRow(1);
      expect(y1 - y0, closeTo(grid.rowHeight, 0.001));
    });
  });

  group('BubbleGrid.floodMatch', () {
    test('finds a connected same-color cluster and stops at other colors',
        () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      const blue = Color(0xFF1E88E5);
      // Row 0 (even row neighbor deltas): (0,0)-(0,1) are adjacent.
      grid.cells[0][0] = red;
      grid.cells[0][1] = red;
      grid.cells[0][2] = blue; // different color: should not be included
      grid.cells[1][0] = red; // connected via neighbor offsets

      final match = grid.floodMatch(0, 0);
      final matchSet = match.map((m) => '${m[0]},${m[1]}').toSet();

      expect(matchSet.contains('0,0'), isTrue);
      expect(matchSet.contains('0,1'), isTrue);
      expect(matchSet.contains('0,2'), isFalse); // blue excluded
    });

    test('a lone bubble matches only itself', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      grid.cells[2][2] = const Color(0xFF43A047);
      final match = grid.floodMatch(2, 2);
      expect(match.length, 1);
      expect(match.first, [2, 2]);
    });

    test('an empty cell has no match', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      expect(grid.floodMatch(0, 0), isEmpty);
    });
  });

  group('BubbleGrid.findFloating', () {
    test('bubbles connected to the ceiling row are not floating', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      grid.cells[0][0] = red;
      grid.cells[1][0] = red;
      grid.cells[2][0] = red;

      expect(grid.findFloating(), isEmpty);
    });

    test('a cluster with no path back to row 0 is reported as floating', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      // A cluster stranded away from the ceiling with no connecting chain.
      grid.cells[3][3] = red;

      final floating = grid.findFloating();
      expect(floating, contains([3, 3]));
    });

    test('removing the bridge cell orphans the bubbles below it', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      grid.cells[0][0] = red; // touches ceiling
      grid.cells[1][0] = red; // bridge
      grid.cells[2][0] = red; // depends on the bridge

      expect(grid.findFloating(), isEmpty); // fully connected initially

      grid.cells[1][0] = null; // pop the bridge, as a real shot would
      final floating = grid.findFloating();
      expect(floating, contains([2, 0]));
      expect(floating, isNot(contains([0, 0])));
    });
  });

  group('BubbleGrid power-up helpers', () {
    test('cellsOfColor finds every occupied cell of that color', () {
      final grid = BubbleGrid(cols: 3, rows: 3, radius: 20);
      const red = Color(0xFFE53935);
      const blue = Color(0xFF1E88E5);
      grid.cells[0][0] = red;
      grid.cells[1][1] = red;
      grid.cells[2][2] = blue;

      final reds = grid.cellsOfColor(red);
      expect(reds.length, 2);
      expect(reds, contains([0, 0]));
      expect(reds, contains([1, 1]));
    });

    test('cellsInRow only returns occupied cells in that row', () {
      final grid = BubbleGrid(cols: 3, rows: 3, radius: 20);
      grid.cells[1][0] = const Color(0xFFE53935);
      grid.cells[1][2] = const Color(0xFF1E88E5);

      final row1 = grid.cellsInRow(1);
      expect(row1.length, 2);
      expect(grid.cellsInRow(0), isEmpty);
      expect(grid.cellsInRow(-1), isEmpty); // out-of-range: safe, not a crash
      expect(grid.cellsInRow(99), isEmpty);
    });

    test('anyOccupiedColor returns null only when the board is empty', () {
      final grid = BubbleGrid(cols: 3, rows: 3, radius: 20);
      expect(grid.anyOccupiedColor(), isNull);
      grid.cells[0][0] = const Color(0xFFE53935);
      expect(grid.anyOccupiedColor(), const Color(0xFFE53935));
    });

    test('mostCommonNeighborColor picks the majority neighbor color', () {
      final grid = BubbleGrid(cols: 4, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      const blue = Color(0xFF1E88E5);
      // Row 1 is odd; neighbors of (1,1) are (0,1) (0,2) (1,0) (1,2) (2,1) (2,2).
      grid.cells[0][1] = red;
      grid.cells[0][2] = red;
      grid.cells[1][0] = blue;

      expect(grid.mostCommonNeighborColor(1, 1), red);
    });

    test('bestMatchNeighborColor prefers the color forming the bigger group',
        () {
      final grid = BubbleGrid(cols: 5, rows: 4, radius: 20);
      const red = Color(0xFFE53935);
      const blue = Color(0xFF1E88E5);
      // A 3-long connected red chain reachable via neighbor (0,1) of (1,1),
      // versus a lone blue neighbor at (1,0).
      grid.cells[0][1] = red;
      grid.cells[0][2] = red;
      grid.cells[0][3] = red;
      grid.cells[1][0] = blue;

      expect(grid.bestMatchNeighborColor(1, 1), red);
    });
  });

  group('BubbleGrid.shiftDownAndAddRow', () {
    test('pushes every row down by one and fills row 0 with new colors', () {
      final grid = BubbleGrid(cols: 3, rows: 3, radius: 20);
      const red = Color(0xFFE53935);
      grid.cells[0] = [red, red, red];
      grid.cells[1] = [null, null, null];

      grid.shiftDownAndAddRow([red], Random(1));

      // Old row 0 is now row 1.
      expect(grid.cells[1], [red, red, red]);
      // A brand-new row was generated at the top.
      expect(grid.cells[0].every((c) => c == red), isTrue);
    });
  });

  group('BubbleGrid.findSnapCell', () {
    test('finds the nearest empty cell to a pixel point', () {
      final grid = BubbleGrid(cols: 5, rows: 5, radius: 20);
      final target = grid.findSnapCell(
        grid.xForCell(2, 2),
        grid.yForRow(2),
      );
      expect(target, isNotNull);
      expect(target, [2, 2]);
    });

    test('skips cells that are already occupied', () {
      final grid = BubbleGrid(cols: 5, rows: 5, radius: 20);
      grid.cells[2][2] = const Color(0xFFE53935);
      final target = grid.findSnapCell(
        grid.xForCell(2, 2),
        grid.yForRow(2),
      );
      expect(target, isNot([2, 2]));
    });
  });
}

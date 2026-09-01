import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Manages the grid of colored bubbles (offset hex layout), including
/// geometry (grid <-> pixel), neighbor lookup, color-match flood fill,
/// and detection of bubbles that lost connection to the ceiling.
class BubbleGrid {
  final int cols;
  final int rows;
  final double radius;
  late final double rowHeight;
  late List<List<Color?>> cells; // cells[row][col], null = empty

  BubbleGrid({required this.cols, required this.rows, required this.radius}) {
    rowHeight = radius * 1.73; // hex packing vertical spacing
    cells = List.generate(rows, (_) => List<Color?>.filled(cols, null));
  }

  double xForCell(int row, int col) {
    final offset = row.isOdd ? radius : 0.0;
    return radius + col * radius * 2 + offset;
  }

  double yForRow(int row) => radius + row * rowHeight;

  bool inBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  bool isOccupied(int row, int col) =>
      inBounds(row, col) && cells[row][col] != null;

  /// True once every cell is empty — the level's been fully cleared.
  bool get isEmpty {
    for (final row in cells) {
      for (final c in row) {
        if (c != null) return false;
      }
    }
    return true;
  }

  List<List<int>> _neighborOffsets(int row) {
    // "odd-r" offset hex neighbor deltas.
    return row.isOdd
        ? [
            [-1, 0], [-1, 1], [0, -1], [0, 1], [1, 0], [1, 1] //
          ]
        : [
            [-1, -1], [-1, 0], [0, -1], [0, 1], [1, -1], [1, 0] //
          ];
  }

  List<List<int>> neighborsOf(int row, int col) {
    final result = <List<int>>[];
    for (final off in _neighborOffsets(row)) {
      final r = row + off[0];
      final c = col + off[1];
      if (inBounds(r, c)) result.add([r, c]);
    }
    return result;
  }

  /// Finds the closest empty cell to a pixel point (used when a shot lands).
  List<int>? findSnapCell(double x, double y) {
    final approxRow =
        ((y - radius) / rowHeight).round().clamp(0, rows - 1);
    int bestRow = -1, bestCol = -1;
    double bestDist = double.infinity;
    final lo = math.max(0, approxRow - 2);
    final hi = math.min(rows - 1, approxRow + 2);
    for (int r = lo; r <= hi; r++) {
      for (int c = 0; c < cols; c++) {
        if (cells[r][c] != null) continue;
        final cx = xForCell(r, c);
        final cy = yForRow(r);
        final d = (cx - x) * (cx - x) + (cy - y) * (cy - y);
        if (d < bestDist) {
          bestDist = d;
          bestRow = r;
          bestCol = c;
        }
      }
    }
    if (bestRow == -1) return null;
    return [bestRow, bestCol];
  }

  /// BFS same-color group starting at (row, col).
  List<List<int>> floodMatch(int row, int col) {
    final color = inBounds(row, col) ? cells[row][col] : null;
    if (color == null) return [];
    final visited = <String>{};
    final stack = <List<int>>[
      [row, col]
    ];
    final result = <List<int>>[];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      final key = '${cur[0]},${cur[1]}';
      if (visited.contains(key)) continue;
      visited.add(key);
      if (!isOccupied(cur[0], cur[1])) continue;
      if (cells[cur[0]][cur[1]] != color) continue;
      result.add(cur);
      stack.addAll(neighborsOf(cur[0], cur[1]));
    }
    return result;
  }

  /// Bubbles no longer connected (directly or indirectly) to row 0.
  List<List<int>> findFloating() {
    final connected = <String>{};
    final queue = <List<int>>[];
    for (int c = 0; c < cols; c++) {
      if (isOccupied(0, c)) {
        queue.add([0, c]);
        connected.add('0,$c');
      }
    }
    int qi = 0;
    while (qi < queue.length) {
      final cur = queue[qi++];
      for (final n in neighborsOf(cur[0], cur[1])) {
        final key = '${n[0]},${n[1]}';
        if (connected.contains(key) || !isOccupied(n[0], n[1])) continue;
        connected.add(key);
        queue.add(n);
      }
    }
    final floating = <List<int>>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (isOccupied(r, c) && !connected.contains('$r,$c')) {
          floating.add([r, c]);
        }
      }
    }
    return floating;
  }

  bool anyBubbleAtOrBelowRow(int thresholdRow) {
    for (int r = thresholdRow; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (isOccupied(r, c)) return true;
      }
    }
    return false;
  }

  /// All occupied cells matching [color] — used by the color-bomb power-up
  /// to find everything it should wipe out.
  List<List<int>> cellsOfColor(Color color) {
    final result = <List<int>>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (cells[r][c] == color) result.add([r, c]);
      }
    }
    return result;
  }

  /// All occupied cells in [row] — used by the line-blast power-up.
  List<List<int>> cellsInRow(int row) {
    if (row < 0 || row >= rows) return [];
    final result = <List<int>>[];
    for (int c = 0; c < cols; c++) {
      if (cells[row][c] != null) result.add([row, c]);
    }
    return result;
  }

  /// Any color still present on the board, or null if it's already empty.
  /// Fallback target for a color bomb that lands with no direct neighbors.
  Color? anyOccupiedColor() {
    for (final row in cells) {
      for (final c in row) {
        if (c != null) return c;
      }
    }
    return null;
  }

  /// The majority color among the occupied neighbors of (row, col) — what
  /// a color bomb is considered to have "struck" when it settles into a
  /// pocket next to more than one color.
  Color? mostCommonNeighborColor(int row, int col) {
    final counts = <Color, int>{};
    for (final n in neighborsOf(row, col)) {
      final color = cells[n[0]][n[1]];
      if (color == null) continue;
      counts[color] = (counts[color] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    Color best = counts.keys.first;
    int bestCount = -1;
    counts.forEach((color, count) {
      if (count > bestCount) {
        best = color;
        bestCount = count;
      }
    });
    return best;
  }

  /// Among the occupied neighbors of (row, col), the color that would form
  /// the largest connected match if a bubble of that color were placed
  /// there. Used to resolve a rainbow/wildcard ball into a real color.
  Color? bestMatchNeighborColor(int row, int col) {
    final tried = <Color>{};
    Color? best;
    int bestSize = 0;
    for (final n in neighborsOf(row, col)) {
      final color = cells[n[0]][n[1]];
      if (color == null || tried.contains(color)) continue;
      tried.add(color);
      final size = floodMatch(n[0], n[1]).length;
      if (size > bestSize) {
        bestSize = size;
        best = color;
      }
    }
    return best;
  }

  void shiftDownAndAddRow(List<Color> palette, math.Random random) {
    for (int r = rows - 1; r > 0; r--) {
      cells[r] = List<Color?>.from(cells[r - 1]);
    }
    cells[0] =
        List<Color?>.generate(cols, (_) => palette[random.nextInt(palette.length)]);
  }
}

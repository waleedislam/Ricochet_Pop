import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../game/bubble_grid.dart';
import '../game/trajectory.dart';
import '../models/ball.dart';
import '../models/falling_bubble.dart';
import '../models/particle.dart';
import '../models/power_up.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/high_score_service.dart';
import '../widgets/bubble_shooter_painter.dart';
import '../widgets/menu_overlay.dart';
import 'level_select_screen.dart';

/// Top-level screen state. [gameOver] doubles as the generic "show a
/// result overlay" state — [LevelResult] decides whether that overlay
/// says the player won or lost.
enum GameState { menu, playing, gameOver }

enum LevelResult { none, complete, failed }

const List<Color> kPalette = [
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final math.Random _random = math.Random();

  GameState _state = GameState.menu;
  LevelResult _levelResult = LevelResult.none;
  String? _failReason;
  bool _paused = false;
  Size? _boardSize;
  BubbleGrid? _grid;

  static const int _cols = 8;
  static const double _shotSpeed = 700; // px/sec

  late Ball _shooterBall;
  bool _isShooting = false;
  double? _aimAngle; // radians from vertical, null when not aiming
  List<Offset>? _aimPath;
  late Offset _shooterPosition;
  Color _nextColor = kPalette.first;
  Color _nextNextColor = kPalette.first;
  PowerUpType _nextPowerUp = PowerUpType.none;
  PowerUpType _nextNextPowerUp = PowerUpType.none;

  /// Color of whichever grid bubble the in-flight ball's collision check
  /// actually struck (as opposed to the cell it eventually snaps to) —
  /// used so a color bomb targets the color it visually hit.
  Color? _lastHitColor;

  int _score = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  int _level = 1;
  int _bestLevel = 1;
  int _shotsRemaining = 0;
  int _combo = 0;

  final List<Particle> _particles = [];
  final List<ScorePopup> _scorePopups = [];
  final List<FallingBubble> _fallingBubbles = [];
  double _dangerPulseT = 0;

  bool _muted = false;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _initAudio();
    _loadBannerAd();
    _ticker = createTicker(_onTick)..start();
  }

  void _loadBannerAd() {
    _bannerAd = AdService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _loadProgress() async {
    final hs = await HighScoreService.getHighScore();
    final bl = await HighScoreService.getBestLevel();
    if (mounted) {
      setState(() {
        _highScore = hs;
        _bestLevel = bl;
      });
    }
  }

  Future<void> _initAudio() async {
    await AudioService.instance.init();
    if (mounted) {
      setState(() => _muted = AudioService.instance.muted);
    }
  }

  void _toggleMute() {
    AudioService.instance.toggleMuted();
    setState(() => _muted = AudioService.instance.muted);
  }

  /// Color pool grows slowly with level so early levels are easy to match
  /// and later levels get genuinely harder.
  List<Color> _paletteForLevel(int level) {
    final count = (3 + (level ~/ 3)).clamp(3, kPalette.length);
    return kPalette.sublist(0, count);
  }

  int _shotsForLevel(int level) => (16 + (level - 1) * 2).clamp(14, 40);

  /// Occasionally hands out a special ball instead of a plain colored one.
  /// Kept off for level 1 so new players learn the base mechanic first,
  /// then shows up roughly one shot in eight, split evenly between the
  /// three power-up kinds.
  PowerUpType _rollPowerUp(int level) {
    if (level < 2) return PowerUpType.none;
    if (_random.nextDouble() > 0.12) return PowerUpType.none;
    const kinds = [
      PowerUpType.colorBomb,
      PowerUpType.lineBlast,
      PowerUpType.rainbow,
    ];
    return kinds[_random.nextInt(kinds.length)];
  }

  void _setupBoard() {
    final size = _boardSize!;
    final radius = size.width / (_cols * 2);
    final rows = (size.height / (radius * 1.73)).ceil();
    _grid = BubbleGrid(cols: _cols, rows: rows, radius: radius);
    _shooterPosition = Offset(size.width / 2, size.height - radius * 2.5);
  }

  void _fillInitialRows(int level) {
    final grid = _grid!;
    final palette = _paletteForLevel(level);
    final rowCount = (3 + ((level + 1) ~/ 2)).clamp(3, math.max(3, grid.rows - 5));
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < grid.cols; c++) {
        grid.cells[r][c] = palette[_random.nextInt(palette.length)];
      }
    }
  }

  /// Fresh run started from the main menu: resets score and starts at
  /// level 1.
  void _startGame() {
    _score = 0;
    _combo = 0;
    _startLevel(1);
  }

  /// Fresh run started at a specific [level], e.g. from the level-select
  /// map. Resets score/combo just like starting from the main menu.
  void _startAtLevel(int level) {
    _score = 0;
    _combo = 0;
    _startLevel(level);
  }

  /// Opens the 1000-level progression map and, if the player picks a
  /// playable level, starts a fresh run there.
  Future<void> _openLevelSelect() async {
    AudioService.instance.play(SfxSound.tap, volume: 0.6);
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(unlockedLevel: _bestLevel),
      ),
    );
    if (selected != null && mounted) {
      _startAtLevel(selected);
    }
  }

  void _startLevel(int level) {
    if (_boardSize == null) return;
    _setupBoard();
    _fillInitialRows(level);
    final palette = _paletteForLevel(level);
    setState(() {
      _state = GameState.playing;
      _levelResult = LevelResult.none;
      _failReason = null;
      _paused = false;
      _level = level;
      _shotsRemaining = _shotsForLevel(level);
      _combo = 0;
      _isNewHighScore = false;
      _isShooting = false;
      _aimAngle = null;
      _aimPath = null;
      _particles.clear();
      _scorePopups.clear();
      _fallingBubbles.clear();
      _nextColor = palette[_random.nextInt(palette.length)];
      _nextPowerUp = _rollPowerUp(level);
      _nextNextColor = palette[_random.nextInt(palette.length)];
      _nextNextPowerUp = _rollPowerUp(level);
      _shooterBall = Ball(
        position: _shooterPosition,
        radius: _grid!.radius * 0.95,
        color: palette[_random.nextInt(palette.length)],
        powerUp: _rollPowerUp(level),
      );
    });
  }

  void _togglePause() {
    if (_state != GameState.playing) return;
    AudioService.instance.play(SfxSound.tap, volume: 0.6);
    setState(() => _paused = !_paused);
  }

  void _quitToMenu() {
    setState(() {
      _paused = false;
      _state = GameState.menu;
    });
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.05) return;
    if (_state != GameState.playing || _paused || _grid == null) return;

    setState(() {
      _dangerPulseT += dt;
      _updateParticles(dt);
      _updateScorePopups(dt);
      _updateFallingBubbles(dt);
      if (_isShooting) {
        _updateShooterPhysics(dt);
      }
    });
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity += const Offset(0, 260) * dt; // gravity
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _updateScorePopups(double dt) {
    for (final s in _scorePopups) {
      s.life -= dt;
    }
    _scorePopups.removeWhere((s) => s.life <= 0);
  }

  /// Gravity + gentle spin for bubbles that were cut loose from the grid.
  /// They're despawned once they drop below the visible board (or, as a
  /// safety net, once their `life` timer runs out).
  void _updateFallingBubbles(double dt) {
    final maxY = (_boardSize?.height ?? 2000) + 80;
    for (final b in _fallingBubbles) {
      b.velocity += const Offset(0, 900) * dt; // heavier than spark particles
      b.position += b.velocity * dt;
      b.rotation += b.angularVelocity * dt;
      b.life -= dt;
    }
    _fallingBubbles.removeWhere(
      (b) => b.life <= 0 || b.position.dy - b.radius > maxY,
    );
  }

  void _updateShooterPhysics(double dt) {
    final grid = _grid!;
    var pos = _shooterBall.position + _shooterBall.velocity * dt;
    var vel = _shooterBall.velocity;

    // Bounce off side walls.
    if (pos.dx - _shooterBall.radius < 0) {
      pos = Offset(_shooterBall.radius, pos.dy);
      vel = Offset(-vel.dx, vel.dy);
    } else if (pos.dx + _shooterBall.radius > _boardSize!.width) {
      pos = Offset(_boardSize!.width - _shooterBall.radius, pos.dy);
      vel = Offset(-vel.dx, vel.dy);
    }

    _shooterBall.position = pos;
    _shooterBall.velocity = vel;

    // Check collision with ceiling or existing bubbles.
    bool landed = pos.dy - _shooterBall.radius <= 0;
    Color? hitColor;
    if (!landed) {
      outer:
      for (int r = 0; r < grid.rows; r++) {
        for (int c = 0; c < grid.cols; c++) {
          final color = grid.cells[r][c];
          if (color == null) continue;
          final center = Offset(grid.xForCell(r, c), grid.yForRow(r));
          if ((center - pos).distance < grid.radius * 1.9) {
            landed = true;
            hitColor = color;
            break outer;
          }
        }
      }
    }

    if (landed) {
      _lastHitColor = hitColor;
      _resolveLanding();
    }
  }

  void _spawnPopEffects(List<List<int>> cells, Map<String, Color> colorByCell) {
    for (final cell in cells) {
      final key = '${cell[0]},${cell[1]}';
      final color = colorByCell[key] ?? _shooterBall.color;
      final center = Offset(_grid!.xForCell(cell[0], cell[1]), _grid!.yForRow(cell[0]));
      for (int i = 0; i < 7; i++) {
        final angle = _random.nextDouble() * 2 * math.pi;
        final speed = 60 + _random.nextDouble() * 130;
        _particles.add(Particle(
          position: center,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          color: color,
          life: 0.45 + _random.nextDouble() * 0.35,
          size: 3 + _random.nextDouble() * 3,
        ));
      }
    }
  }

  /// Cuts bubbles that lost their connection to the ceiling loose from the
  /// grid so they tumble down under gravity instead of disappearing.
  /// Also sprinkles a small burst of sparks at each origin cell so the
  /// detachment itself still reads as an event.
  void _spawnFallingBubbles(List<List<int>> cells, Map<String, Color> colorByCell) {
    final grid = _grid!;
    for (final cell in cells) {
      final key = '${cell[0]},${cell[1]}';
      final color = colorByCell[key] ?? _shooterBall.color;
      final center = Offset(grid.xForCell(cell[0], cell[1]), grid.yForRow(cell[0]));

      final sideKick = (_random.nextDouble() - 0.5) * 160; // px/s sideways
      final dropKick = 30 + _random.nextDouble() * 70; // small initial fall
      _fallingBubbles.add(FallingBubble(
        position: center,
        velocity: Offset(sideKick, dropKick),
        color: color,
        radius: grid.radius,
        rotation: _random.nextDouble() * 2 * math.pi,
        angularVelocity: (_random.nextDouble() - 0.5) * 7,
      ));

      // A few small sparks at the detachment point for extra punch.
      for (int i = 0; i < 3; i++) {
        final angle = _random.nextDouble() * 2 * math.pi;
        final speed = 30 + _random.nextDouble() * 60;
        _particles.add(Particle(
          position: center,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          color: color,
          life: 0.25 + _random.nextDouble() * 0.2,
          size: 2 + _random.nextDouble() * 2,
        ));
      }
    }
  }

  /// A quick burst of palette-colored sparks at [center] — used to sell a
  /// rainbow ball's "magic" moment even on shots that don't land a match.
  void _spawnRainbowSparkle(Offset center) {
    for (int i = 0; i < 14; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 50 + _random.nextDouble() * 140;
      _particles.add(Particle(
        position: center,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: kPalette[_random.nextInt(kPalette.length)],
        life: 0.35 + _random.nextDouble() * 0.35,
        size: 2.5 + _random.nextDouble() * 3,
      ));
    }
  }

  /// Shared clear-and-cascade path used by a normal 3+ match as well as
  /// every power-up detonation: pops the given [cells], awards
  /// [totalScore], and — unless suppressed — chains into clearing anything
  /// that's now floating free of the ceiling.
  void _clearCells(
    List<List<int>> cells, {
    required Offset popupAnchor,
    required int totalScore,
    SfxSound sound = SfxSound.pop,
    bool heavyHaptic = false,
    bool triggerCascade = true,
  }) {
    if (cells.isEmpty) return;
    final grid = _grid!;
    final colorByCell = {
      for (final cell in cells) '${cell[0]},${cell[1]}': grid.cells[cell[0]][cell[1]]!
    };
    _spawnPopEffects(cells, colorByCell);
    for (final cell in cells) {
      grid.cells[cell[0]][cell[1]] = null;
    }
    _score += totalScore;
    _scorePopups.add(ScorePopup(position: popupAnchor, amount: totalScore));
    if (heavyHaptic) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    AudioService.instance.play(sound);

    if (!triggerCascade) return;
    final floating = grid.findFloating();
    if (floating.isNotEmpty) {
      final floatColors = {
        for (final cell in floating)
          '${cell[0]},${cell[1]}': grid.cells[cell[0]][cell[1]]!
      };
      _spawnFallingBubbles(floating, floatColors);
      final bonus = floating.length * 15;
      for (final cell in floating) {
        grid.cells[cell[0]][cell[1]] = null;
      }
      _score += bonus;
      _scorePopups.add(ScorePopup(
        position: Offset(_shooterPosition.dx, _shooterPosition.dy - 46),
        amount: bonus,
      ));
      HapticFeedback.heavyImpact();
      AudioService.instance.play(SfxSound.floatBonus);
    }
  }

  void _resolveLanding() {
    final grid = _grid!;
    final snap = grid.findSnapCell(_shooterBall.position.dx, _shooterBall.position.dy);
    _isShooting = false;
    _aimPath = null;

    if (snap == null) {
      // No room to land (grid essentially full) — treat as a loss rather
      // than getting stuck.
      _failLevel('No space left!');
      return;
    }

    final row = snap[0], col = snap[1];
    final landedCenter = Offset(grid.xForCell(row, col), grid.yForRow(row));

    switch (_shooterBall.powerUp) {
      case PowerUpType.colorBomb:
        _resolveColorBomb(row, col, landedCenter);
        break;
      case PowerUpType.lineBlast:
        _resolveLineBlast(row, col, landedCenter);
        break;
      case PowerUpType.rainbow:
        _resolveRainbow(row, col, landedCenter);
        break;
      case PowerUpType.none:
        _resolveNormalLanding(row, col, landedCenter);
        break;
    }

    _checkLevelState();
  }

  /// Ordinary landing: place the ball's own color and pop a 3+ match, same
  /// behavior as before power-ups existed. Also reused by the rainbow ball
  /// once it has resolved itself into a real color via [colorOverride].
  void _resolveNormalLanding(
    int row,
    int col,
    Offset landedCenter, {
    Color? colorOverride,
  }) {
    final grid = _grid!;
    final color = colorOverride ?? _shooterBall.color;
    grid.cells[row][col] = color;

    final match = grid.floodMatch(row, col);
    if (match.length >= 3) {
      _combo++;
      final multiplier = 1 + (_combo - 1) * 0.2;
      final gained = (match.length * 10 * multiplier).round();
      _clearCells(match, popupAnchor: landedCenter, totalScore: gained);
    } else {
      _combo = 0;
      HapticFeedback.lightImpact();
    }
  }

  /// Color Bomb: detonates on landing and clears every bubble sharing the
  /// color it struck (or, failing that, whichever color surrounds it, or
  /// any color left on the board) — no 3-in-a-row required.
  void _resolveColorBomb(int row, int col, Offset landedCenter) {
    final grid = _grid!;
    final target = _lastHitColor ??
        grid.mostCommonNeighborColor(row, col) ??
        grid.anyOccupiedColor();
    final cells = target == null ? <List<int>>[] : grid.cellsOfColor(target);
    if (cells.isEmpty) {
      _combo = 0;
      HapticFeedback.lightImpact();
      return;
    }
    _combo++;
    final multiplier = 1 + (_combo - 1) * 0.2;
    final gained = (cells.length * 22 * multiplier).round();
    _clearCells(
      cells,
      popupAnchor: landedCenter,
      totalScore: gained,
      sound: SfxSound.floatBonus,
      heavyHaptic: true,
    );
  }

  /// Line Blast: detonates on landing and clears the entire row it settled
  /// into, regardless of color.
  void _resolveLineBlast(int row, int col, Offset landedCenter) {
    final grid = _grid!;
    final cells = grid.cellsInRow(row);
    if (cells.isEmpty) {
      _combo = 0;
      HapticFeedback.lightImpact();
      return;
    }
    _combo++;
    final multiplier = 1 + (_combo - 1) * 0.2;
    final gained = (cells.length * 18 * multiplier).round();
    _clearCells(
      cells,
      popupAnchor: landedCenter,
      totalScore: gained,
      sound: SfxSound.floatBonus,
      heavyHaptic: true,
    );
  }

  /// Rainbow Ball: a wildcard that "becomes" whichever neighboring color
  /// would form the biggest match, then resolves exactly like a normal
  /// landing of that color. Falls back to a random palette color (still a
  /// perfectly normal landing) if it happens to touch nothing.
  void _resolveRainbow(int row, int col, Offset landedCenter) {
    final grid = _grid!;
    final palette = _paletteForLevel(_level);
    final resolvedColor = grid.bestMatchNeighborColor(row, col) ??
        palette[_random.nextInt(palette.length)];
    _spawnRainbowSparkle(landedCenter);
    _resolveNormalLanding(row, col, landedCenter, colorOverride: resolvedColor);
  }

  void _checkLevelState() {
    final grid = _grid!;

    if (grid.isEmpty) {
      _completeLevel();
      return;
    }

    final thresholdRow =
        ((_shooterPosition.dy - grid.radius) / grid.rowHeight).floor();
    if (grid.anyBubbleAtOrBelowRow(thresholdRow)) {
      _failLevel('Bubbles reached the red line!');
      return;
    }

    if (_shotsRemaining <= 0) {
      _failLevel('Out of shots!');
      return;
    }

    _loadNextBall();
  }

  void _loadNextBall() {
    final palette = _paletteForLevel(_level);
    _shooterBall = Ball(
      position: _shooterPosition,
      radius: _grid!.radius * 0.95,
      color: _nextColor,
      powerUp: _nextPowerUp,
    );
    _nextColor = _nextNextColor;
    _nextPowerUp = _nextNextPowerUp;
    _nextNextColor = palette[_random.nextInt(palette.length)];
    _nextNextPowerUp = _rollPowerUp(_level);
  }

  Future<void> _completeLevel() async {
    _levelResult = LevelResult.complete;
    _state = GameState.gameOver;
    HapticFeedback.mediumImpact();
    AudioService.instance.play(SfxSound.win);
    AdService.instance.showInterstitial();
    final isNew = await HighScoreService.saveIfHighScore(_score);
    await HighScoreService.saveIfBestLevel(_level + 1);
    if (!mounted) return;
    setState(() {
      _isNewHighScore = isNew;
      if (isNew) _highScore = _score;
      if (_level + 1 > _bestLevel) _bestLevel = _level + 1;
    });
  }

  Future<void> _failLevel(String reason) async {
    _levelResult = LevelResult.failed;
    _failReason = reason;
    _state = GameState.gameOver;
    HapticFeedback.heavyImpact();
    AudioService.instance.play(SfxSound.lose);
    AdService.instance.showInterstitial();
    final isNew = await HighScoreService.saveIfHighScore(_score);
    if (!mounted) return;
    setState(() {
      _isNewHighScore = isNew;
      if (isNew) _highScore = _score;
    });
  }

  double _clampAngle(double angle) {
    const maxTilt = 75 * math.pi / 180;
    return angle.clamp(-maxTilt, maxTilt);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_state != GameState.playing || _paused || _isShooting) return;
    final delta = details.localPosition - _shooterPosition;
    final angle = math.atan2(delta.dx, -delta.dy);
    setState(() {
      _aimAngle = _clampAngle(angle);
      _aimPath = computeAimPath(
        start: _shooterPosition,
        angle: _aimAngle!,
        boardSize: _boardSize!,
        grid: _grid!,
        ballRadius: _shooterBall.radius,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_state != GameState.playing ||
        _paused ||
        _isShooting ||
        _aimAngle == null ||
        _shotsRemaining <= 0) {
      return;
    }
    final angle = _aimAngle!;
    HapticFeedback.selectionClick();
    AudioService.instance.play(SfxSound.shoot);
    setState(() {
      _shotsRemaining--;
      _shooterBall.velocity = Offset(
        math.sin(angle) * _shotSpeed,
        -math.cos(angle) * _shotSpeed,
      );
      _isShooting = true;
      _aimAngle = null;
      _aimPath = null;
    });
  }

  /// Tapping directly on the shooter ball swaps it with the upcoming
  /// "next" ball — color and any power-up together — unlimited uses, as
  /// long as a shot isn't already in flight.
  void _onTapUp(TapUpDetails details) {
    if (_state != GameState.playing || _paused || _isShooting) return;
    final dist = (details.localPosition - _shooterPosition).distance;
    if (dist > _shooterBall.radius * 2.4) return;
    setState(() {
      final swappedColor = _shooterBall.color;
      final swappedPowerUp = _shooterBall.powerUp;
      _shooterBall = Ball(
        position: _shooterBall.position,
        radius: _shooterBall.radius,
        color: _nextColor,
        powerUp: _nextPowerUp,
      );
      _nextColor = swappedColor;
      _nextPowerUp = swappedPowerUp;
    });
    HapticFeedback.selectionClick();
    AudioService.instance.play(SfxSound.tap);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F17),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHud(),
                Expanded(
                  child: GestureDetector(
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onTapUp: _onTapUp,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final newSize =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        if (_boardSize != newSize) {
                          _boardSize = newSize;
                          if (_grid == null && _state != GameState.playing) {
                            _setupBoard();
                          }
                        }
                        if (_grid == null) return const SizedBox.shrink();

                        final thresholdRow =
                            ((_shooterPosition.dy - _grid!.radius) / _grid!.rowHeight)
                                .floor();
                        final pulse = (math.sin(_dangerPulseT * 4) + 1) / 2;

                        return CustomPaint(
                          size: Size.infinite,
                          painter: BubbleShooterPainter(
                            grid: _grid!,
                            shooterBall: _state == GameState.playing
                                ? _shooterBall
                                : Ball(
                                    position: _shooterPosition,
                                    radius: _grid!.radius * 0.95,
                                    color: kPalette.first,
                                  ),
                            shooterPosition: _shooterPosition,
                            aimAngle: _aimAngle,
                            aimPath: _aimPath,
                            particles: _particles,
                            scorePopups: _scorePopups,
                            fallingBubbles: _fallingBubbles,
                            dangerRow: thresholdRow,
                            dangerPulse: pulse,
                            canSwap: _state == GameState.playing && !_paused && !_isShooting,
                            animT: _dangerPulseT,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
            if (_state == GameState.menu)
              MenuOverlay(
                mode: OverlayMode.start,
                score: _score,
                highScore: _highScore,
                bestLevel: _bestLevel,
                onPlay: _startGame,
                onSelectLevel: _openLevelSelect,
              ),
            if (_state == GameState.gameOver && _levelResult == LevelResult.complete)
              MenuOverlay(
                mode: OverlayMode.levelComplete,
                score: _score,
                highScore: _highScore,
                isNewHighScore: _isNewHighScore,
                level: _level,
                bestLevel: _bestLevel,
                onPlay: () => _startLevel(_level + 1),
              ),
            if (_state == GameState.gameOver && _levelResult == LevelResult.failed)
              MenuOverlay(
                mode: OverlayMode.levelFailed,
                score: _score,
                highScore: _highScore,
                level: _level,
                bestLevel: _bestLevel,
                failReason: _failReason,
                onPlay: () => _startLevel(_level),
                onQuit: _quitToMenu,
              ),
            if (_state == GameState.playing && _paused)
              MenuOverlay(
                mode: OverlayMode.paused,
                score: _score,
                highScore: _highScore,
                level: _level,
                onPlay: _togglePause,
                onQuit: _quitToMenu,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.09)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFF64FFDA)],
                              ).createShader(bounds),
                              child: Text(
                                'Level $_level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ComboBadge(combo: _combo),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 13, color: Colors.amberAccent),
                            const SizedBox(width: 3),
                            _AnimatedScoreText(score: _score),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.gps_fixed_rounded,
                              size: 13,
                              color: _shotsRemaining <= 3
                                  ? Colors.redAccent
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$_shotsRemaining',
                              style: TextStyle(
                                color: _shotsRemaining <= 3
                                    ? Colors.redAccent
                                    : Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNextQueue(),
                        const SizedBox(width: 6),
                        _MuteButton(muted: _muted, onTap: _toggleMute),
                        if (_state == GameState.playing) ...[
                          const SizedBox(width: 6),
                          _PauseButton(paused: _paused, onTap: _togglePause),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextQueue() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('NEXT',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              )),
          const SizedBox(width: 7),
          _queueDot(_nextColor, _nextPowerUp, 20,
              key: ValueKey('n1_${_nextColor}_$_nextPowerUp')),
          const SizedBox(width: 5),
          _queueDot(_nextNextColor, _nextNextPowerUp, 13,
              key: ValueKey('n2_${_nextNextColor}_$_nextNextPowerUp')),
        ],
      ),
    );
  }

  /// A queue preview dot: a plain color swatch for an ordinary ball, or a
  /// badge with the power-up's icon and accent color when a special ball
  /// is up next, so the player can plan their shot in advance.
  Widget _queueDot(Color color, PowerUpType powerUp, double size, {Key? key}) {
    if (!powerUp.isPowerUp) {
      return _colorDot(color, size, key: key);
    }
    final info = powerUp.info;
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: powerUp == PowerUpType.rainbow
            ? const SweepGradient(colors: [
                Color(0xFFE53935),
                Color(0xFFFDD835),
                Color(0xFF43A047),
                Color(0xFF1E88E5),
                Color(0xFF8E24AA),
                Color(0xFFE53935),
              ])
            : RadialGradient(
                center: const Alignment(-0.35, -0.4),
                colors: [
                  Color.lerp(info.accent, Colors.white, 0.4)!,
                  info.accent,
                ],
              ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: info.accent.withOpacity(0.7),
            blurRadius: 7,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Icon(info.icon, size: size * 0.62, color: Colors.white),
    );
  }

  Widget _colorDot(Color color, double size, {Key? key}) {
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.5)!, color],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

/// Animated mute/unmute control with a soft glass pill background.
class _MuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;
  const _MuteButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              key: ValueKey(muted),
              color: Colors.white70,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pause/play control with a soft glass pill background.
class _PauseButton extends StatelessWidget {
  final bool paused;
  final VoidCallback onTap;
  const _PauseButton({required this.paused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              key: ValueKey(paused),
              color: Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Score number that smoothly counts up/down whenever [score] changes,
/// instead of snapping instantly.
class _AnimatedScoreText extends StatefulWidget {
  final int score;
  const _AnimatedScoreText({required this.score});

  @override
  State<_AnimatedScoreText> createState() => _AnimatedScoreTextState();
}

class _AnimatedScoreTextState extends State<_AnimatedScoreText> {
  int _displayed = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.score;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _displayed, end: widget.score),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      onEnd: () => _displayed = widget.score,
      builder: (context, value, child) => Text(
        'Score: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

/// Combo counter that pops with a little bounce every time the streak
/// grows, and fades out entirely when the combo resets.
class _ComboBadge extends StatelessWidget {
  final int combo;
  const _ComboBadge({required this.combo});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: combo > 1
          ? Container(
              key: ValueKey(combo),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC857), Color(0xFFFF8C42)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                '🔥 x$combo',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no-combo')),
    );
  }
}

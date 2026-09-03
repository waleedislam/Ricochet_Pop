import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/level_progress.dart';
import '../services/level_progress_service.dart';
import 'game_screen.dart' show kPalette;

/// A vertically scrolling "world map" of level nodes that snakes left and
/// right, grouped into worlds of [LevelSelectScreen.worldSize] levels each.
///
/// Only levels up to and including [unlockedLevel] are playable — anything
/// beyond that is shown locked. Tapping a playable node pops this screen
/// with the chosen level number; tapping back (or a locked node) never
/// returns a level.
class LevelSelectScreen extends StatefulWidget {
  final int unlockedLevel;

  static const int totalLevels = 1000;
  static const int worldSize = 25;

  const LevelSelectScreen({super.key, required this.unlockedLevel});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

/// A single row in the map: either a level node or a "World N" banner.
class _MapNode {
  final bool isHeader;
  final int number; // level number, or world number when isHeader is true
  final double alignX; // 0..1 horizontal position within the row

  const _MapNode.level(this.number, this.alignX) : isHeader = false;
  const _MapNode.header(this.number, this.alignX) : isHeader = true;
}

/// A visual theme applied to the backdrop behind a range of 25 levels
/// ("one world"). No image assets involved — each theme is a gradient
/// plus a single faint watermark icon, so it's copyright-free, adds
/// zero asset weight, and still gives every world a distinct look.
class _WorldTheme {
  final String name;
  final List<Color> gradient;
  final Color accent;
  final IconData motif;
  const _WorldTheme({
    required this.name,
    required this.gradient,
    required this.accent,
    required this.motif,
  });
}

const List<_WorldTheme> _worldThemes = [
  _WorldTheme(
    name: 'Ocean',
    gradient: [Color(0xFF0B2447), Color(0xFF07162E)],
    accent: Color(0xFF64FFDA),
    motif: Icons.water_rounded,
  ),
  _WorldTheme(
    name: 'Sunset',
    gradient: [Color(0xFF3D0C11), Color(0xFF1C0509)],
    accent: Color(0xFFFF8C42),
    motif: Icons.wb_twilight_rounded,
  ),
  _WorldTheme(
    name: 'Forest',
    gradient: [Color(0xFF0B2E1F), Color(0xFF06170F)],
    accent: Color(0xFF7CE38B),
    motif: Icons.park_rounded,
  ),
  _WorldTheme(
    name: 'Galaxy',
    gradient: [Color(0xFF14103A), Color(0xFF080619)],
    accent: Color(0xFFB39DDB),
    motif: Icons.auto_awesome_rounded,
  ),
  _WorldTheme(
    name: 'Candy',
    gradient: [Color(0xFF33103B), Color(0xFF190819)],
    accent: Color(0xFFFF7AC6),
    motif: Icons.icecream_rounded,
  ),
  _WorldTheme(
    name: 'Volcano',
    gradient: [Color(0xFF2E0A0A), Color(0xFF150404)],
    accent: Color(0xFFFF6B4A),
    motif: Icons.local_fire_department_rounded,
  ),
  _WorldTheme(
    name: 'Glacier',
    gradient: [Color(0xFF0A2A33), Color(0xFF051519)],
    accent: Color(0xFF8DE9FF),
    motif: Icons.ac_unit_rounded,
  ),
  _WorldTheme(
    name: 'Desert',
    gradient: [Color(0xFF2E1D0A), Color(0xFF160E04)],
    accent: Color(0xFFFFC857),
    motif: Icons.wb_sunny_rounded,
  ),
  _WorldTheme(
    name: 'Neon City',
    gradient: [Color(0xFF1B0A2E), Color(0xFF0D0416)],
    accent: Color(0xFFFF4FD8),
    motif: Icons.location_city_rounded,
  ),
  _WorldTheme(
    name: 'Aurora',
    gradient: [Color(0xFF06232A), Color(0xFF041014)],
    accent: Color(0xFF64FFDA),
    motif: Icons.blur_on_rounded,
  ),
];

_WorldTheme _themeForWorld(int world) =>
    _worldThemes[(world - 1) % _worldThemes.length];

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  static const double _levelRowHeight = 108;
  static const double _headerRowHeight = 64;
  static const double _horizontalInset = 26;

  // Repeating left/right pattern that gives the path its "snake" shape.
  static const List<double> _pattern = [
    0.50, 0.74, 0.86, 0.74, 0.50, 0.26, 0.14, 0.26,
  ];

  late final List<_MapNode> _nodes;
  late final List<double> _offsets; // cumulative top offset of every node
  late final List<int> _worldOfNode; // which world each node in _nodes belongs to
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  int _currentWorld = 1;
  Map<int, LevelProgress> _progress = {};

  int get _unlocked =>
      widget.unlockedLevel.clamp(1, LevelSelectScreen.totalLevels);

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes();
    _offsets = _buildOffsets();
    _worldOfNode = _buildWorldOfNode();
    _currentWorld =
        ((_unlocked - 1) ~/ LevelSelectScreen.worldSize) + 1;
    _scrollController = ScrollController()
      ..addListener(_updateCurrentWorldFromScroll);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _jumpToCurrent(animate: false));
    LevelProgressService.getAll().then((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<int> _buildWorldOfNode() {
    final worlds = <int>[];
    for (final n in _nodes) {
      final level = n.isHeader
          ? (n.number - 1) * LevelSelectScreen.worldSize + 1
          : n.number;
      worlds.add(((level - 1) ~/ LevelSelectScreen.worldSize) + 1);
    }
    return worlds;
  }

  /// Finds which world is at the top of the viewport right now and, if it
  /// changed since the last frame, updates [_currentWorld] so the backdrop
  /// crossfades to that world's theme.
  void _updateCurrentWorldFromScroll() {
    if (!_scrollController.hasClients) return;
    final scrollTop = _scrollController.position.pixels;
    int idx = 0;
    for (int i = 0; i < _offsets.length - 1; i++) {
      if (_offsets[i] > scrollTop) break;
      idx = i;
    }
    final world = idx < _worldOfNode.length ? _worldOfNode[idx] : _currentWorld;
    if (world != _currentWorld) {
      setState(() => _currentWorld = world);
    }
  }

  List<_MapNode> _buildNodes() {
    final nodes = <_MapNode>[];
    int patternIdx = 0;
    for (int lvl = 1; lvl <= LevelSelectScreen.totalLevels; lvl++) {
      if ((lvl - 1) % LevelSelectScreen.worldSize == 0) {
        final world = (lvl - 1) ~/ LevelSelectScreen.worldSize + 1;
        nodes.add(_MapNode.header(world, 0.5));
      }
      nodes.add(_MapNode.level(lvl, _pattern[patternIdx % _pattern.length]));
      patternIdx++;
    }
    return nodes;
  }

  List<double> _buildOffsets() {
    final offsets = <double>[];
    double y = 0;
    for (final n in _nodes) {
      offsets.add(y);
      y += n.isHeader ? _headerRowHeight : _levelRowHeight;
    }
    offsets.add(y); // sentinel: total scrollable content height
    return offsets;
  }

  int _indexForLevel(int level) {
    for (int i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      if (!n.isHeader && n.number == level) return i;
    }
    return -1;
  }

  bool _isUnlockedNode(_MapNode n) {
    if (!n.isHeader) return n.number <= _unlocked;
    final firstLevelOfWorld = (n.number - 1) * LevelSelectScreen.worldSize + 1;
    return firstLevelOfWorld <= _unlocked;
  }

  void _jumpToCurrent({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final idx = _indexForLevel(_unlocked);
    if (idx < 0) return;
    final viewport = _scrollController.position.viewportDimension;
    final maxScroll = (_offsets.last - viewport).clamp(0.0, double.infinity);
    final target = (_offsets[idx] - viewport / 2 + _levelRowHeight / 2)
        .clamp(0.0, maxScroll);
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _onSelect(int level) {
    if (level > _unlocked) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F17),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackdrop(),
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 48),
                    itemCount: _nodes.length,
                    itemBuilder: (context, index) => _buildRow(index),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulseController.value);
          return Transform.scale(scale: 1.0 + t * 0.05, child: child);
        },
        child: FloatingActionButton.extended(
          onPressed: () => _jumpToCurrent(),
          backgroundColor: const Color(0xFFFF5A52),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.gps_fixed_rounded),
          label: Text('Level $_unlocked'),
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    final theme = _themeForWorld(_currentWorld);
    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: Stack(
          children: [
            // Radial highlight to keep the original depth/vignette feel.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.4,
                  colors: [Colors.white10, Colors.transparent],
                ),
              ),
            ),
            // A single large, very faint watermark icon that crossfades
            // per world — the "different background per world" cue.
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0.15, -0.1),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Icon(
                    theme.motif,
                    key: ValueKey(theme.name),
                    size: 320,
                    color: theme.accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF64FFDA)],
                  ).createShader(bounds),
                  child: const Text(
                    'Select Level',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '${LevelSelectScreen.totalLevels} levels • unlocked up to $_unlocked',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final node = _nodes[index];
    final nextNode = index + 1 < _nodes.length ? _nodes[index + 1] : null;
    final height = node.isHeader ? _headerRowHeight : _levelRowHeight;
    final topActive = _isUnlockedNode(node);
    final bottomActive = nextNode != null && _isUnlockedNode(nextNode);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalInset),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PathPainter(
                hasIncoming: index > 0,
                thisX: node.alignX,
                nextX: nextNode?.alignX,
                topActive: topActive,
                bottomActive: bottomActive,
              ),
            ),
            Align(
              alignment: Alignment(node.alignX * 2 - 1, 0),
              child: node.isHeader
                  ? _WorldBadge(
                      world: node.number,
                      theme: _themeForWorld(node.number),
                    )
                  : _LevelNode(
                      level: node.number,
                      unlockedLevel: _unlocked,
                      pulse: _pulseController,
                      stars: _progress[node.number]?.stars,
                      onTap: () => _onSelect(node.number),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the connecting path segments that lead into and out of a node.
/// Each row only ever paints within its own bounds: a straight stub from
/// the top edge down to the node (matching where the previous row's curve
/// arrived), and a curve from the node down to the bottom edge (at the x
/// position where the next row's node will be).
class _PathPainter extends CustomPainter {
  final bool hasIncoming;
  final double thisX;
  final double? nextX;
  final bool topActive;
  final bool bottomActive;

  _PathPainter({
    required this.hasIncoming,
    required this.thisX,
    required this.nextX,
    required this.topActive,
    required this.bottomActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = const Color(0xFF64FFDA).withValues(alpha: 0.85)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * thisX, size.height / 2);

    if (hasIncoming) {
      final top = Offset(size.width * thisX, 0);
      canvas.drawLine(top, center, topActive ? activePaint : dimPaint);
    }

    final nx = nextX;
    if (nx != null) {
      final bottom = Offset(size.width * nx, size.height);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx,
          size.height * 0.78,
          (center.dx + bottom.dx) / 2,
          size.height * 0.85,
        )
        ..quadraticBezierTo(
          bottom.dx,
          size.height * 0.92,
          bottom.dx,
          size.height,
        );
      canvas.drawPath(path, bottomActive ? activePaint : dimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.thisX != thisX ||
      oldDelegate.nextX != nextX ||
      oldDelegate.topActive != topActive ||
      oldDelegate.bottomActive != bottomActive ||
      oldDelegate.hasIncoming != hasIncoming;
}

/// A single tappable level node: locked (grey + lock icon), completed
/// (colored + check badge), current (colored + pulsing glow), or a future
/// level that just isn't reachable yet.
class _LevelNode extends StatefulWidget {
  final int level;
  final int unlockedLevel;
  final AnimationController pulse;
  final int? stars; // null = never completed yet
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.unlockedLevel,
    required this.pulse,
    this.stars,
    required this.onTap,
  });

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  bool get _locked => widget.level > widget.unlockedLevel;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_locked) {
      _shake.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    final isCurrent = widget.level == widget.unlockedLevel;
    final completed = widget.level < widget.unlockedLevel;
    final color = kPalette[(widget.level - 1) % kPalette.length];

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.pulse, _shake]),
        builder: (context, child) {
          final t =
              isCurrent ? Curves.easeInOut.transform(widget.pulse.value) : 0.0;
          // A quick playful "no!" wobble — a couple of decaying side-to-side
          // shakes — when the player taps a level they haven't unlocked yet.
          final shakeT = _shake.value;
          final shakeOffset =
              math.sin(shakeT * math.pi * 6) * 6 * (1 - shakeT);
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: Transform.scale(
              scale: isCurrent ? 1.0 + t * 0.08 : 1.0,
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: locked
                    ? null
                    : RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                      ),
                color: locked ? const Color(0xFF1B2836) : null,
                border: Border.all(
                  color: isCurrent
                      ? Colors.white
                      : locked
                          ? Colors.white24
                          : Colors.white38,
                  width: isCurrent ? 2.6 : 1.6,
                ),
                boxShadow: [
                  if (!locked)
                    BoxShadow(
                      color: (isCurrent ? Colors.white : color)
                          .withValues(alpha: isCurrent ? 0.55 : 0.35),
                      blurRadius: isCurrent ? 22 : 10,
                      spreadRadius: isCurrent ? 1 : 0,
                    ),
                ],
              ),
              child: locked
                  ? const Icon(Icons.lock_rounded, color: Colors.white38, size: 22)
                  : completed
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${widget.level}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF43A047),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '${widget.level}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
            ),
            if (widget.stars != null) ...[
              const SizedBox(height: 3),
              _StarRow(stars: widget.stars!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three tiny stars showing how well a level was cleared (1–3).
class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < stars;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 12,
          color: filled ? const Color(0xFFFFC857) : Colors.white24,
        );
      }),
    );
  }
}

/// Decorative pill shown at the start of every 25-level "world".
class _WorldBadge extends StatefulWidget {
  final int world;
  final _WorldTheme theme;
  const _WorldBadge({required this.world, required this.theme});

  @override
  State<_WorldBadge> createState() => _WorldBadgeState();
}

class _WorldBadgeState extends State<_WorldBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1.0 + t * 0.03, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.theme.accent, Color.lerp(widget.theme.accent, Colors.black, 0.35)!],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: widget.theme.accent.withValues(alpha: 0.25 + 0.2 * _c.value), blurRadius: 8 + 6 * _c.value),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.theme.motif, size: 13, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                'WORLD ${widget.world} · ${widget.theme.name.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;

  int get _unlocked =>
      widget.unlockedLevel.clamp(1, LevelSelectScreen.totalLevels);

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes();
    _offsets = _buildOffsets();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _jumpToCurrent(animate: false));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _jumpToCurrent(),
        backgroundColor: const Color(0xFFFF5A52),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.gps_fixed_rounded),
        label: Text('Level $_unlocked'),
      ),
    );
  }

  Widget _buildBackdrop() {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [Color(0xFF16233A), Color(0xFF0A0F17)],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 2),
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
                  ? _WorldBadge(world: node.number)
                  : _LevelNode(
                      level: node.number,
                      unlockedLevel: _unlocked,
                      pulse: _pulseController,
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
      ..color = const Color(0xFF64FFDA).withOpacity(0.85)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dimPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
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
class _LevelNode extends StatelessWidget {
  final int level;
  final int unlockedLevel;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.unlockedLevel,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = level > unlockedLevel;
    final isCurrent = level == unlockedLevel;
    final completed = level < unlockedLevel;
    final color = kPalette[(level - 1) % kPalette.length];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = isCurrent ? Curves.easeInOut.transform(pulse.value) : 0.0;
          return Transform.scale(
            scale: isCurrent ? 1.0 + t * 0.08 : 1.0,
            child: child,
          );
        },
        child: Container(
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
                      .withOpacity(isCurrent ? 0.55 : 0.35),
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
                          '$level',
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
                      '$level',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
        ),
      ),
    );
  }
}

/// Decorative pill shown at the start of every 25-level "world".
class _WorldBadge extends StatelessWidget {
  final int world;
  const _WorldBadge({required this.world});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC857), Color(0xFFFF8C42)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: Text(
        'WORLD $world',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/power_up.dart';

/// Which overlay screen is currently showing.
enum OverlayMode { start, levelComplete, levelFailed, paused }

class MenuOverlay extends StatefulWidget {
  final OverlayMode mode;
  final int score;
  final int highScore;
  final bool isNewHighScore;
  final int level;
  final int bestLevel;
  final String? failReason;
  final VoidCallback onPlay;
  final VoidCallback? onQuit;
  final VoidCallback? onSelectLevel;

  const MenuOverlay({
    super.key,
    required this.mode,
    required this.score,
    required this.highScore,
    required this.onPlay,
    this.isNewHighScore = false,
    this.level = 1,
    this.bestLevel = 1,
    this.failReason,
    this.onQuit,
    this.onSelectLevel,
  });

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _ambient;
  final List<_BubbleSpec> _bubbles = _generateBubbleField();

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.mode) {
      case OverlayMode.levelComplete:
        return const Color(0xFF43A047);
      case OverlayMode.levelFailed:
        return const Color(0xFFE53935);
      case OverlayMode.paused:
        return const Color(0xFF64FFDA);
      case OverlayMode.start:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Rich dark gradient (instead of a flat dim) + subtle blur so the
        // board still reads through behind everything.
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    _accent.withOpacity(0.16),
                    const Color(0xFF0B1220).withOpacity(0.72),
                    Colors.black.withOpacity(0.82),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Slow-drifting colorful glow blobs for ambient motion.
        AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) => CustomPaint(
            painter: _AmbientBlobPainter(t: _ambient.value, accent: _accent),
            size: Size.infinite,
          ),
        ),
        // Softly rising bubbles drifting up from the bottom of the screen.
        AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) => CustomPaint(
            painter: _FloatingBubblesPainter(t: _ambient.value, bubbles: _bubbles),
            size: Size.infinite,
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _entrance,
            builder: (context, child) {
              final curved =
                  CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
              final scale = 0.82 + 0.18 * curved.value;
              final fade = _entrance.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: fade,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              child: _Card(
                mode: widget.mode,
                accent: _accent,
                cornerAction: widget.mode == OverlayMode.start
                    ? _InfoButton(onTap: _showHowToPlay)
                    : null,
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingIcon(icon: _icon, color: _accent),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, _accent.withOpacity(0.85)],
          ).createShader(bounds),
          child: Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._buildStaggeredBody(),
        const SizedBox(height: 26),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BouncyButton(
              onPressed: widget.onPlay,
              color: _accent,
              label: _buttonLabel,
              icon: _buttonIcon,
            ),
            if (widget.onQuit != null &&
                (widget.mode == OverlayMode.paused ||
                    widget.mode == OverlayMode.levelFailed)) ...[
              const SizedBox(width: 12),
              _GhostButton(onPressed: widget.onQuit!, label: 'Menu'),
            ],
            if (widget.onSelectLevel != null &&
                widget.mode == OverlayMode.start) ...[
              const SizedBox(width: 12),
              _GhostButton(
                onPressed: widget.onSelectLevel!,
                label: 'Levels',
                icon: Icons.map_rounded,
              ),
            ],
          ],
        ),
      ],
    );
  }

  IconData get _icon {
    switch (widget.mode) {
      case OverlayMode.paused:
        return Icons.pause_circle_filled_rounded;
      case OverlayMode.levelComplete:
        return Icons.emoji_events_rounded;
      case OverlayMode.levelFailed:
        return Icons.sentiment_dissatisfied_rounded;
      case OverlayMode.start:
        return Icons.sports_baseball_rounded;
    }
  }

  IconData get _buttonIcon {
    switch (widget.mode) {
      case OverlayMode.paused:
        return Icons.play_arrow_rounded;
      case OverlayMode.levelComplete:
        return Icons.arrow_forward_rounded;
      case OverlayMode.levelFailed:
        return Icons.refresh_rounded;
      case OverlayMode.start:
        return Icons.play_arrow_rounded;
    }
  }

  String get _title {
    switch (widget.mode) {
      case OverlayMode.paused:
        return 'Paused';
      case OverlayMode.levelComplete:
        return 'Level Complete!';
      case OverlayMode.levelFailed:
        return widget.failReason ?? 'Level Failed';
      case OverlayMode.start:
        return 'Ricochet Pop';
    }
  }

  String get _buttonLabel {
    switch (widget.mode) {
      case OverlayMode.paused:
        return 'Resume';
      case OverlayMode.levelComplete:
        return 'Next Level';
      case OverlayMode.levelFailed:
        return 'Retry Level';
      case OverlayMode.start:
        return 'Play';
    }
  }

  List<Widget> _buildStaggeredBody() {
    final rows = _bodyRows();
    return List.generate(rows.length, (i) {
      return _Staggered(
        controller: _entrance,
        index: i,
        total: rows.length,
        child: rows[i],
      );
    });
  }

  List<Widget> _bodyRows() {
    switch (widget.mode) {
      case OverlayMode.levelComplete:
        return [
          Column(
            children: [
              Text(
                'Level ${widget.level} cleared!',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _ScoreChip(score: widget.score, accent: _accent),
              if (widget.isNewHighScore) ...[
                const SizedBox(height: 10),
                const _HighScoreBadge(),
              ],
            ],
          ),
        ];
      case OverlayMode.levelFailed:
        return [
          Column(
            children: [
              _ScoreChip(score: widget.score, accent: _accent),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.military_tech_rounded,
                      size: 15, color: Colors.white54),
                  const SizedBox(width: 5),
                  Text(
                    'Best Level: ${widget.bestLevel}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                  ),
                ],
              ),
            ],
          ),
        ];
      case OverlayMode.paused:
        return [
          Text(
            'Level ${widget.level}  •  Score ${widget.score}',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ];
      case OverlayMode.start:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(
                icon: Icons.emoji_events_rounded,
                label: '${widget.highScore}',
                color: const Color(0xFFFFC857),
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.flag_rounded,
                label: 'Lv ${widget.bestLevel}',
                color: const Color(0xFF64FFDA),
              ),
            ],
          ),
        ];
    }
  }

  Widget _instructionRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: Colors.white70),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  /// Opens the "How To Play" sheet with the instructions and special-ball
  /// legend that used to live directly on the start screen.
  void _showHowToPlay() {
    showGeneralDialog(
      context: context,
      barrierLabel: 'How to play',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim, secAnim) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.88 + 0.12 * curved.value,
            child: Center(
              child: _HowToPlayCard(
                accent: _accent,
                instructionRow: _instructionRow,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen "How To Play" reference: the rules + special-ball legend,
/// reached via the info icon on the start screen instead of living inline.
class _HowToPlayCard extends StatelessWidget {
  final Color accent;
  final Widget Function(IconData icon, String text) instructionRow;

  const _HowToPlayCard({required this.accent, required this.instructionRow});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      child: _Card(
        mode: OverlayMode.start,
        accent: accent,
        cornerAction: _CloseButton(onTap: () => Navigator.of(context).pop()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How To Play',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 18),
            instructionRow(Icons.touch_app_rounded, 'Drag to aim the laser sight'),
            const SizedBox(height: 12),
            instructionRow(Icons.blur_circular_rounded, 'Match 3+ same colors to pop them'),
            const SizedBox(height: 12),
            instructionRow(Icons.swap_horiz_rounded, 'Tap your ball to swap its color, unlimited'),
            const SizedBox(height: 12),
            instructionRow(Icons.warning_amber_rounded, "Don't let bubbles reach the red line"),
            const SizedBox(height: 12),
            instructionRow(Icons.flag_rounded, 'Clear the board before shots run out'),
            const SizedBox(height: 18),
            const _PowerUpLegend(),
          ],
        ),
      ),
    );
  }
}

/// Small circular "i" button shown top-right on the start screen.
class _InfoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Small circular close ("x") button used on the How To Play card.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 18,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Small reference card on the start screen showing the three special
/// balls the player might draw and what each one does.
class _PowerUpLegend extends StatelessWidget {
  const _PowerUpLegend();

  static const _kinds = [
    PowerUpType.colorBomb,
    PowerUpType.lineBlast,
    PowerUpType.rainbow,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const Text(
            'SPECIAL BALLS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ..._kinds.map((kind) {
            final info = kind.info;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: kind == PowerUpType.rainbow
                          ? const SweepGradient(colors: [
                              Color(0xFFE53935),
                              Color(0xFFFDD835),
                              Color(0xFF43A047),
                              Color(0xFF1E88E5),
                              Color(0xFF8E24AA),
                              Color(0xFFE53935),
                            ])
                          : RadialGradient(colors: [
                              Color.lerp(info.accent, Colors.white, 0.4)!,
                              info.accent,
                            ]),
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                    child: Icon(info.icon, size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, height: 1.25),
                        children: [
                          TextSpan(
                            text: '${info.label}: ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: info.description,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Fades + slides each body row in with a small per-index delay.
class _Staggered extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final Widget child;

  const _Staggered({
    required this.controller,
    required this.index,
    required this.total,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = 0.15 + (index / math.max(total, 1)) * 0.35;
    final end = (start + 0.5).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 12),
          child: c,
        ),
      ),
      child: Padding(padding: const EdgeInsets.only(bottom: 2), child: child),
    );
  }
}

/// Glass card shell with gradient border + soft shadow that hosts overlay
/// content.
class _Card extends StatelessWidget {
  final OverlayMode mode;
  final Color accent;
  final Widget child;
  final Widget? cornerAction;

  const _Card({
    required this.mode,
    required this.accent,
    required this.child,
    this.cornerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF223449).withOpacity(0.92),
                  const Color(0xFF0F1721).withOpacity(0.96),
                ],
              ),
              border: Border.all(color: accent.withOpacity(0.25), width: 1.4),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: child,
                ),
                if (cornerAction != null)
                  Positioned(top: 0, right: 0, child: cornerAction!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon with a soft breathing glow behind it.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
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
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.35 + t * 0.15),
                widget.color.withOpacity(0.0),
              ],
            ),
          ),
          child: Transform.scale(
            scale: 1.0 + t * 0.06,
            child: Icon(widget.icon, size: 46, color: widget.color),
          ),
        );
      },
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int score;
  final Color accent;
  const _ScoreChip({required this.score, required this.accent});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: score),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Text(
          'Score: $value',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighScoreBadge extends StatefulWidget {
  const _HighScoreBadge();
  @override
  State<_HighScoreBadge> createState() => _HighScoreBadgeState();
}

class _HighScoreBadgeState extends State<_HighScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
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
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1.0 + t * 0.05,
          child: Text(
            '🎉 New High Score!',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.amber.withOpacity(0.6 * t), blurRadius: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Primary action button with a press-down scale + gradient fill.
class _BouncyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final String label;
  final IconData icon;

  const _BouncyButton({
    required this.onPressed,
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  State<_BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<_BouncyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.25)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_pressed ? 0.15 : 0.4),
                blurRadius: _pressed ? 6 : 16,
                offset: Offset(0, _pressed ? 2 : 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 19, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  const _GhostButton({required this.onPressed, required this.label, this.icon});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_pressed ? 0.05 : 0.02),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: Colors.white70),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two soft, slowly-orbiting glow blobs behind the card for ambient motion.
class _AmbientBlobPainter extends CustomPainter {
  final double t; // 0..1 looping
  final Color accent;
  _AmbientBlobPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi;
    final c1 = Offset(
      size.width * 0.5 + math.cos(angle) * size.width * 0.32,
      size.height * 0.35 + math.sin(angle) * size.height * 0.18,
    );
    final c2 = Offset(
      size.width * 0.5 + math.cos(angle + math.pi) * size.width * 0.28,
      size.height * 0.65 + math.sin(angle + math.pi) * size.height * 0.2,
    );
    final c3 = Offset(
      size.width * 0.5 + math.cos(angle + math.pi / 2) * size.width * 0.22,
      size.height * 0.5 + math.sin(angle + math.pi / 2) * size.height * 0.3,
    );

    canvas.drawCircle(
      c1,
      size.shortestSide * 0.35,
      Paint()
        ..color = accent.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      c2,
      size.shortestSide * 0.3,
      Paint()
        ..color = const Color(0xFF64FFDA).withOpacity(0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      c3,
      size.shortestSide * 0.24,
      Paint()
        ..color = const Color(0xFFFFC857).withOpacity(0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientBlobPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// One procedurally-placed bubble drifting up the background.
class _BubbleSpec {
  final double dx; // horizontal position, 0..1 fraction of width
  final double size; // diameter in logical pixels
  final double speed; // cycles per _ambient loop (higher = faster rise)
  final double phase; // 0..1 starting offset so bubbles don't sync up
  final double opacity;
  final Color color;

  const _BubbleSpec({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.color,
  });
}

List<_BubbleSpec> _generateBubbleField() {
  final random = math.Random(7); // fixed seed: same layout every launch
  const palette = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
    Color(0xFF64FFDA),
  ];
  return List.generate(16, (i) {
    return _BubbleSpec(
      dx: random.nextDouble(),
      size: 6 + random.nextDouble() * 16,
      speed: 0.35 + random.nextDouble() * 0.85,
      phase: random.nextDouble(),
      opacity: 0.08 + random.nextDouble() * 0.14,
      color: palette[random.nextInt(palette.length)],
    );
  });
}

/// Paints softly-glowing bubbles drifting upward and looping seamlessly,
/// echoing the game's own bubbles for a bit of atmosphere behind the card.
class _FloatingBubblesPainter extends CustomPainter {
  final double t; // 0..1 looping
  final List<_BubbleSpec> bubbles;
  _FloatingBubblesPainter({required this.t, required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final progress = (t * b.speed + b.phase) % 1.0;
      final dy = size.height * (1 - progress) + size.height * 0.1;
      final sway = math.sin(progress * 2 * math.pi + b.phase * 10) * 10;
      final center = Offset(b.dx * size.width + sway, dy);
      // Fade in/out near the top and bottom of the loop so bubbles don't
      // visibly pop in or out mid-screen.
      final edgeFade = (math.sin(progress * math.pi)).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        b.size,
        Paint()
          ..color = b.color.withOpacity(b.opacity * edgeFade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        center.translate(-b.size * 0.28, -b.size * 0.28),
        b.size * 0.28,
        Paint()..color = Colors.white.withOpacity(0.18 * edgeFade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingBubblesPainter oldDelegate) =>
      oldDelegate.t != t;
}

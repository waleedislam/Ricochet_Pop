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
  late final AnimationController _confetti;
  final List<_BubbleSpec> _bubbles = _generateBubbleField();
  late final List<_ConfettiPiece> _confettiPieces;
  late final String _encouragement;

  static const _encouragements = [
    "So close! You've got this 💪",
    "Almost there — try again!",
    "Great effort! One more shot?",
    "Don't give up, champ!",
    "So close to clearing it!",
  ];

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
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // A little celebratory burst — on the welcoming start screen, and
    // (bigger reason to celebrate) whenever a level is completed. Plays
    // once per time the overlay appears, never loops, so it stays fun
    // instead of annoying.
    final isWin = widget.mode == OverlayMode.levelComplete;
    _confettiPieces = _generateConfetti(big: isWin);
    if (widget.mode == OverlayMode.start || isWin) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _confetti.forward();
      });
    }
    _encouragement =
        _encouragements[math.Random().nextInt(_encouragements.length)];
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    _confetti.dispose();
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
                    _accent.withValues(alpha: 0.16),
                    const Color(0xFF0B1220).withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.82),
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
        // One-time celebratory confetti burst — welcome on start, victory
        // celebration on level complete.
        if (widget.mode == OverlayMode.start || widget.mode == OverlayMode.levelComplete)
          AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(
              painter: _ConfettiPainter(t: _confetti.value, pieces: _confettiPieces),
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
        _PulsingIcon(
          icon: _icon,
          color: _accent,
          imageAsset:
              widget.mode == OverlayMode.start ? 'assets/icon/app_icon.png' : null,
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _ambient,
          builder: (context, child) {
            final wiggle = widget.mode == OverlayMode.start
                ? math.sin(_ambient.value * 2 * math.pi * 1.5) * 0.035
                : 0.0;
            return Transform.rotate(angle: wiggle, child: child);
          },
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, _accent.withValues(alpha: 0.85)],
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
        ),
        const SizedBox(height: 16),
        ..._buildStaggeredBody(),
        const SizedBox(height: 26),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
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
              Text(
                _encouragement,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7CE38B),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
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

  Widget _instructionRow(IconData icon, String text, [Color? color]) {
    final c = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.12)],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 15, color: c),
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
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
class _HowToPlayCard extends StatefulWidget {
  final Color accent;
  final Widget Function(IconData icon, String text, [Color? color]) instructionRow;

  const _HowToPlayCard({required this.accent, required this.instructionRow});

  @override
  State<_HowToPlayCard> createState() => _HowToPlayCardState();
}

class _HowToPlayCardState extends State<_HowToPlayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;

  static const _rowColors = [
    Color(0xFF64FFDA),
    Color(0xFFFFC857),
    Color(0xFFFF7AC6),
    Color(0xFFFF6B4A),
    Color(0xFF7CE38B),
  ];

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  /// Wraps [child] so it fades/slides/pops in on its own little delay,
  /// [index] steps into the stagger — later rows appear a beat after
  /// earlier ones instead of everything snapping in at once.
  Widget _staggered(int index, Widget child) {
    final start = 0.08 * index;
    final anim = CurvedAnimation(
      parent: _stagger,
      curve: Interval(start.clamp(0.0, 0.9), (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final v = anim.value.clamp(0.0, 1.3);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - v) * 20, 0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      widget.instructionRow(Icons.touch_app_rounded, 'Drag to aim the laser sight', _rowColors[0]),
      widget.instructionRow(Icons.blur_circular_rounded, 'Match 3+ same colors to pop them', _rowColors[1]),
      widget.instructionRow(Icons.swap_horiz_rounded, 'Tap your ball to swap its color, unlimited', _rowColors[2]),
      widget.instructionRow(Icons.warning_amber_rounded, "Don't let bubbles reach the red line", _rowColors[3]),
      widget.instructionRow(Icons.flag_rounded, 'Clear the board before shots run out', _rowColors[4]),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      child: _Card(
        mode: OverlayMode.start,
        accent: widget.accent,
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
            for (int i = 0; i < rows.length; i++) ...[
              _staggered(i, rows[i]),
              if (i != rows.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 18),
            _staggered(rows.length, const _PowerUpLegend()),
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
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFC857).withValues(alpha: 0.06),
            const Color(0xFFFF7AC6).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
            color: accent.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
                  const Color(0xFF223449).withValues(alpha: 0.92),
                  const Color(0xFF0F1721).withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.4),
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

/// A little character animation: the icon actually bounces like a ball,
/// complete with squash-on-landing and a ground shadow that reacts —
/// fitting for a game about bouncing, and a lot more fun to watch than a
/// static glow.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? imageAsset;
  const _PulsingIcon({required this.icon, required this.color, this.imageAsset});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat();
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
        // Parabolic hop: 0 at ground (t=0 and t=1), 1 at the apex (t=0.5).
        // Repeating this exact shape with a plain (non-reversing) loop is
        // seamless — it already returns to the ground smoothly each cycle.
        final t = _c.value;
        final height = 4 * t * (1 - t); // 0..1..0
        const maxBounce = 16.0;
        final squash = 1 - height; // 1 at ground (squashed), 0 at apex

        const ballSize = 64.0;
        final scaleX = 1.0 + squash * 0.16;
        final scaleY = 1.0 - squash * 0.16;

        return SizedBox(
          width: 90,
          height: 90 + maxBounce,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Ground shadow: wider/darker when the ball is down, smaller
              // and softer when it's up at the apex — sells the bounce.
              Positioned(
                bottom: 6,
                child: Opacity(
                  opacity: 0.35 - height * 0.2,
                  child: Container(
                    width: 46 - height * 14,
                    height: 10 - height * 4,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // The bouncing ball itself.
              Positioned(
                bottom: 10 + height * maxBounce,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(scaleX, scaleY, 1.0, 1.0),
                  child: Container(
                    width: ballSize,
                    height: ballSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withValues(alpha: 0.4),
                          widget.color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: widget.imageAsset != null
                        ? Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.color.withValues(alpha: 0.6),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                widget.imageAsset!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Icon(widget.icon, size: 46, color: widget.color),
                  ),
                ),
              ),
            ],
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
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Score: $value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  State<_StatPill> createState() => _StatPillState();
}

class _StatPillState extends State<_StatPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
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
        return Transform.scale(scale: 1.0 + t * 0.04, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 15, color: widget.color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                Shadow(color: Colors.amber.withValues(alpha: 0.6 * t), blurRadius: 12),
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
                color: widget.color.withValues(alpha: _pressed ? 0.15 : 0.4),
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
            color: Colors.white.withValues(alpha: _pressed ? 0.05 : 0.02),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
        ..color = accent.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      c2,
      size.shortestSide * 0.3,
      Paint()
        ..color = const Color(0xFF64FFDA).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      c3,
      size.shortestSide * 0.24,
      Paint()
        ..color = const Color(0xFFFFC857).withValues(alpha: 0.05)
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
    Color(0xFFFF7AC6),
    Color(0xFFFF8C42),
  ];
  return List.generate(22, (i) {
    return _BubbleSpec(
      dx: random.nextDouble(),
      size: 8 + random.nextDouble() * 22,
      speed: 0.3 + random.nextDouble() * 0.9,
      phase: random.nextDouble(),
      opacity: 0.16 + random.nextDouble() * 0.22,
      color: palette[random.nextInt(palette.length)],
    );
  });
}

/// Paints cheerful, clearly-colored bubbles drifting upward and looping
/// seamlessly — bright enough to feel fun and alive rather than just
/// background ambiance, echoing the game's own bubbles.
class _FloatingBubblesPainter extends CustomPainter {
  final double t; // 0..1 looping
  final List<_BubbleSpec> bubbles;
  _FloatingBubblesPainter({required this.t, required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final progress = (t * b.speed + b.phase) % 1.0;
      final dy = size.height * (1 - progress) + size.height * 0.1;
      final sway = math.sin(progress * 2 * math.pi + b.phase * 10) * 12;
      final center = Offset(b.dx * size.width + sway, dy);
      // Fade in/out near the top and bottom of the loop so bubbles don't
      // visibly pop in or out mid-screen.
      final edgeFade = (math.sin(progress * math.pi)).clamp(0.0, 1.0);

      // Soft outer glow.
      canvas.drawCircle(
        center,
        b.size * 1.15,
        Paint()
          ..color = b.color.withValues(alpha: b.opacity * 0.5 * edgeFade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Filled bubble body.
      canvas.drawCircle(
        center,
        b.size,
        Paint()..color = b.color.withValues(alpha: b.opacity * edgeFade),
      );
      // Crisp rim so it reads as a bubble rather than a blur.
      canvas.drawCircle(
        center,
        b.size,
        Paint()
          ..color = b.color.withValues(alpha: (b.opacity + 0.25) * edgeFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Little highlight, like light catching the top of a bubble.
      canvas.drawCircle(
        center.translate(-b.size * 0.3, -b.size * 0.3),
        b.size * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * edgeFade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingBubblesPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// One piece of confetti in the one-time "welcome" burst.
class _ConfettiPiece {
  final double angle; // launch direction, radians
  final double speed; // how far it travels outward, in logical pixels
  final double size;
  final double spin; // full rotations over the burst's lifetime
  final Color color;
  final bool isStar;

  const _ConfettiPiece({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
    required this.isStar,
  });
}

List<_ConfettiPiece> _generateConfetti({bool big = false}) {
  final random = math.Random(3);
  const palette = [
    Color(0xFFFFC857),
    Color(0xFF64FFDA),
    Color(0xFFFF7AC6),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
  ];
  final count = big ? 32 : 18;
  final speedBoost = big ? 1.4 : 1.0;
  return List.generate(count, (i) {
    final angle = (i / count) * 2 * math.pi + random.nextDouble() * 0.3;
    return _ConfettiPiece(
      angle: angle,
      speed: (70 + random.nextDouble() * 90) * speedBoost,
      size: 5 + random.nextDouble() * (big ? 6 : 5),
      spin: 1.5 + random.nextDouble() * 2.5,
      color: palette[random.nextInt(palette.length)],
      isStar: random.nextBool(),
    );
  });
}

/// Paints an outward-radiating confetti burst from the icon area, fading
/// and slowing (gravity-ish) as it goes. Plays once — the controller
/// driving [t] does not repeat.
class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1, plays once
  final List<_ConfettiPiece> pieces;
  _ConfettiPainter({required this.t, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    // Roughly where the pulsing icon sits above the card.
    final origin = Offset(size.width / 2, size.height * 0.32);
    // Ease-out travel + a touch of "gravity" pulling pieces down over time.
    final travel = Curves.easeOut.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);

    for (final p in pieces) {
      final dx = math.cos(p.angle) * p.speed * travel;
      final dy = math.sin(p.angle) * p.speed * travel + 40 * t * t;
      final center = origin + Offset(dx, dy);
      final rotation = p.spin * 2 * math.pi * t;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      if (p.isStar) {
        _drawStar(canvas, paint, p.size);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    const points = 5;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final a = (i * math.pi) / points;
      final pt = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

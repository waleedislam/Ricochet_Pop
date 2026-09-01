import 'package:flutter/material.dart';

/// The kinds of special shooter balls the player can receive, alongside the
/// plain colored ones. A ball carries at most one of these at a time.
///
///  - [colorBomb]: on landing, clears every bubble of one color from the
///    whole board (the color it strikes, or the majority color around it).
///  - [lineBlast]: on landing, wipes out every bubble in the row it lands on.
///  - [rainbow]: acts as a wildcard — it takes on whichever neighboring
///    color would form the biggest match, so it "matches any color".
enum PowerUpType { none, colorBomb, lineBlast, rainbow }

/// Static display info (label, icon, accent color) for a [PowerUpType],
/// used by both the HUD and the in-game painter so they stay in sync.
class PowerUpInfo {
  final String label;
  final String description;
  final IconData icon;
  final Color accent;

  const PowerUpInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
  });
}

extension PowerUpTypeX on PowerUpType {
  bool get isPowerUp => this != PowerUpType.none;

  PowerUpInfo get info {
    switch (this) {
      case PowerUpType.colorBomb:
        return const PowerUpInfo(
          label: 'Color Bomb',
          description: 'Clears every bubble of one color on the board',
          icon: Icons.whatshot_rounded,
          accent: Color(0xFFFF6D00),
        );
      case PowerUpType.lineBlast:
        return const PowerUpInfo(
          label: 'Line Blast',
          description: 'Wipes out the entire row it lands on',
          icon: Icons.bolt_rounded,
          accent: Color(0xFF00E5FF),
        );
      case PowerUpType.rainbow:
        return const PowerUpInfo(
          label: 'Rainbow Ball',
          description: 'Matches with any color it touches',
          icon: Icons.auto_awesome_rounded,
          accent: Color(0xFFFFD54F),
        );
      case PowerUpType.none:
        return const PowerUpInfo(
          label: '',
          description: '',
          icon: Icons.circle,
          accent: Colors.white,
        );
    }
  }
}

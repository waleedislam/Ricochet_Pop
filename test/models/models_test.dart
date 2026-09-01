import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ricochet_pop/models/ball.dart';
import 'package:ricochet_pop/models/falling_bubble.dart';
import 'package:ricochet_pop/models/particle.dart';
import 'package:ricochet_pop/models/power_up.dart';

void main() {
  group('Ball', () {
    test('applies sensible defaults when only position is given', () {
      final ball = Ball(position: const Offset(10, 20));
      expect(ball.position, const Offset(10, 20));
      expect(ball.velocity, Offset.zero);
      expect(ball.radius, 20);
      expect(ball.powerUp, PowerUpType.none);
    });

    test('accepts an explicit power-up type', () {
      final ball = Ball(
        position: Offset.zero,
        powerUp: PowerUpType.rainbow,
      );
      expect(ball.powerUp, PowerUpType.rainbow);
      expect(ball.powerUp.isPowerUp, isTrue);
    });
  });

  group('FallingBubble', () {
    test('opacityFor is fully opaque while life exceeds the fade window',
        () {
      final bubble = FallingBubble(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.red,
        radius: 20,
        life: 2.0,
      );
      expect(bubble.opacityFor(fadeWindow: 0.35), 1.0);
    });

    test('opacityFor fades linearly as life runs out', () {
      final bubble = FallingBubble(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.red,
        radius: 20,
        life: 0.175, // half of the default 0.35s fade window
      );
      expect(bubble.opacityFor(fadeWindow: 0.35), closeTo(0.5, 0.001));
    });

    test('opacityFor never goes negative once life is exhausted', () {
      final bubble = FallingBubble(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.red,
        radius: 20,
        life: -1,
      );
      expect(bubble.opacityFor(fadeWindow: 0.35), 0.0);
    });

    test('maxLife is captured at creation and does not track life changes',
        () {
      final bubble = FallingBubble(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.red,
        radius: 20,
        life: 2.4,
      );
      bubble.life = 0.1;
      expect(bubble.maxLife, 2.4);
    });
  });

  group('Particle', () {
    test('progress is 0 right after spawning and 1 when life hits zero', () {
      final particle = Particle(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.orange,
        life: 1.0,
        size: 4,
      );
      expect(particle.progress, closeTo(0.0, 0.001));

      particle.life = 0.0;
      expect(particle.progress, closeTo(1.0, 0.001));
    });

    test('progress is proportional partway through its life', () {
      final particle = Particle(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.orange,
        life: 1.0,
        size: 4,
      );
      particle.life = 0.75; // 25% elapsed
      expect(particle.progress, closeTo(0.25, 0.001));
    });
  });

  group('ScorePopup', () {
    test('defaults to a 0.9s life and starts at progress 0', () {
      final popup = ScorePopup(position: Offset.zero, amount: 30);
      expect(popup.maxLife, 0.9);
      expect(popup.progress, closeTo(0.0, 0.001));
    });
  });

  group('PowerUpType', () {
    test('none is not a power-up; every other type is', () {
      expect(PowerUpType.none.isPowerUp, isFalse);
      expect(PowerUpType.colorBomb.isPowerUp, isTrue);
      expect(PowerUpType.lineBlast.isPowerUp, isTrue);
      expect(PowerUpType.rainbow.isPowerUp, isTrue);
    });

    test('every power-up type exposes non-empty display info', () {
      for (final type in [
        PowerUpType.colorBomb,
        PowerUpType.lineBlast,
        PowerUpType.rainbow,
      ]) {
        final info = type.info;
        expect(info.label, isNotEmpty, reason: '$type should have a label');
        expect(info.description, isNotEmpty,
            reason: '$type should have a description');
      }
    });

    test('PowerUpType.none has empty label/description by design', () {
      expect(PowerUpType.none.info.label, isEmpty);
      expect(PowerUpType.none.info.description, isEmpty);
    });
  });
}

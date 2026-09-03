// End-to-end widget tests for the main user-facing flows: booting to the
// start menu, opening How To Play, starting a game, pausing, and
// navigating to the level map. These catch exactly the kind of thing
// that slips through when there's no test suite — e.g. a screen showing
// stale branding text, or a button that silently stops doing anything
// after a refactor.
//
// IMPORTANT: this app intentionally has several perpetually-repeating
// animations (the bouncing app icon, the title wiggle, breathing badges,
// drifting ambient bubbles, the shooter ball's idle bob, etc.) — that's
// the whole point of the playful redesign. `pumpAndSettle()` waits until
// NO more frames are scheduled, which never happens with a `..repeat()`
// controller, so it always times out here. Every wait below uses a fixed
// `pump(duration)` long enough for the relevant one-shot transition
// (entrance fade, dialog transition, page route) to finish, instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ricochet_pop/main.dart';

/// Pumps a couple of frames to let one-shot transitions/entrance
/// animations finish, without ever waiting for perpetual animations to
/// "settle" (they never will).
Future<void> settle(WidgetTester tester,
    [Duration duration = const Duration(milliseconds: 700)]) async {
  await tester.pump();
  await tester.pump(duration);
}

void main() {
  setUp(() {
    // A clean, empty persisted-progress store for every test, so high
    // score / best level don't leak between tests.
    SharedPreferences.setMockInitialValues({});
  });

  group('App boot', () {
    testWidgets('boots to the start menu with correct branding and buttons',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await settle(tester);

      expect(find.text('Ricochet Pop'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Levels'), findsOneWidget);
    });
  });

  group('How To Play', () {
    testWidgets('info icon opens the How To Play card with the rules',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await settle(tester, const Duration(milliseconds: 400));

      expect(find.text('How To Play'), findsOneWidget);
      expect(find.textContaining('Drag to aim'), findsOneWidget);
      expect(
        find.textContaining('Color Bomb', findRichText: true),
        findsOneWidget,
      );

      // Closing it returns to the start menu underneath.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, const Duration(milliseconds: 400));

      expect(find.text('How To Play'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
    });
  });

  group('Starting and pausing a level', () {
    testWidgets('Play starts the game and shows the in-game HUD',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await settle(tester);

      await tester.tap(find.text('Play'));
      await settle(tester, const Duration(milliseconds: 400));

      // Start-menu title is gone; the HUD shows level + score instead.
      expect(find.text('Ricochet Pop'), findsNothing);
      expect(find.textContaining('Level 1'), findsOneWidget);
      expect(find.textContaining('Score:'), findsOneWidget);
    });

    testWidgets('pause button shows the Paused overlay with a Resume button',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await settle(tester);

      await tester.tap(find.text('Play'));
      await settle(tester, const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await settle(tester);

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await settle(tester);

      expect(find.text('Paused'), findsNothing);
    });
  });

  group('Level select navigation', () {
    testWidgets('Levels button opens the level map and back returns to menu',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await settle(tester);

      await tester.tap(find.text('Levels'));
      await settle(tester, const Duration(milliseconds: 500));

      expect(find.text('Select Level'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester, const Duration(milliseconds: 500));

      expect(find.text('Select Level'), findsNothing);
      expect(find.text('Ricochet Pop'), findsOneWidget);
    });
  });
}

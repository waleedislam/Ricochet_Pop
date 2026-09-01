// End-to-end widget tests for the main user-facing flows: booting to the
// start menu, opening How To Play, starting a game, pausing, and
// navigating to the level map. These catch exactly the kind of thing
// that slips through when there's no test suite — e.g. a screen showing
// stale branding text, or a button that silently stops doing anything
// after a refactor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ricochet_pop/main.dart';

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
      await tester.pumpAndSettle();

      expect(find.text('Ricochet Pop'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Levels'), findsOneWidget);
    });
  });

  group('How To Play', () {
    testWidgets('info icon opens the How To Play card with the rules',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('How To Play'), findsOneWidget);
      expect(find.textContaining('Drag to aim'), findsOneWidget);
      expect(find.text('Color Bomb'), findsOneWidget);

      // Closing it returns to the start menu underneath.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('How To Play'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
    });
  });

  group('Starting and pausing a level', () {
    testWidgets('Play starts the game and shows the in-game HUD',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Start-menu title is gone; the HUD shows level + score instead.
      expect(find.text('Ricochet Pop'), findsNothing);
      expect(find.textContaining('Level 1'), findsOneWidget);
      expect(find.textContaining('Score:'), findsOneWidget);
    });

    testWidgets('pause button shows the Paused overlay with a Resume button',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsNothing);
    });
  });

  group('Level select navigation', () {
    testWidgets('Levels button opens the level map and back returns to menu',
        (tester) async {
      await tester.pumpWidget(const BouncingBallApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Levels'));
      await tester.pumpAndSettle();

      expect(find.text('Select Level'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Select Level'), findsNothing);
      expect(find.text('Ricochet Pop'), findsOneWidget);
    });
  });
}

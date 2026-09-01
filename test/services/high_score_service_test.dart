import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ricochet_pop/services/high_score_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Start every test from a clean, empty "device" so tests can't leak
    // state into each other.
    SharedPreferences.setMockInitialValues({});
  });

  group('HighScoreService.getHighScore / saveIfHighScore', () {
    test('defaults to 0 when nothing has been saved yet', () async {
      expect(await HighScoreService.getHighScore(), 0);
    });

    test('saving a score above the current best returns true and persists',
        () async {
      final isNew = await HighScoreService.saveIfHighScore(150);
      expect(isNew, isTrue);
      expect(await HighScoreService.getHighScore(), 150);
    });

    test('saving a lower score returns false and keeps the old high score',
        () async {
      await HighScoreService.saveIfHighScore(500);
      final isNew = await HighScoreService.saveIfHighScore(200);
      expect(isNew, isFalse);
      expect(await HighScoreService.getHighScore(), 500);
    });

    test('saving an equal score does not count as a new high score',
        () async {
      await HighScoreService.saveIfHighScore(300);
      final isNew = await HighScoreService.saveIfHighScore(300);
      expect(isNew, isFalse);
      expect(await HighScoreService.getHighScore(), 300);
    });
  });

  group('HighScoreService.getBestLevel / saveIfBestLevel', () {
    test('defaults to level 1 when nothing has been saved yet', () async {
      expect(await HighScoreService.getBestLevel(), 1);
    });

    test('saving a further level updates the stored best level', () async {
      await HighScoreService.saveIfBestLevel(5);
      expect(await HighScoreService.getBestLevel(), 5);
    });

    test('saving an earlier level does not move the best level backwards',
        () async {
      await HighScoreService.saveIfBestLevel(8);
      await HighScoreService.saveIfBestLevel(3);
      expect(await HighScoreService.getBestLevel(), 8);
    });
  });
}

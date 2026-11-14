import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';

void main() {
  group('UserData Roundtrip (toJson → fromJson)', () {
    test('Fall A – volles UserData-Objekt bleibt nach Roundtrip identisch',
        () {
      final user = UserData(
        uName: 'testuser',
        mLang: 'de',
        progress: {'A1': 2, 'A2': 0, 'B1': 1, 'B2': 0, 'C1': 0, 'C2': 0},
        learnedLanguages: const [],
        language: {'some': 'dict'},
        vocab: {
          'test_word': VocabEntry(
            key: 'test_word',
            word: 'Test',
            translation: 'Test',
            examples: const [],
            examplesNative: const [],
          ),
        },
        dayStreak: const DayStreak(
          current: 5,
          longest: 10,
          lastDate: '2026-01-15',
        ),
        gameHighscore: 42,
        selectedCourses: const ['en_verben_a1'],
      );

      final roundtripped = UserData.fromJson(user.toJson());

      expect(roundtripped.uName, 'testuser');
      expect(roundtripped.mLang, 'de');
      expect(roundtripped.progress['A1'], 2);
      expect(roundtripped.progress['B1'], 1);
      expect(roundtripped.language['some'], 'dict');
      expect(roundtripped.vocab.length, 1);
      expect(roundtripped.vocab['test_word']!.word, 'Test');
      expect(roundtripped.vocab['test_word']!.translation, 'Test');
      expect(roundtripped.dayStreak, isNotNull);
      expect(roundtripped.dayStreak!.current, 5);
      expect(roundtripped.dayStreak!.longest, 10);
      expect(roundtripped.dayStreak!.lastDate, '2026-01-15');
      expect(roundtripped.gameHighscore, 42);
      expect(roundtripped.selectedCourses, ['en_verben_a1']);
    });

    test('Fall B – Default-Werte und null day_streak überleben Roundtrip', () {
      final user = UserData(
        uName: 'minimal',
        mLang: 'en',
        progress: {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
        learnedLanguages: const [],
        language: const {},
        vocab: const {},
        // dayStreak bleibt null (weggelassen)
        // gameHighscore bleibt Default 0
        // selectedCourses bleibt Default []
      );

      final roundtripped = UserData.fromJson(user.toJson());

      expect(roundtripped.uName, 'minimal');
      expect(roundtripped.mLang, 'en');
      expect(roundtripped.dayStreak, isNull);
      expect(roundtripped.gameHighscore, 0);
      expect(roundtripped.selectedCourses, isEmpty);
      expect(roundtripped.vocab, isEmpty);
      expect(roundtripped.language, isEmpty);
    });
  });
}
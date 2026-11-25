import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';

void main() {
  group('Level-System (Ticket #51)', () {
    test('maxLevel definiert die Gelernt-Grenze', () {
      expect(VocabManager.maxLevel, 8);
    });

    test('intervalDaysFor: linear 1..7, null bei neu (0), gelernt (8) und jenseits (9)',
        () {
      expect(VocabManager.intervalDaysFor(0), isNull);
      for (var l = 1; l < VocabManager.maxLevel; l++) {
        expect(VocabManager.intervalDaysFor(l), l);
      }
      expect(VocabManager.intervalDaysFor(8), isNull);
      expect(VocabManager.intervalDaysFor(9), isNull);
    });

    test('Prädikate: neu (0), in Arbeit (1..7), gelernt (>=8) inkl. Level 9',
        () {
      expect(VocabManager.isNew(0), isTrue);
      expect(VocabManager.isNew(9), isFalse);
      expect(VocabManager.isInProgress(1), isTrue);
      expect(VocabManager.isInProgress(7), isTrue);
      expect(VocabManager.isInProgress(8), isFalse);
      expect(VocabManager.isMastered(7), isFalse);
      expect(VocabManager.isMastered(8), isTrue);
      expect(VocabManager.isMastered(9), isTrue);
    });
  });

  test('fmt schreibt Datumsangaben als YYYY-MM-DD', () {
    expect(fmt(DateTime(2026, 11, 11, 22, 51)), '2026-11-11');
    expect(fmt(DateTime(2026, 1, 5)), '2026-01-05');
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';

void main() {
  group('repeatIntervalDays', () {
    test('verwendet den linearen 1–7 Tage Rhythmus, gelernt bei Level 8', () {
      expect(VocabManager.repeatIntervalDays, {
        1: 1,
        2: 2,
        3: 3,
        4: 4,
        5: 5,
        6: 6,
        7: 7,
        8: null,
      });
    });
  });

  test('fmt schreibt Datumsangaben als YYYY-MM-DD', () {
    expect(fmt(DateTime(2026, 11, 11, 22, 51)), '2026-11-11');
    expect(fmt(DateTime(2026, 1, 5)), '2026-01-05');
  });
}

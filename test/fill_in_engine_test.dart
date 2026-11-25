import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/fill_in_engine.dart';

/// Konjugations-Eintrag (gesehen, level 1 – spielbar).
VocabEntry _seen(String key, String word, String translation,
        {List<String> examples = const [],
        List<String> examplesNative = const []}) =>
    VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: examples,
      examplesNative: examplesNative,
      level: 1,
      status: 'seen',
    );

void main() {
  group('buildItem', () {
    // Realistische App-Semantik: word = Zielsprach-Konjugation, translation =
    // Muttersprach-Uebersetzung, examples = Zielsprache, examplesNative =
    // Muttersprache.
    final entry = _seen(
      'to_go_present_0',
      'ich gehe',
      'I go',
      examples: ['Ich gehe zur Schule.'],
      examplesNative: ['I go to school.'],
    );

    test('normaler Fall: Loesung = Verbform, Satz mit Luecke, Native-Zeile',
        () {
      final item = buildItem(entry);
      expect(item.solution, 'gehe');
      expect(item.sentence, 'Ich ____ zur Schule.');
      expect(item.sentenceNative, 'I go to school.');
      // Laenge der Unterstriche = Laenge der Loesung.
      expect(item.sentence.split(' ')[1], hasLength(4));
    });

    test('case-insensitive: Gross-/Kleinschreibung im Satz egal', () {
      final upper = _seen(
        'to_go_present_0',
        'ich gehe',
        'I go',
        examples: ['ICH GEHE ZUR SCHULE.'],
        examplesNative: ['I go to school.'],
      );
      final item = buildItem(upper);
      expect(item.sentence, 'ICH ____ ZUR SCHULE.');
      expect(item.solution, 'gehe');
    });

    test('Personen-Zeile des Beispiellistens gewinnt', () {
      final perPerson = _seen(
        'to_go_present_1',
        'du gehst',
        'you go',
        examples: ['Ich gehe zur Schule.', 'Du gehst nach Hause.'],
      );
      final item = buildItem(perPerson);
      expect(item.sentence, 'Du _____ nach Hause.');
      expect(item.solution, 'gehst');
    });

    test('Rueckfallebene ohne examples: nur "translation: ___"', () {
      final noExamples = _seen('to_go_present_0', 'ich gehe', 'I go');
      final item = buildItem(noExamples);
      expect(item.sentence, 'translation: ____');
      expect(item.sentenceNative, '');
      expect(item.solution, 'gehe');
    });

    test('Rueckfallebene, wenn die Verbform im Satz nicht vorkommt', () {
      final mismatch = _seen(
        'to_go_present_0',
        'ich arbeite',
        'I work',
        examples: ['Ich gehe zur Schule.'],
      );
      final item = buildItem(mismatch);
      expect(item.sentence, 'translation: ${'_' * 7}');
    });
  });

  group('checkAnswer', () {
    test('richtig: trim + Gross-/Kleinschreibung tolerant', () {
      final item = FillInItem(
          sentence: 'Ich ____ zur Schule.',
          sentenceNative: '',
          solution: 'gehe');
      expect(checkAnswer(item, '  GEHE '), isTrue);
      expect(item.score, isTrue);
      expect(item.tries, 1);
    });

    test('falsch: false, tries steigt, score bleibt false', () {
      final item =
          FillInItem(sentence: 'x', sentenceNative: '', solution: 'gehe');
      expect(checkAnswer(item, 'xxx'), isFalse);
      expect(item.score, isFalse);
      expect(item.tries, 1);
      expect(checkAnswer(item, 'abcde'), isFalse);
      expect(item.tries, 2);
    });

    test('Tipp-Leak erst nach 2 Fehlversuchen (einmalig)', () {
      final item =
          FillInItem(sentence: 'x', sentenceNative: '', solution: 'gehe');
      checkAnswer(item, 'a');
      expect(item.hintShown, isFalse);
      checkAnswer(item, 'b');
      expect(item.hintShown, isTrue);
      checkAnswer(item, 'c');
      expect(item.hintShown, isTrue);
      expect(item.tries, 3);
    });
  });

  group('isRoundOver / score', () {
    test('isRoundOver erst nach dem letzten Item', () {
      final round = FillInRound(
        items: [
          FillInItem(sentence: 'a', sentenceNative: '', solution: 'a'),
          FillInItem(sentence: 'b', sentenceNative: '', solution: 'b'),
          FillInItem(sentence: 'c', sentenceNative: '', solution: 'c'),
        ],
      );
      expect(isRoundOver(round), isFalse);
      round.index = 2;
      expect(isRoundOver(round), isFalse);
      round.index = 3;
      expect(isRoundOver(round), isTrue);
    });

    test('score-Zaehlung: richtig geloeste Items erhoehen round.score', () {
      final round = createRound([
        _seen('to_go_present_0', 'ich gehe', 'I go'),
        _seen('to_come_present_0', 'ich komme', 'I come'),
        _seen('to_read_present_0', 'ich lese', 'I read'),
      ], 'medium');

      // Reihenfolge ist zufaellig – Items ueber ihre Loesung finden.
      FillInItem itemFor(String solution) =>
          round.items.firstWhere((i) => i.solution == solution);

      // Erster Satz richtig, zweiter falsch, dritter richtig.
      expect(checkAnswer(itemFor('gehe'), 'gehe'), isTrue);
      round.score++;
      expect(checkAnswer(itemFor('komme'), 'falsch'), isFalse);
      expect(checkAnswer(itemFor('lese'), 'LESE'), isTrue);
      round.score++;
      round.index = round.items.length;
      expect(round.score, 2);
      expect(isRoundOver(round), isTrue);
    });
  });

  group('createRound', () {
    test('sentenceCountFor: easy 25, medium 50, hard 100', () {
      expect(sentenceCountFor('easy'), 25);
      expect(sentenceCountFor('medium'), 50);
      expect(sentenceCountFor('hard'), 100);
      expect(sentenceCountFor('unknown'), 50); // Default medium
    });

    test("status 'new' und level 0 landen niemals in der Runde", () {
      final round = createRound([
        _seen('to_go_present_0', 'ich gehe', 'I go'),
        _seen('to_come_present_0', 'ich komme', 'I come'),
        _seen('to_read_present_0', 'ich lese', 'I read'),
        // NIE spielbar: level 0 + status 'new' (VocabEntry-Defaults).
        VocabEntry(
          key: 'to_live_present_0',
          word: 'ich wohne',
          translation: 'I live',
          examples: const [],
          examplesNative: const [],
        ),
      ], 'medium');
      expect(round.items.where((i) => i.solution == 'wohne'), isEmpty);
      expect(round.items.length, 3);
    });

    test('gelesene Woerter mit level 0 sind spielbar (Ticket #61)', () {
      final round = createRound([
        VocabEntry(
          key: 'to_end_present_0',
          word: 'ich ende',
          translation: 'I end',
          examples: const [],
          examplesNative: const [],
          status: 'seen',
        ),
      ], 'medium');
      expect(round.items.where((i) => i.solution == 'ende'), isNotEmpty);
    });

    test('Deckelung: Pool kleiner als Satzahl -> weniger Saetze, ohne Wiederholung',
        () {
      final pool = [
        for (var i = 0; i < 5; i++)
          _seen('to_make_present_$i', 'ich mache $i', 'I make $i'),
      ];
      final round = createRound(pool, 'easy');
      expect(round.items.length, 5); // Ziel 25, gedeckelt auf 5
      final solutions = round.items.map((i) => i.solution).toSet();
      expect(solutions.length, 5); // keine Wiederholung
    });
  });
}

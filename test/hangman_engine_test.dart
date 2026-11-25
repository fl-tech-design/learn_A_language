import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/hangman_engine.dart';

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

/// Baut wir/sie-Praesens-Formen fuer mehrere Verben (liefern den Infinitiv).
List<VocabEntry> _verbs(List<(String, String, String)> verbs) {
  final result = <VocabEntry>[];
  for (final (verbKey, infinitive, translation) in verbs) {
    result.add(_seen('${verbKey}_present_3', 'wir $infinitive', translation));
    result.add(_seen('${verbKey}_present_5', 'sie $infinitive', translation));
  }
  return result;
}

void main() {
  group('buildHint', () {
    // Realistische App-Semantik: word = Zielsprach-Konjugation (enzlisch),
    // translation = Muttersprach-Uebersetzung (deutsch), examples = Zielsprach,
    // examplesNative = Muttersprache.
    final entry = _seen(
      'to_work_present_3',
      'we work',
      'wir arbeiten',
      examples: ['We work a lot.'],
      examplesNative: ['Wir arbeiten viel.'],
    );

    test('easy: zeigt die Uebersetzung', () {
      expect(buildHint(entry, 'easy'), 'wir arbeiten');
    });

    test('medium: nativer Beispielsatz mit Luecke am Zielwort', () {
      final hint = buildHint(entry, 'medium');
      // Gap-Laenge entspricht dem Infinitiv "WORK" (4 Buchstaben).
      expect(hint, 'Wir ____ viel.');
      expect(hint.contains('arbeiten'), isFalse);
    });

    test('hard: Zielsprachen-Beispielsatz mit Luecke am Zielwort', () {
      final hint = buildHint(entry, 'hard');
      expect(hint, 'We ____ a lot.');
      expect(hint.contains('work'), isFalse);
    });

    test('Rueckfall auf Uebersetzung, wenn kein Beispielsatz vorhanden', () {
      final noExamples = _seen('to_work_present_3', 'we work', 'we work');
      expect(buildHint(noExamples, 'medium'), 'we work');
      expect(buildHint(noExamples, 'hard'), 'we work');
      expect(buildHint(noExamples, 'easy'), 'we work');
    });
  });

  group('guessLetter', () {
    test('richtiger Buchstabe deckt alle Vorkommen auf', () {
      final word = HangmanWord(target: 'BANANE', hint: 'x');
      expect(guessLetter(word, 'a'), isTrue);
      expect(word.guessed, contains('A'));
      expect(revealedWord(word), '_A_A__');
    });

    test('falscher Buchstabe wird trotzdem markiert (nicht im Zielwort)', () {
      final word = HangmanWord(target: 'BANANE', hint: 'x');
      expect(guessLetter(word, 'Z'), isFalse);
      expect(word.guessed, contains('Z'));
      expect(revealedWord(word), '______');
    });

    test('idempotent: bereits geratene liefern false ohne Veraenderung', () {
      final word = HangmanWord(target: 'BANANE', hint: 'x');
      expect(guessLetter(word, 'A'), isTrue);
      final before = List<String>.from(word.guessed);
      expect(guessLetter(word, 'a'), isFalse);
      expect(word.guessed, before);
    });
  });

  group('isWordSolved / revealedWord / isRoundOver', () {
    test('isWordSolved erst nach allen Buchstaben', () {
      final word = HangmanWord(target: 'BANANE', hint: 'x');
      expect(isWordSolved(word), isFalse);
      for (final l in ['B', 'A', 'N']) {
        guessLetter(word, l);
      }
      expect(isWordSolved(word), isFalse);
      guessLetter(word, 'E');
      expect(isWordSolved(word), isTrue);
      expect(revealedWord(word), 'BANANE');
    });

    test('isRoundOver: verloren nach aufgebrauchten Leben', () {
      final round = HangmanRound(
        entries: [HangmanWord(target: 'BAUM', hint: 'x')],
        wrongGuesses: <String>[],
        lives: 2,
        solvedCount: 0,
      );
      expect(isRoundOver(round), isFalse);
      round.wrongGuesses.addAll(['X', 'Y']);
      expect(isRoundOver(round), isTrue);
      expect(round.remainingLives, 0);
    });

    test('isRoundOver: gewonnen nach allen Woertern geloest', () {
      final round = HangmanRound(
        entries: [HangmanWord(target: 'BAUM', hint: 'x')],
        wrongGuesses: <String>[],
        lives: 6,
        solvedCount: 1,
      );
      expect(isRoundOver(round), isTrue);
    });
  });

  group('createRound', () {
    test("status 'new' und level 0 landen niemals in der Runde", () {
      final round = createRound([
        // Spielbar
        _seen('to_go_present_3', 'wir gehen', 'we go'),
        _seen('to_come_present_3', 'wir kommen', 'we come'),
        _seen('to_read_present_3', 'wir lesen', 'we read'),
        _seen('to_work_present_3', 'wir arbeiten', 'we work'),
        _seen('to_find_present_3', 'wir finden', 'we find'),
        _seen('to_learn_present_3', 'wir lernen', 'we learn'),
        _seen('to_write_present_3', 'wir schreiben', 'we write'),
        // NIE spielbar: level 0 + status 'new' (VocabEntry-Defaults).
        VocabEntry(
          key: 'to_live_present_3',
          word: 'wir laufen',
          translation: 'we run',
          examples: const [],
          examplesNative: const [],
        ),
      ], 'medium');
      expect(round.entries.where((w) => w.target == 'LAUFEN'), isEmpty);
    });

    test('gelesene Woerter mit level 0 sind spielbar (Ticket #61)', () {
      final round = createRound([
        VocabEntry(
          key: 'to_end_present_3',
          word: 'wir enden',
          translation: 'we end',
          examples: const [],
          examplesNative: const [],
          status: 'seen',
        ),
      ], 'medium');
      expect(round.entries.where((w) => w.target == 'ENDEN'), isNotEmpty);
    });

    test('gleicher Infinitiv nur einmal (Deduplizierung)', () {
      final round = createRound([
        _seen('to_go_present_0', 'ich gehe', 'I go'),
        _seen('to_go_present_3', 'wir gehen', 'we go'),
        _seen('to_go_present_5', 'sie gehen', 'they go'),
        _seen('to_must_present_3', 'wir muessen', 'we must'),
        _seen('to_must_present_5', 'sie muessen', 'they must'),
      ], 'easy');
      expect(round.entries.where((w) => w.target == 'GEHEN').length, 1);
      expect(round.entries.where((w) => w.target == 'GEHE'), isEmpty);
    });

    test('Leben je Schwierigkeit korrekt', () {
      expect(createRound(_verbs([('to_go', 'gehen', 'we go')]), 'easy').lives,
          8);
      expect(createRound(_verbs([('to_go', 'gehen', 'we go')]), 'medium').lives,
          6);
      expect(createRound(_verbs([('to_go', 'gehen', 'we go')]), 'hard').lives,
          5);
    });
  });
}
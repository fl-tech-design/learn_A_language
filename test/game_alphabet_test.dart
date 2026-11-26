import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/alphabet.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/crossword_engine.dart' as cw;
import 'package:learn_a_language/screens/hangman_engine.dart' as hm;
import 'package:learn_a_language/screens/word_search_engine.dart' as ws;

/// Ticket #75: Buchstaben-Spiele müssen auch für nicht-lateinische Alphabete
/// (Griechisch, Russisch) funktionieren.
///
/// Vorher filterte die Normalisierung alle Zeichen außer a–z weg; griechische
/// Wörter wurden dadurch zu leeren Strings und die Engines fanden keine
/// Kandidaten („Keine gelesenen Wörter"). Diese Tests sichern die
/// sprachbewusste Normalisierung, die Alphabete und die Kandidatenbildung.
void main() {
  VocabEntry seen(String key, String word, String translation) => VocabEntry(
        key: key,
        word: word,
        translation: translation,
        examples: const [],
        examplesNative: const [],
        level: 1,
        status: 'seen',
      );

  group('normalizeForGrid – Alphabete', () {
    test('Griechisch: Akzente entfernen, Großbuchstaben', () {
      expect(normalizeForGrid('πηγαίνω', 'el'), 'ΠΗΓΑΙΝΩ');
      expect(normalizeForGrid('άλογο', 'el'), 'ΑΛΟΓΟ');
      expect(normalizeForGrid('θάλασσα', 'el'), 'ΘΑΛΑΣΣΑ');
    });

    test('Russisch: Ё→Е, Großbuchstaben', () {
      expect(normalizeForGrid('ёлка', 'ru'), 'ЕЛКА');
      expect(normalizeForGrid('привет', 'ru'), 'ПРИВЕТ');
    });

    test('Latein bleibt wie bisher (Regression)', () {
      expect(normalizeForGrid('öffnen', 'de'), 'OEFFNEN');
      expect(normalizeForGrid('ändern', 'de'), 'AENDERN');
      expect(ws.normalizeGridWord('öffnen'), 'OEFFNEN');
    });
  });

  group('alphabetFor', () {
    test('Griechisch: 24 Buchstaben inkl. Ω', () {
      expect(alphabetFor('el').length, 24);
      expect(alphabetFor('el'), contains('Ω'));
    });

    test('Russisch: 33 Buchstaben inkl. Я', () {
      expect(alphabetFor('ru').length, 33);
      expect(alphabetFor('ru'), contains('Я'));
    });

    test('Latein: A–Z', () {
      expect(alphabetFor('de').length, 26);
      expect(alphabetFor('de'), contains('Z'));
    });
  });

  group('Wortsuche – Griechisch', () {
    test('deriveSearchWord liefert griechischen Infinitiv', () {
      expect(
        ws.deriveSearchWord(
            seen('to_go_present_0', 'πηγαίνω', 'ich gehe'),
            langCode: 'el'),
        'ΠΗΓΑΙΝΩ',
      );
    });

    test('Partikel am Wortende wird übersprungen ("πρέπει να" → ΠΡΕΠΕΙ)',
        () {
      expect(
        ws.deriveSearchWord(
            seen('to_must_present_0', 'πρέπει να', 'muss'), langCode: 'el'),
        'ΠΡΕΠΕΙ',
      );
      expect(
        ws.deriveSearchWord(
            seen('to_should_present_0', 'εγώ πρέπει να', 'soll'),
            langCode: 'el'),
        'ΠΡΕΠΕΙ',
      );
    });

    test('generatePuzzle erzeugt spielbare Wörter', () {
      final puzzle = ws.generatePuzzle([
        seen('to_go_present_0', 'πηγαίνω', 'ich gehe'),
        seen('to_eat_present_0', 'τρώω', 'ich esse'),
        seen('to_live_present_0', 'ζω', 'ich lebe'),
      ], 'easy', langCode: 'el');
      expect(puzzle.words, isNotEmpty);
    });

    test('generatePuzzle mit Partikel-Verben ("Erste Verben"-artig)', () {
      final puzzle = ws.generatePuzzle([
        seen('to_can_present_0', 'εγώ μπορώ', 'kann'),
        seen('to_want_present_0', 'εγώ θέλω', 'will'),
        seen('to_should_present_0', 'εγώ πρέπει να', 'soll'),
        seen('to_must_present_0', 'πρέπει να', 'muss'),
      ], 'easy', langCode: 'el');
      expect(puzzle.words, isNotEmpty);
    });
  });

  group('Kreuzworträtsel – Griechisch', () {
    test('generatePuzzle erzeugt ein Rätsel', () {
      final puzzle = cw.generatePuzzle([
        seen('to_go_present_0', 'πηγαίνω', 'ich gehe'),
        seen('to_eat_present_0', 'τρώω', 'ich esse'),
        seen('to_live_present_0', 'ζω', 'ich lebe'),
      ], 'easy', langCode: 'el');
      expect(puzzle.words, isNotEmpty);
    });
  });

  group('Hangman – Griechisch/Russisch', () {
    test('createRound erzeugt Wörter (el)', () {
      final round = hm.createRound([
        seen('to_go_present_0', 'πηγαίνω', 'ich gehe'),
        seen('to_eat_present_0', 'τρώω', 'ich esse'),
      ], 'medium', langCode: 'el');
      expect(round.entries, isNotEmpty);
    });

    test('createRound erzeugt Wörter (ru)', () {
      final round = hm.createRound([
        seen('to_go_present_0', 'идти', 'ich gehe'),
        seen('to_live_present_0', 'жить', 'ich lebe'),
      ], 'medium', langCode: 'ru');
      expect(round.entries, isNotEmpty);
    });
  });
}

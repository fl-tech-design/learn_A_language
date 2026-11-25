import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/word_search_engine.dart';

/// Konjugations-Eintrag (gesehen, level 1 - spielbar).
VocabEntry _seen(String key, String word, String translation) => VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: const [],
      examplesNative: const [],
      level: 1,
      status: 'seen',
    );

/// Baut wir/sie-Praesens-Formen fuer mehrere Verben.
List<VocabEntry> _verbs(List<(String, String, String)> verbs) {
  final result = <VocabEntry>[];
  for (final (verbKey, infinitive, translation) in verbs) {
    result.add(_seen('${verbKey}_present_3', 'wir $infinitive', translation));
    result.add(_seen('${verbKey}_present_5', 'sie $infinitive', translation));
  }
  return result;
}

/// Prueft, ob die Zellen eine Gerade in genau einer Richtung sind.
bool _isStraight(List<Point> cells) {
  if (cells.length < 2) return true;
  final dr = (cells[1].row - cells[0].row).sign;
  final dc = (cells[1].col - cells[0].col).sign;
  if (dr == 0 && dc == 0) return false;
  for (var i = 1; i < cells.length; i++) {
    if (cells[i].row - cells[i - 1].row != dr ||
        cells[i].col - cells[i - 1].col != dc) {
      return false;
    }
  }
  return true;
}

/// true, wenn die Zellen ausschliesslich horizontal oder vertikal sind.
bool _isHV(List<Point> cells) {
  for (var i = 1; i < cells.length; i++) {
    final dr = cells[i].row - cells[i - 1].row;
    final dc = cells[i].col - cells[i - 1].col;
    if (dr != 0 && dc != 0) return false;
  }
  return true;
}

/// Buchstabenfolge des Gitters entlang der Zellen eines Wortes.
String _readWord(WordSearchPuzzle puzzle, WordSearchWord w) =>
    w.cells.map((p) => puzzle.letterAt(p)).join();

void main() {
  group('generatePuzzle', () {
    test('easy: 8x8, 4 Woerter, nur horizontal/vertikal, lesbar', () {
      final puzzle = generatePuzzle(
          _verbs([
            ('to_go', 'gehen', 'we go'),
            ('to_come', 'kommen', 'we come'),
            ('to_read', 'lesen', 'we read'),
            ('to_work', 'arbeiten', 'we work'),
            ('to_find', 'finden', 'we find'),
            ('to_learn', 'lernen', 'we learn'),
          ]),
          'easy');

      expect(puzzle.size, 8);
      expect(puzzle.words.length, 4);
      for (final w in puzzle.words) {
        expect(w.cells.length, w.word.length);
        expect(_readWord(puzzle, w), w.word);
        expect(_isStraight(w.cells), isTrue);
        expect(_isHV(w.cells), isTrue, reason: 'easy/medium: nur h+v');
        expect(w.word.length, greaterThanOrEqualTo(3));
      }
    });

    test('medium: 10x10, 6 Woerter, lesbar', () {
      final puzzle = generatePuzzle(
          _verbs([
            ('to_go', 'gehen', 'we go'),
            ('to_come', 'kommen', 'we come'),
            ('to_read', 'lesen', 'we read'),
            ('to_work', 'arbeiten', 'we work'),
            ('to_find', 'finden', 'we find'),
            ('to_learn', 'lernen', 'we learn'),
            ('to_write', 'schreiben', 'we write'),
          ]),
          'medium');

      expect(puzzle.size, 10);
      expect(puzzle.words.length, 6);
      for (final w in puzzle.words) {
        expect(_readWord(puzzle, w), w.word);
        expect(_isStraight(w.cells), isTrue);
        expect(_isHV(w.cells), isTrue);
      }
    });

    test('hard: 12x12, 8 Woerter, Diagonalen erlaubt, lesbar', () {
      final puzzle = generatePuzzle(
          _verbs([
            ('to_go', 'gehen', 'we go'),
            ('to_come', 'kommen', 'we come'),
            ('to_read', 'lesen', 'we read'),
            ('to_work', 'arbeiten', 'we work'),
            ('to_find', 'finden', 'we find'),
            ('to_learn', 'lernen', 'we learn'),
            ('to_write', 'schreiben', 'we write'),
            ('to_speak', 'sprechen', 'we speak'),
            ('to_understand', 'verstehen', 'we understand'),
            ('to_live', 'wohnen', 'we live'),
          ]),
          'hard');

      expect(puzzle.size, 12);
      expect(puzzle.words.length, 8);
      for (final w in puzzle.words) {
        expect(_readWord(puzzle, w), w.word);
        expect(_isStraight(w.cells), isTrue);
        expect(w.word.length, lessThanOrEqualTo(12));
      }
      final allLetters = puzzle.grid
          .expand((row) => row)
          .every((c) =>
              c.length == 1 && c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90);
      expect(allLetters, isTrue);
    });
  });

  group('validatePath', () {
    final grid = [
      ['A', 'B', 'C'],
      ['D', 'E', 'F'],
      ['G', 'H', 'I'],
    ];
    final word = WordSearchWord(
      word: 'ABC',
      translation: 'x',
      cells: const [Point(0, 0), Point(0, 1), Point(0, 2)],
    );
    final puzzle = WordSearchPuzzle(grid: grid, words: [word]);

    test('erkennt Treffer vorwaerts und liefert das Wort', () {
      expect(
          validatePath(
              const [Point(0, 0), Point(0, 1), Point(0, 2)], puzzle),
          same(word));
    });

    test('erkennt Treffer rueckwaerts', () {
      expect(
          validatePath(
              const [Point(0, 2), Point(0, 1), Point(0, 0)], puzzle),
          same(word));
    });

    test('falsche Zelle liefert null', () {
      expect(
          validatePath(
              const [Point(1, 0), Point(1, 1), Point(1, 2)], puzzle),
          isNull);
    });

    test('Knick im Pfad liefert null', () {
      expect(
          validatePath(
              const [Point(0, 0), Point(0, 1), Point(1, 2)], puzzle),
          isNull);
    });

    test('bereits gefundenes Wort wird nicht nochmal gemeldet', () {
      final w2 = WordSearchWord(
        word: 'ABC',
        translation: 'x',
        cells: const [Point(0, 0), Point(0, 1), Point(0, 2)],
        found: true,
      );
      final p2 = WordSearchPuzzle(grid: grid, words: [w2]);
      expect(
          validatePath(
              const [Point(0, 0), Point(0, 1), Point(0, 2)], p2),
          isNull);
    });
  });

  group('Infinitiv-Ableitung', () {
    test('aus Konjugationen zu GEHEN dedupliziert, Umlaute normalisiert', () {
      final puzzle = generatePuzzle(
          [
            _seen('to_go_present_0', 'ich gehe', 'I go'),
            _seen('to_go_present_1', 'du gehst', 'you go'),
            _seen('to_go_present_3', 'wir gehen', 'we go'),
            _seen('to_go_present_5', 'sie gehen', 'they go'),
            _seen('to_must_present_3', 'wir muessen', 'we must'),
            _seen('to_must_present_5', 'sie muessen', 'they must'),
            _seen('to_work_present_3', 'wir arbeiten', 'we work'),
            _seen('to_work_present_5', 'sie arbeiten', 'they work'),
            _seen('to_read_present_3', 'wir lesen', 'we read'),
            _seen('to_read_present_5', 'sie lesen', 'they read'),
          ],
          'easy');

      expect(
          puzzle.words.where((w) => w.word == 'GEHEN').length, 1,
          reason: 'gleicher Infinitiv nur einmal');
    });

    test('Umlaut-Normalisierung (ue -> UE, ss-Ersatz)', () {
      expect(deriveSearchWord(_seen('to_must_present_3', 'wir m', 'we')), null);
      expect(deriveSearchWord(_seen('to_must_present_5', 'sie muessen', 'we')),
          'MUESSEN');
      expect(normalizeGridWord('öffnen'), 'OEFFNEN');
      expect(normalizeGridWord('ändern'), 'AENDERN');
    });

    test('Ein-Wort-Eintraege werden direkt verwendet', () {
      expect(deriveSearchWord(_seen('app_nomen_1', 'Haus', 'house')), 'HAUS');
    });
  });

  group('Wort-Pool-Filter', () {
    test('status new und level 0 landen niemals im Puzzle', () {
      final puzzle = generatePuzzle(
          [
            _seen('to_go_present_3', 'wir gehen', 'we go'),
            _seen('to_come_present_3', 'wir kommen', 'we come'),
            _seen('to_read_present_3', 'wir lesen', 'we read'),
            _seen('to_work_present_3', 'wir arbeiten', 'we work'),
            // NIE spielbar: level 0 + status 'new' sind die VocabEntry-Defaults.
            VocabEntry(
              key: 'to_live_present_3',
              word: 'wir laufen',
              translation: 'we run',
              examples: const [],
              examplesNative: const [],
            ),
          ],
          'easy');

      expect(puzzle.words.where((w) => w.word == 'LAUFEN'), isEmpty);
    });

    test('gelesene Woerter mit level 0 sind spielbar (Ticket #61)', () {
      final puzzle = generatePuzzle(
          [
            VocabEntry(
              key: 'to_buy_present_3',
              word: 'wir kaufen',
              translation: 'we buy',
              examples: const [],
              examplesNative: const [],
              status: 'seen',
            ),
          ],
          'easy');

      expect(puzzle.words.where((w) => w.word == 'KAUFEN'), isNotEmpty);
    });
  });
}

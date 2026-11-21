import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/crossword_engine.dart';

/// Konjugations-Eintrag (gesehen, level 1 – spielbar).
VocabEntry _seen(String key, String word, String translation) => VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: const [],
      examplesNative: const [],
      level: 1,
      status: 'seen',
    );

/// Baut wir/sie-Praesens-Formen fuer mehrere Verben: die Praesens-3/5-Form
/// ("wir gehen"/"sie gehen") liefert den Infinitiv-Kandidaten.
List<VocabEntry> _verbs(List<(String, String, String)> verbs) {
  final result = <VocabEntry>[];
  for (final (verbKey, infinitive, translation) in verbs) {
    result.add(_seen('${verbKey}_present_3', 'wir $infinitive', translation));
    result.add(_seen('${verbKey}_present_5', 'sie $infinitive', translation));
  }
  return result;
}

/// Liest die Buchstabenfolge des Gitters entlang der Zellen eines Wortes.
String _readWord(CrosswordPuzzle puzzle, CrosswordWord w) =>
    w.cells.map((p) => puzzle.cellAt(p)!.letter).join();

/// Pool aus 24 Verben – ausreichend fuer alle drei Schwierigkeitsgrade.
List<VocabEntry> _verbPool() => _verbs([
      ('to_go', 'gehen', 'we go'),
      ('to_come', 'kommen', 'we come'),
      ('to_read', 'lesen', 'we read'),
      ('to_work', 'arbeiten', 'we work'),
      ('to_find', 'finden', 'we find'),
      ('to_learn', 'lernen', 'we learn'),
      ('to_write', 'schreiben', 'we write'),
      ('to_speak', 'sprechen', 'we speak'),
      ('to_understand', 'verstehen', 'we understand'),
      ('to_buy', 'kaufen', 'we buy'),
      ('to_sell', 'verkaufen', 'we sell'),
      ('to_make', 'machen', 'we make'),
      ('to_begin', 'beginnen', 'we begin'),
      ('to_end', 'enden', 'we end'),
      ('to_open', 'oeffnen', 'we open'),
      ('to_close', 'schliessen', 'we close'),
      ('to_eat', 'essen', 'we eat'),
      ('to_drink', 'trinken', 'we drink'),
      ('to_help', 'helfen', 'we help'),
      ('to_live', 'wohnen', 'we live'),
      ('to_need', 'brauchen', 'we need'),
      ('to_see', 'sehen', 'we see'),
      ('to_have', 'haben', 'we have'),
      ('to_be', 'sein', 'we are'),
    ]);

/// Handgebautes Mini-Puzzle fuer isolierte checkLetter-Tests:
/// waagrecht "ABC" (Zeile 0) kreuzt das senkrechte "ADE" (Spalte 0) an 'A'.
CrosswordPuzzle _miniPuzzle() {
  Cell cell(String letter, {bool h = false, bool v = false}) => Cell(
        letter: letter,
        crossedH: h,
        crossedV: v,
      );
  return CrosswordPuzzle(
    grid: [
      [cell('A', h: true, v: true), cell('B', h: true), cell('C', h: true)],
      [cell('D', v: true), cell(''), cell('')],
      [cell('E', v: true), cell(''), cell('')],
    ],
    words: [
      CrosswordWord(
        word: 'ABC',
        translation: 'triple',
        cells: const [
          CrosswordPos(0, 0),
          CrosswordPos(0, 1),
          CrosswordPos(0, 2),
        ],
        direction: 'h',
      ),
      CrosswordWord(
        word: 'ADE',
        translation: 'down',
        cells: const [
          CrosswordPos(0, 0),
          CrosswordPos(1, 0),
          CrosswordPos(2, 0),
        ],
        direction: 'v',
      ),
    ],
  );
}
void main() {
  group('generatePuzzle', () {
    test('easy: 8 Woerter, alle von ihrer Startzelle lesbar', () {
      final puzzle = generatePuzzle(_verbPool(), 'easy');
      expect(puzzle.words.length, 8);
      for (final w in puzzle.words) {
        expect(w.cells.length, w.word.length);
        expect(puzzle.cellAt(w.start)!.letter, w.word[0]);
        expect(_readWord(puzzle, w), w.word);
      }
    });

    test('medium: 12 Woerter, alle von ihrer Startzelle lesbar', () {
      final puzzle = generatePuzzle(_verbPool(), 'medium');
      expect(puzzle.words.length, 12);
      for (final w in puzzle.words) {
        expect(w.cells.length, w.word.length);
        expect(puzzle.cellAt(w.start)!.letter, w.word[0]);
        expect(_readWord(puzzle, w), w.word);
      }
    });

    test('hard: 16 Woerter, alle von ihrer Startzelle lesbar', () {
      final puzzle = generatePuzzle(_verbPool(), 'hard');
      expect(puzzle.words.length, 16);
      for (final w in puzzle.words) {
        expect(w.cells.length, w.word.length);
        expect(puzzle.cellAt(w.start)!.letter, w.word[0]);
        expect(_readWord(puzzle, w), w.word);
      }
    });

    test('minimale Begrenzungsbox + mindestens ein leeres Feld', () {
      final puzzle = generatePuzzle(_verbPool(), 'easy');
      expect(puzzle.rows, greaterThan(0));
      expect(puzzle.cols, greaterThan(0));
      final hasEmpty =
          puzzle.grid.any((row) => row.any((cell) => cell.isEmpty));
      expect(hasEmpty, isTrue,
          reason: 'immer mind. 1 leeres Feld als Hinweis-Button');
      for (final w in puzzle.words) {
        for (final p in w.cells) {
          expect(puzzle.cellAt(p), isNotNull,
              reason: 'alle Wortzellen liegen in der Begrenzungsbox');
        }
      }
    });
  });

  group('checkLetter', () {
    test('richtiger Buchstabe loest die Zelle, falscher laesst sie leer', () {
      final puzzle = _miniPuzzle();
      const active = ActiveCell(CrosswordPos(0, 1), 'h');

      final wrong = checkLetter(puzzle, active, 'X');
      expect(wrong.correct, isFalse);
      expect(puzzle.cellAt(const CrosswordPos(0, 1))!.solved, isFalse);

      final ok = checkLetter(puzzle, active, 'b'); // Grossschreibung erwartet
      expect(ok.correct, isTrue);
      expect(puzzle.cellAt(const CrosswordPos(0, 1))!.solved, isTrue);

      // Bereits geloeste Zellen koennen nicht erneut belegt werden.
      final again = checkLetter(puzzle, active, 'B');
      expect(again.correct, isFalse);
    });

    test('next-cell-Weiterschalten isoliert (Wort -> naechstes offenes Wort)',
        () {
      final puzzle = _miniPuzzle();

      var active = const ActiveCell(CrosswordPos(0, 0), 'h');
      expect(checkLetter(puzzle, active, 'A').nextActive,
          const ActiveCell(CrosswordPos(0, 1), 'h'));

      active = const ActiveCell(CrosswordPos(0, 1), 'h');
      expect(checkLetter(puzzle, active, 'B').nextActive,
          const ActiveCell(CrosswordPos(0, 2), 'h'));

      // Wortende von ABC: Cursor springt zum naechsten offenen Wort (ADE),
      // wobei die bereits geloeste Kreuzungszelle (0,0) uebersprungen wird.
      active = const ActiveCell(CrosswordPos(0, 2), 'h');
      expect(checkLetter(puzzle, active, 'C').nextActive,
          const ActiveCell(CrosswordPos(1, 0), 'v'));

      active = const ActiveCell(CrosswordPos(1, 0), 'v');
      expect(checkLetter(puzzle, active, 'D').nextActive,
          const ActiveCell(CrosswordPos(2, 0), 'v'));

      // Letzte Zelle des Raetsels: kein naechster Cursor mehr.
      active = const ActiveCell(CrosswordPos(2, 0), 'v');
      final last = checkLetter(puzzle, active, 'E');
      expect(last.correct, isTrue);
      expect(last.nextActive, isNull);
    });
  });

  group('isPuzzleSolved', () {
    test('erst nach dem allerletzten Buchstaben true', () {
      final puzzle = _miniPuzzle();
      expect(isPuzzleSolved(puzzle), isFalse);

      var active = const ActiveCell(CrosswordPos(0, 0), 'h');
      checkLetter(puzzle, active, 'A');
      active = const ActiveCell(CrosswordPos(0, 1), 'h');
      checkLetter(puzzle, active, 'B');
      active = const ActiveCell(CrosswordPos(0, 2), 'h');
      checkLetter(puzzle, active, 'C');
      expect(isPuzzleSolved(puzzle), isFalse);

      active = const ActiveCell(CrosswordPos(1, 0), 'v');
      checkLetter(puzzle, active, 'D');
      expect(isPuzzleSolved(puzzle), isFalse);

      active = const ActiveCell(CrosswordPos(2, 0), 'v');
      checkLetter(puzzle, active, 'E');
      expect(isPuzzleSolved(puzzle), isTrue);
    });
  });

  group('Wort-Pool-Filter', () {
    test("status 'new' und level 0 landen niemals im Raetsel", () {
      final puzzle = generatePuzzle([
        ..._verbs([('to_go', 'gehen', 'we go')]),
        ..._verbs([('to_come', 'kommen', 'we come')]),
        ..._verbs([('to_read', 'lesen', 'we read')]),
        ..._verbs([('to_work', 'arbeiten', 'we work')]),
        ..._verbs([('to_find', 'finden', 'we find')]),
        ..._verbs([('to_learn', 'lernen', 'we learn')]),
        ..._verbs([('to_write', 'schreiben', 'we write')]),
        ..._verbs([('to_speak', 'sprechen', 'we speak')]),
        ..._verbs([('to_understand', 'verstehen', 'we understand')]),
        ..._verbs([('to_buy', 'kaufen', 'we buy')]),
        ..._verbs([('to_sell', 'verkaufen', 'we sell')]),
        ..._verbs([('to_make', 'machen', 'we make')]),
        ..._verbs([('to_begin', 'beginnen', 'we begin')]),
        // NIE spielbar: level 0 + status 'new' (VocabEntry-Defaults).
        VocabEntry(
          key: 'to_live_present_3',
          word: 'wir laufen',
          translation: 'we run',
          examples: const [],
          examplesNative: const [],
        ),
        // Auch 'seen' + level 0 (Default) bleibt draussen.
        VocabEntry(
          key: 'to_end_present_3',
          word: 'wir enden',
          translation: 'we end',
          examples: const [],
          examplesNative: const [],
          status: 'seen',
        ),
      ], 'medium');
      expect(puzzle.words.where((w) => w.word == 'LAUFEN'), isEmpty);
      expect(puzzle.words.where((w) => w.word == 'ENDEN'), isEmpty);
    });

    test('gleicher Infinitiv nur einmal (Deduplizierung)', () {
      final puzzle = generatePuzzle([
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
      ], 'easy');
      expect(puzzle.words.where((w) => w.word == 'GEHEN').length, 1,
          reason: 'gleicher Infinitiv nur einmal');
      expect(puzzle.words.where((w) => w.word == 'GEHE'), isEmpty);
    });
  });
}
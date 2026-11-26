import 'dart:math';

import '../models/app_models.dart';
import '../models/vocab_key.dart';
import 'word_search_engine.dart' show deriveSearchWord;

/// Kreuzwortraetsel-Engine – pure Dart, OHNE Flutter-Imports.
///
/// Wiederverwendete Patterns (nicht neu erfunden):
/// - Wortdaten: [VocabEntry] aus `app_models.dart`.
/// - Infinitiv-Ableitung: `vocabVerbKey` (vocab_key.dart) fuer die
///   Verb-Gruppierung und `deriveSearchWord` (word_search_engine.dart, rein
///   pures Dart) fuer die Ableitung des gesuchten Infinitivs.
/// - Spielbare Woerter: ausschliesslich status 'seen' UND level >= 1;
///   Kategorie-0-Woerter (status 'new' / level 0) landen NIE im Raetsel.

/// Position einer Gitterzelle (Zeile/Spalte, 0-basiert).
class CrosswordPos {
  final int row;
  final int col;

  const CrosswordPos(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is CrosswordPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'CrosswordPos($row, $col)';
}

/// Eine Zelle des Kreuzwortraetsel-Gitters.
class Cell {
  /// Loesung (Grossbuchstabe A-Z) bzw. leer, wenn kein Wort die Zelle nutzt.
  final String letter;

  /// Vom Spieler bereits korrekt eingegeben.
  bool solved;

  /// Zelle liegt in mindestens einem waagrechten Wort.
  final bool crossedH;

  /// Zelle liegt in mindestens einem senkrechten Wort.
  final bool crossedV;

  Cell({
    required this.letter,
    this.solved = false,
    this.crossedH = false,
    this.crossedV = false,
  });

  /// Leeres Feld: kein Wort benutzt diese Zelle (dient in der UI als
  /// Hinweis-Button).
  bool get isEmpty => letter.isEmpty;
}

/// Ein zu loesendes Wort im Raetsel.
class CrosswordWord {
  /// Gesuchtes Wort (normalisierter Infinitiv, Grossbuchstaben A-Z).
  final String word;

  /// Hinweis fuer den Spieler (Uebersetzung des zugrunde liegenden Eintrags).
  final String translation;

  /// Zellen des platzierten Wortes in Leserichtung.
  final List<CrosswordPos> cells;

  /// 'h' = waagrecht, 'v' = senkrecht.
  final String direction;

  bool solved;

  CrosswordWord({
    required this.word,
    required this.translation,
    required this.cells,
    required this.direction,
    this.solved = false,
  });

  /// Erste Zelle des Wortes (Startzelle in Leserichtung).
  CrosswordPos get start => cells.first;
}
/// Ein erzeugtes Kreuzwortraetsel-Puzzle in seiner minimalen Begrenzungsbox.
class CrosswordPuzzle {
  final List<List<Cell>> grid;
  final List<CrosswordWord> words;

  CrosswordPuzzle({required this.grid, required this.words});

  int get rows => grid.length;

  int get cols => grid.isEmpty ? 0 : grid.first.length;

  /// Zelle an [pos] oder null, wenn ausserhalb des Gitters.
  Cell? cellAt(CrosswordPos pos) {
    if (pos.row < 0 || pos.row >= rows || pos.col < 0 || pos.col >= cols) {
      return null;
    }
    return grid[pos.row][pos.col];
  }
}

/// Aktive Zelle samt gewaehlter Leserichtung (Cursorkontext).
class ActiveCell {
  final CrosswordPos pos;
  final String direction;

  const ActiveCell(this.pos, this.direction);

  @override
  bool operator ==(Object other) =>
      other is ActiveCell && other.pos == pos && other.direction == direction;

  @override
  int get hashCode => Object.hash(pos, direction);

  @override
  String toString() => 'ActiveCell($pos, $direction)';
}

/// Ergebnis einer Buchstabeneingabe.
class CrosswordCheckResult {
  final bool correct;

  /// Naechste zu befuellende Zelle bzw. null, wenn das Raetsel geloest ist.
  final ActiveCell? nextActive;

  const CrosswordCheckResult({required this.correct, this.nextActive});
}

/// Interner Kandidat vor der Platzierung.
class _Candidate {
  final String word;
  final String translation;

  _Candidate(this.word, this.translation);
}

/// Wortanzahl je Schwierigkeit: easy 8, medium 12, hard 16.
int _wordCountFor(String difficulty) => switch (difficulty) {
      'easy' => 8,
      'hard' => 16,
      _ => 12, // medium Default
    };

/// Erlaubt nur Eintraege, die spielbar sind: status 'seen' (Level egal).
///
/// Wird nach dem Laden zusaetzlich angewendet, damit NIE Woerter der
/// Kategorie 0 (status 'new') ins Raetsel gelangen. Seit Ticket #61 ist
/// der Filter identisch zum Turbo-Spiel: jedes gelesene Wort ist spielbar.
List<VocabEntry> _usableEntries(List<VocabEntry> entries) =>
    entries.where((e) => e.status == 'seen').toList();

/// Baut die Kandidaten-Woerter fuer das Raetsel.
///
/// Gruppiert nach Verb ([vocabVerbKey]) und waehlt je Verb den besten
/// Infinitiv-Kandidaten (Ableitung ueber die BESTEHENDE Wortsuche-Logik
/// [deriveSearchWord] – nicht neu erfunden). Gleiche Infinitive (z. B.
/// "wir gehen" und "sie gehen") erscheinen nur einmal.
List<_Candidate> _buildCandidates(
    List<VocabEntry> entries, String langCode) {
  final byVerb = <String, List<VocabEntry>>{};
  for (final e in _usableEntries(entries)) {
    byVerb.putIfAbsent(vocabVerbKey(e.key), () => []).add(e);
  }

  final result = <_Candidate>[];
  for (final group in byVerb.values) {
    final best = _pickInfinitive(group, langCode);
    if (best != null) result.add(best);
  }

  // Deduplizierung identischer Infinitive ueber verschiedene Verben hinweg.
  final seen = <String>{};
  final unique = <_Candidate>[];
  for (final c in result) {
    if (seen.add(c.word)) unique.add(c);
  }
  return unique;
}
/// Waehlt fuer eine Verbgruppe den besten Infinitiv-Kandidaten.
///
/// Der Infinitiv ist die haeufigste Form: z. B. liefern die wir/sie-Formen
/// ("wir gehen", "sie gehen") denselben Kandidaten "GEHEN" und gewinnen so
/// gegen Einzelformen ("ich gehe" -> "GEHE"). Bei Gleichstand gewinnt die
/// laengere Form.
_Candidate? _pickInfinitive(List<VocabEntry> group, String langCode) {
  _Candidate? best;
  var bestCount = 0;
  for (final entry in group) {
    final word = deriveSearchWord(entry, langCode: langCode);
    if (word == null) continue;
    final count =
        group.where((o) => deriveSearchWord(o, langCode: langCode) == word)
            .length;
    final translation =
        entry.translation.isEmpty ? entry.word : entry.translation;
    if (best == null ||
        count > bestCount ||
        (count == bestCount && word.length > best.word.length)) {
      best = _Candidate(word, translation);
      bestCount = count;
    }
  }
  return best;
}

/// Liefert das Wort mit [direction], das [pos] enthaelt, oder null.
CrosswordWord? wordAt(
    CrosswordPuzzle puzzle, CrosswordPos pos, String direction) {
  for (final w in puzzle.words) {
    if (w.direction == direction && w.cells.contains(pos)) return w;
  }
  return null;
}

/// Alle orthogonalen Nachbarn einer Zelle.
List<CrosswordPos> _neighbors(CrosswordPos p) => [
      CrosswordPos(p.row - 1, p.col),
      CrosswordPos(p.row + 1, p.col),
      CrosswordPos(p.row, p.col - 1),
      CrosswordPos(p.row, p.col + 1),
    ];

/// Prueft, ob die Platzierung von [word] auf [cells] gueltig ist.
///
/// - Bereits belegte Zellen muessen denselben Buchstaben tragen
///   (Ueberschneidung NUR bei Buchstabenuebereinstimmung).
/// - Neue Zellen duerfen nicht an fremde, belegte Zellen grenzen (keine
///   parallelen/angrenzenden Wortbloecke, damit das Gitter lesbar bleibt).
/// - Fuer alle Woerter ausser dem ersten ist mindestens eine Ueberschneidung
///   (reuse) Pflicht.
bool _canPlace(
    Map<CrosswordPos, String> occupied, List<CrosswordPos> cells, String word) {
  final newCells = cells.toSet();
  var reuse = 0;
  for (var i = 0; i < cells.length; i++) {
    final existing = occupied[cells[i]];
    if (existing != null) {
      if (existing != word[i]) return false;
      reuse++;
      continue;
    }
    for (final nb in _neighbors(cells[i])) {
      if (occupied.containsKey(nb) && !newCells.contains(nb)) return false;
    }
  }
  return reuse >= 1;
}

/// Alle kreuzenden Platzierungs-Optionen fuer [word] gegen die gelegten Woerter.
List<(List<CrosswordPos>, String)> _crossOptions(
    List<CrosswordWord> placed, String word) {
  final options = <(List<CrosswordPos>, String)>[];
  for (final w in placed) {
    for (var j = 0; j < w.cells.length; j++) {
      for (var i = 0; i < word.length; i++) {
        if (w.word[j] != word[i]) continue;
        final crossing = w.cells[j];
        if (w.direction == 'h') {
          // Neues Wort senkrecht durch die Kreuzungszelle.
          final startRow = crossing.row - i;
          options.add((
            [
              for (var k = 0; k < word.length; k++)
                CrosswordPos(startRow + k, crossing.col)
            ],
            'v',
          ));
        } else {
          // Neues Wort waagrecht durch die Kreuzungszelle.
          final startCol = crossing.col - i;
          options.add((
            [
              for (var k = 0; k < word.length; k++)
                CrosswordPos(crossing.row, startCol + k)
            ],
            'h',
          ));
        }
      }
    }
  }
  return options;
}
/// Versucht, [word] im aktuellen Gitter zu platzieren.
///
/// Das erste Wort liegt waagrecht an Position (0, 0); alle weiteren Woerter
/// muessen ein bereits platziertes Wort kreuzen (Buchstabe identisch). Liefert
/// (Zellen, Richtung) oder null, wenn kein gueltiger Platz existiert – dann
/// wird das Wort weggelassen.
(List<CrosswordPos>, String)? _tryPlace(Map<CrosswordPos, String> occupied,
    List<CrosswordWord> placed, String word, Random rng) {
  if (placed.isEmpty) {
    return ([
      for (var i = 0; i < word.length; i++) CrosswordPos(0, i),
    ], 'h');
  }

  final options = _crossOptions(placed, word)..shuffle(rng);
  for (final option in options) {
    if (_canPlace(occupied, option.$1, word)) return option;
  }
  return null;
}

/// Erzeugt ein Kreuzwortraetsel-Puzzle aus den Vokabel-Eintraegen.
///
/// - easy: 8 Woerter, medium: 12 Woerter, hard: 16 Woerter.
/// - Es werden NUR Eintraege mit status 'seen' und level >= 1 verwendet
///   (siehe [_usableEntries]); Infinitive sind dedupliziert.
/// - Jedes Spiel erzeugt ein NEUES Gitter (zufaellige Wortauswahl), das an die
///   gewaehlten Woerter angepasst gezeichnet wird: Begrenzungsbox der
///   Platzierung, keine feste Gittergroesse.
/// - Immer bleibt mindestens EIN leeres Feld erhalten, das in der UI als
///   Hinweis-Button dient.
CrosswordPuzzle generatePuzzle(List<VocabEntry> entries, String difficulty,
    {String langCode = 'de'}) {
  final target = _wordCountFor(difficulty);
  final rng = Random();

  final candidates = _buildCandidates(entries, langCode)..shuffle(rng);

  final placed = <CrosswordWord>[];
  final occupied = <CrosswordPos, String>{};

  for (final candidate in candidates) {
    if (placed.length >= target) break;
    final result = _tryPlace(occupied, placed, candidate.word, rng);
    if (result == null) continue; // Platzierung nicht moeglich: Wort weglassen
    final cells = result.$1;
    for (var i = 0; i < cells.length; i++) {
      occupied[cells[i]] = candidate.word[i];
    }
    placed.add(CrosswordWord(
      word: candidate.word,
      translation: candidate.translation,
      cells: cells,
      direction: result.$2,
    ));
  }

  // Minimale Begrenzungsbox ueber alle platzierten Zellen.
  var minRow = 0, maxRow = 0, minCol = 0, maxCol = 0;
  var first = true;
  for (final w in placed) {
    for (final p in w.cells) {
      if (first) {
        minRow = maxRow = p.row;
        minCol = maxCol = p.col;
        first = false;
      } else {
        minRow = min(minRow, p.row);
        maxRow = max(maxRow, p.row);
        minCol = min(minCol, p.col);
        maxCol = max(maxCol, p.col);
      }
    }
  }

  final rows = maxRow - minRow + 1;
  final cols = maxCol - minCol + 1;

  final hCells = <CrosswordPos>{};
  final vCells = <CrosswordPos>{};
  for (final w in placed) {
    (w.direction == 'h' ? hCells : vCells).addAll(w.cells);
  }

  final grid = [
    for (var r = 0; r < rows; r++)
      [
        for (var c = 0; c < cols; c++)
          Cell(
            letter: occupied[CrosswordPos(r + minRow, c + minCol)] ?? '',
            crossedH: hCells.contains(CrosswordPos(r + minRow, c + minCol)),
            crossedV: vCells.contains(CrosswordPos(r + minRow, c + minCol)),
          ),
      ],
  ];

  // Immer mindestens ein leeres Feld im Gitter (Hinweis-Button). Ist die
  // Begrenzungsbox komplett belegt, wird eine leere Spalte angehaengt.
  if (!grid.any((row) => row.any((cell) => cell.isEmpty))) {
    for (final row in grid) {
      row.add(Cell(letter: ''));
    }
  }

  final words = [
    for (final w in placed)
      CrosswordWord(
        word: w.word,
        translation: w.translation,
        cells: [
          for (final p in w.cells) CrosswordPos(p.row - minRow, p.col - minCol)
        ],
        direction: w.direction,
      ),
  ];

  return CrosswordPuzzle(grid: grid, words: words);
}
/// Prueft einen Buchstaben an der [active] Zelle.
///
/// Bei richtigem Buchstaben wird die Zelle eingetragen (solved), der
/// Loesungs-Status der betroffenen Woerter (waagrecht UND senkrecht)
/// aktualisiert und direkt die naechste aktive Zelle gepfadet (naechste leere
/// Zelle in Leserichtung; am Wortende das naechste offene Wort). Bei falschem
/// Buchstaben passiert nichts: die Zelle bleibt leer.
CrosswordCheckResult checkLetter(
    CrosswordPuzzle puzzle, ActiveCell active, String guessedLetter) {
  final cell = puzzle.cellAt(active.pos);
  final letter = guessedLetter.trim().toUpperCase();
  if (cell == null || cell.isEmpty || cell.solved || letter.length != 1) {
    return const CrosswordCheckResult(correct: false);
  }
  if (letter != cell.letter) {
    return const CrosswordCheckResult(correct: false);
  }

  cell.solved = true;

  // solved-Status der betroffenen Woerter aktualisieren.
  for (final w in puzzle.words) {
    if (!w.solved && w.cells.contains(active.pos)) {
      w.solved = w.cells.every((p) => puzzle.cellAt(p)?.solved ?? true);
    }
  }

  return CrosswordCheckResult(
      correct: true, nextActive: _nextActive(puzzle, active));
}

/// Liefert die aktive Zelle des aktiven Wortes von [active].
CrosswordWord? _activeWord(CrosswordPuzzle puzzle, ActiveCell active) =>
    wordAt(puzzle, active.pos, active.direction);

/// Pfadet den Cursor nach einer korrekten Eingabe weiter.
///
/// 1. Naechste ungeloeste Zelle im aktiven Wort (Leserichtung),
/// 2. sonst das naechste offene Wort (dessen erste ungeloeste Zelle),
/// 3. null, wenn alles geloest ist.
ActiveCell? _nextActive(CrosswordPuzzle puzzle, ActiveCell active) {
  final word = _activeWord(puzzle, active);
  if (word != null && !word.solved) {
    final index = word.cells.indexOf(active.pos);
    for (var i = index + 1; i < word.cells.length; i++) {
      final c = puzzle.cellAt(word.cells[i]);
      if (c != null && !c.solved) {
        return ActiveCell(word.cells[i], word.direction);
      }
    }
  }

  // Wortende erreicht (oder Richtung ohne Wort): naechstes offenes Wort.
  final words = puzzle.words;
  if (words.isEmpty) return null;
  final start = word == null ? 0 : words.indexOf(word) + 1;
  for (var i = 0; i < words.length; i++) {
    final w = words[(start + i) % words.length];
    if (w.solved) continue;
    for (final p in w.cells) {
      final c = puzzle.cellAt(p);
      if (c != null && !c.solved) {
        return ActiveCell(p, w.direction);
      }
    }
  }
  return null; // alles geloest
}

/// True, sobald ALLE Woerter des Raetsels geloest sind.
bool isPuzzleSolved(CrosswordPuzzle puzzle) =>
    puzzle.words.isNotEmpty && puzzle.words.every((w) => w.solved);
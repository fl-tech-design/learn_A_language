import 'dart:math';

import '../models/app_models.dart';
import '../models/vocab_key.dart';

/// Punkt im Wortsuch-Gitter (Zeile/Spalte, 0-basiert).
///
/// Eigene Klasse (statt `dart:math.Point`), damit row/col sprechend sind und
/// die Engine ohne Flutter-Importe auskommt (pure Dart).
class Point {
  final int row;
  final int col;

  const Point(this.row, this.col);

  bool get isDiagonal => row != 0 && col != 0;

  @override
  bool operator ==(Object other) =>
      other is Point && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'Point($row, $col)';
}

/// Ein zu suchendes Wort im Puzzle.
class WordSearchWord {
  final String word;

  /// Hinweis für den Spieler (Übersetzung des zugrunde liegenden Eintrags).
  final String translation;

  /// Zellen des platzierten Wortes im Gitter (Leserichtung).
  final List<Point> cells;

  bool found;

  WordSearchWord({
    required this.word,
    required this.translation,
    required this.cells,
    this.found = false,
  });
}

/// Ein erzeugtes Wortsuch-Puzzle.
class WordSearchPuzzle {
  final List<List<String>> grid;
  final List<WordSearchWord> words;

  WordSearchPuzzle({required this.grid, required this.words});

  /// Kantenlänge des quadratischen Gitters.
  int get size => grid.length;

  /// Buchstabe an der Zelle (immer ein Großbuchstabe A-Z).
  String letterAt(Point p) => grid[p.row][p.col];
}

/// Schwierigkeits-Konfiguration.
class _DifficultyConfig {
  final int size;
  final int wordCount;
  final bool diagonal;

  const _DifficultyConfig(this.size, this.wordCount, {required this.diagonal});
}

_DifficultyConfig _configFor(String difficulty) => switch (difficulty) {
      'easy' => const _DifficultyConfig(8, 4, diagonal: false),
      'hard' => const _DifficultyConfig(12, 8, diagonal: true),
      _ => const _DifficultyConfig(10, 6, diagonal: false), // medium Default
    };

/// Einheitliche Schrittrichtung für Linien (eine der 8 Himmelsrichtungen).
class _DirStep {
  final int dr;
  final int dc;

  const _DirStep(this.dr, this.dc);

  bool get isDiagonal => dr != 0 && dc != 0;
}

/// Alle 8 Richtungen.
const List<_DirStep> _allDirections = [
  _DirStep(1, 0),
  _DirStep(-1, 0),
  _DirStep(0, 1),
  _DirStep(0, -1),
  _DirStep(1, 1),
  _DirStep(1, -1),
  _DirStep(-1, 1),
  _DirStep(-1, -1),
];

/// Richtungen, in denen Wörter platziert werden: easy/medium nur horizontal
/// und vertikal, hard zusätzlich diagonal (jeweils vor- und rückwärts).
List<_DirStep> _placementDirections(bool diagonal) => [
      const _DirStep(0, 1),
      const _DirStep(0, -1),
      const _DirStep(1, 0),
      const _DirStep(-1, 0),
      if (diagonal)
        ..._allDirections.where((d) => d.isDiagonal),
    ];

/// Erlaubt nur Einträge, die spielbar sind: status 'seen' (Level egal).
///
/// Wird nach dem Laden zusätzlich zu den Datenbank-Filtern angewendet, damit
/// NIE Wörter der Kategorie 0 (status 'new') ins Puzzle gelangen. Seit
/// Ticket #61 ist der Filter identisch zum Turbo-Spiel: jedes gelesene Wort
/// ist spielbar.
List<VocabEntry> _usableEntries(List<VocabEntry> entries) =>
    entries.where((e) => e.status == 'seen').toList();

List<String> _tokens(String word) =>
    word.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Normalisiert einen Roh-Grid-Begriff auf Großbuchstaben A-Z:
/// ä/ö/ü/ß werden zu AE/OE/UE/SS, alles andere außer a-z wird entfernt.
String normalizeGridWord(String raw) {
  final out = StringBuffer();
  final lowered = raw.toLowerCase();
  for (var i = 0; i < lowered.length; i++) {
    final ch = lowered[i];
    if (ch == 'ä') {
      out.write('AE');
    } else if (ch == 'ö') {
      out.write('OE');
    } else if (ch == 'ü') {
      out.write('UE');
    } else if (ch == 'ß') {
      out.write('SS');
    } else if (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122) {
      out.write(ch.toUpperCase());
    }
  }
  return out.toString();
}

/// Bekannte Pronomen von 2-Token-Konjugationen.
const Set<String> _pronouns = {
  'ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie',
  'i', 'you', 'he/she/it', 'we', 'they', 'he', 'she', 'it',
};

/// Hilfsverben des Futurs: danach folgt im 3-Token-Fall der Infinitiv
/// ("ich werde gehen", "I will go").
const Set<String> _futureHelpers = {
  'werde', 'wirst', 'wird', 'werden', 'werdet', 'will', 'shall',
};

/// Leitet den Such-Begriff (Infinitiv-Form) aus einem einzelnen Eintrag ab.
///
/// Grundregeln:
/// - Ein-Wort-Einträge (spätere Nomen/Adjektive) werden direkt verwendet.
/// - Konjugationen mit Pronomen liefern das letzte Token ("wir gehen" ->
///   "gehen", "ich werde gehen" -> "gehen").
/// - Umlaut-/ß-Normalisierung nach [normalizeGridWord].
///
/// Liefert null, wenn aus dem Eintrag kein spielbares Wort (>= 3 Buchstaben)
/// ableitbar ist.
String? deriveSearchWord(VocabEntry entry) {
  final tokens = _tokens(entry.word);
  if (tokens.isEmpty) return null;
  final gridWord =
      normalizeGridWord(tokens.length == 1 ? tokens.first : tokens.last);
  if (gridWord.length < 3) return null;
  return gridWord;
}

/// Punktwert, wie nah der abgeleitete Begriff am echten Infinitiv liegt.
///
/// Bevorzugt die wir/sie-Präsens-Form (entspricht dem Infinitiv), das letzte
/// Token des Futurs sowie Infinitive auf -en/-n. Höher = besser.
int _candidateScore(VocabEntry entry, String gridWord) {
  final tokens = _tokens(entry.word);
  final tense = vocabTenseKey(entry.key);
  final person = vocabPersonIndex(entry.key);
  var score = 0;

  if (gridWord.endsWith('EN')) {
    score += 3; // typische Infinitiv-Endung
  } else if (gridWord.length > 3 && gridWord.endsWith('N')) {
    score += 2; // z. B. sein, können
  }
  if (tokens.length >= 3 &&
      _futureHelpers.contains(tokens[tokens.length - 2])) {
    score += 2; // "ich werde gehen" -> letztes Token ist der Infinitiv
  }
  if (tokens.length == 2 &&
      _pronouns.contains(tokens.first) &&
      tense == 'present' &&
      (person == 3 || person == 5)) {
    score += 2; // wir/sie-Form ("wir gehen") entspricht dem Infinitiv
  }
  if (tokens.length == 1) {
    score += 1; // Ein-Wort-Eintrag: direkt verwenden (Fallback)
  }
  return score;
}

/// Baut die Kandidaten-Wörter für das Puzzle.
///
/// Gruppiert nach Verb ([vocabVerbKey]) und wählt je Verb den besten
/// Infinitiv-Kandidaten. Gleiche Infinitive (z. B. "wir gehen" und
/// "sie gehen") erscheinen nur einmal – mit der ersten gefundenen
/// Übersetzung.
List<WordSearchWord> _buildCandidates(List<VocabEntry> entries) {
  final byVerb = <String, List<VocabEntry>>{};
  for (final e in _usableEntries(entries)) {
    byVerb.putIfAbsent(vocabVerbKey(e.key), () => []).add(e);
  }

  final result = <WordSearchWord>[];
  for (final group in byVerb.values) {
    WordSearchWord? best;
    var bestScore = -1;
    for (final entry in group) {
      final gridWord = deriveSearchWord(entry);
      if (gridWord == null) continue;
      var score = _candidateScore(entry, gridWord);
      // Häufigkeits-Bonus: Formen, die denselben Kandidaten mehrfach liefern,
      // gewinnen bei Gleichstand.
      final frequency =
          group.where((o) => deriveSearchWord(o) == gridWord).length;
      if (frequency >= 2) score += 1;
      if (best != null && score <= bestScore) continue;
      best = WordSearchWord(
        word: gridWord,
        translation: entry.translation,
        cells: const <Point>[],
      );
      bestScore = score;
    }
    if (best != null) result.add(best);
  }
  return result;
}

/// Legt [word] ins Gitter oder gibt nach ca. 50 Fehlversuchen null zurück.
///
/// Wörter dürfen sich kreuzen, wenn der getroffene Buchstabe übereinstimmt;
/// belegte Zellen mit anderem Buchstaben führen zum Verwerfen des Versuchs.
List<Point>? _tryPlaceWord(
    List<List<String?>> grid, String word, List<_DirStep> dirs, Random rng) {
  final size = grid.length;
  for (var attempt = 0; attempt < 50; attempt++) {
    final dir = dirs[rng.nextInt(dirs.length)];
    final row = rng.nextInt(size);
    final col = rng.nextInt(size);
    var ok = true;
    final cells = <Point>[];
    for (var i = 0; i < word.length; i++) {
      final r = row + dir.dr * i;
      final c = col + dir.dc * i;
      if (r < 0 || r >= size || c < 0 || c >= size) {
        ok = false;
        break;
      }
      final existing = grid[r][c];
      if (existing != null && existing != word[i]) {
        ok = false;
        break;
      }
      cells.add(Point(r, c));
    }
    if (ok) {
      for (var i = 0; i < cells.length; i++) {
        grid[cells[i].row][cells[i].col] = word[i];
      }
      return cells;
    }
  }
  return null;
}

/// Erzeugt ein Wortsuch-Puzzle aus den Vokabel-Einträgen.
///
/// - easy:   8x8,  4 Wörter, horizontal + vertikal
/// - medium: 10x10, 6 Wörter, horizontal + vertikal
/// - hard:   12x12, 8 Wörter, zusätzlich diagonal (vor- und rückwärts)
///
/// Es werden NUR Einträge mit status 'seen' und level >= 1 verwendet
/// (siehe [_usableEntries]).
WordSearchPuzzle generatePuzzle(List<VocabEntry> entries, String difficulty) {
  final config = _configFor(difficulty);
  final rng = Random();
  final grid =
      List.generate(config.size, (_) => List<String?>.filled(config.size, null));

  final candidates = _buildCandidates(entries)
    ..removeWhere((w) => w.word.length > config.size)
    ..shuffle(rng);
  final dirs = _placementDirections(config.diagonal);
  final placed = <WordSearchWord>[];

  for (final candidate in candidates) {
    if (placed.length >= config.wordCount) break;
    final cells = _tryPlaceWord(grid, candidate.word, dirs, rng);
    if (cells == null) continue; // nach ca. 50 Fehlversuchen: Wort weglassen
    placed.add(WordSearchWord(
      word: candidate.word,
      translation: candidate.translation,
      cells: cells,
    ));
  }

  // Rest-Füllung mit zufälligen Buchstaben A-Z.
  const String letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final filled = grid
      .map((row) => row
          .map((c) => c ?? letters[rng.nextInt(letters.length)])
          .toList())
      .toList();

  return WordSearchPuzzle(grid: filled, words: placed);
}

/// Prüft, ob [path] als gerade Linie eine der 8 Richtungen ist (auch
/// rückwärts) und genau ein noch nicht gefundenes Wort ergibt.
///
/// Liefert das getroffene [WordSearchWord] oder null.
WordSearchWord? validatePath(List<Point> path, WordSearchPuzzle puzzle) {
  if (path.length < 2) return null;
  final first = path.first;
  final last = path.last;
  final dr = (last.row - first.row).sign;
  final dc = (last.col - first.col).sign;
  if (dr == 0 && dc == 0) return null;

  for (var i = 0; i < path.length; i++) {
    final p = path[i];
    if (p.row != first.row + dr * i || p.col != first.col + dc * i) {
      return null; // Knick oder Sprung im Pfad
    }
    if (p.row < 0 || p.row >= puzzle.size ||
        p.col < 0 || p.col >= puzzle.size) {
      return null; // außerhalb des Gitters
    }
  }

  final buffer = StringBuffer();
  for (final p in path) {
    buffer.write(puzzle.letterAt(p));
  }
  final found = buffer.toString();

  for (final word in puzzle.words) {
    if (word.found) continue;
    if (word.word == found || word.word == found.split('').reversed.join()) {
      return word;
    }
  }
  return null;
}

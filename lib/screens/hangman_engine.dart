import 'dart:math';

import '../models/app_models.dart';
import '../models/vocab_key.dart';
import 'word_search_engine.dart' show deriveSearchWord;

/// Hangman-Engine – pure Dart, OHNE Flutter-Imports.
///
/// Wiederverwendete Patterns (nicht neu erfunden):
/// - Wortdaten: [VocabEntry] aus `app_models.dart`.
/// - Infinitiv-Ableitung: `vocabVerbKey` (vocab_key.dart) fuer die
///   Verb-Gruppierung und `deriveSearchWord` (word_search_engine.dart, rein
///   pures Dart) fuer die Ableitung des gesuchten Infinitivs.
/// - Spielbare Woerter: ausschliesslich status 'seen' UND level >= 1;
///   Kategorie-0-Woerter (status 'new' / level 0) landen NIE in der Runde.
/// - Eine Runde besteht aus bis zu 5 Woertern, Hinweise je Schwierigkeit.

/// Ein zu ratendes Wort (normalisierter Infinitiv) samt Hinweis.
class HangmanWord {
  /// Gesuchtes Wort: normalisierter Infinitiv, Grossbuchstaben A-Z.
  final String target;

  /// Hinweis fuer den Spieler (je Schwierigkeit, siehe [buildHint]).
  final String hint;

  /// Bereits ausprobiertet Buchstaben (richtig ODER falsch), Grossbuchstaben.
  final List<String> guessed;

  HangmanWord({required this.target, required this.hint, List<String>? guessed})
      : guessed = guessed ?? <String>[];
}

/// Eine Spielrunde: bis zu 5 Woerter hintereinander, ohne Leben-Reset
/// zwischen den Woertern.
class HangmanRound {
  final List<HangmanWord> entries;

  /// Falsch geratene Buchstaben (ein Leben pro Eintrag).
  final List<String> wrongGuesses;

  /// Anzahl erlaubter Fehlversuche (Leben) zu Rundenbeginn.
  final int lives;

  /// Anzahl bereits vollstaendig geloester Woerter.
  int solvedCount;

  HangmanRound({
    required this.entries,
    required this.wrongGuesses,
    required this.lives,
    required this.solvedCount,
  });

  /// Noch verbleibende Leben.
  int get remainingLives => lives - wrongGuesses.length;

  /// Runde ist verloren, sobald alle Leben aufgebraucht sind.
  bool get lost => wrongGuesses.length >= lives;

  /// Anzahl Woerter, die in dieser Runde geloest werden muessen.
  int get targetWordCount => entries.length;
}

/// Erlaubte Fehlversuche je Schwierigkeit: easy 8, medium 6, hard 5.
int livesFor(String difficulty) => switch (difficulty) {
      'easy' => 8,
      'hard' => 5,
      _ => 6, // medium Default
    };

/// Erlaubt nur Eintraege, die spielbar sind: status 'seen' (Level egal).
///
/// Wird nach dem Laden zusaetzlich angewendet, damit NIE Woerter der
/// Kategorie 0 (status 'new') in die Runde gelangen. Seit Ticket #61 ist
/// der Filter identisch zum Turbo-Spiel: jedes gelesene Wort ist spielbar.
List<VocabEntry> _usableEntries(List<VocabEntry> entries) =>
    entries.where((e) => e.status == 'seen').toList();

/// Letztes Wort-Token eines Eintrags (die konjugierte Infinitiv-Form,
/// z. B. "gehen" aus "wir gehen", "gehe" aus "ich gehe").
String _verbExpression(String word) {
  final tokens =
      word.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  return tokens.isEmpty ? word.trim() : tokens.last;
}

/// Liefert den passenden Beispielsatz (per Person, sonst ersten nicht-leeren)
/// oder null, wenn keiner vorhanden ist.
String? _sentenceAt(List<String> list, int person) {
  if (person >= 0 && person < list.length) {
    final s = list[person].trim();
    if (s.isNotEmpty) return s;
  }
  for (final s in list) {
    final t = s.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

/// Naives Ersetzen des Zielwort-Ausdrucks im Satz durch eine Luecke aus
/// Unterstrichen (Laenge = Laenge des normalisierten Ziel-Infinitivs, sonst
/// Laenge des Ausdrucks).
///
/// Es wird der erste Treffer des [expression] (Gross-/Kleinschreibung egal,
/// ganze Wortgrenze) ersetzt. Liefert null, wenn der Ausdruck im Satz nicht
/// vorkommt (dann faellt der Aufrufer auf die Uebersetzung zurueck).
String? _gapSentence(String sentence, String expression, String? target) {
  final gapLen = target?.length ?? expression.length;
  final gap = '_' * gapLen;
  if (expression.isEmpty) return null;
  final pattern = RegExp(
    '(?<![a-zäöüß])${RegExp.escape(expression)}(?![a-zäöüß])',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(sentence);
  if (match == null) return null;
  return sentence.replaceRange(match.start, match.end, gap);
}

/// Fallback-Hinweis: die Uebersetzung (bzw. das Wort, falls leer).
String _translationHint(VocabEntry entry) =>
    entry.translation.trim().isEmpty ? entry.word : entry.translation;

/// Baut den Hinweis fuer einen Eintrag je Schwierigkeit:
/// - easy:   Uebersetzung (z. B. "I go").
/// - medium: deutscher Beispielsatz ([examplesNative]) mit Luecke an der
///           Stelle des Zielworts.
/// - hard:   Beispielsatz in der Zielsprache ([examples]) mit Luecke.
///
/// Falls kein Beispielsatz vorhanden ist (oder der Zielwort-Ausdruck im Satz
/// fehlt), wird automatisch auf den easy-Hinweis (Uebersetzung) ausgewichen.
String buildHint(VocabEntry entry, String difficulty) {
  final target = deriveSearchWord(entry);

  if (difficulty == 'medium' || difficulty == 'hard') {
    // medium: Muttersprachen-Beispielsatz (examplesNative) → der verbale
    //          Ausdruck kommt aus der Muttersprach-Uebersetzung
    //          (z. B. "wir arbeiten" → "arbeiten").
    // hard:   Zielsprachen-Beispielsatz (examples) → der verbale Ausdruck
    //          kommt aus dem Zielsprach-Wort (z. B. "we work" → "work").
    final expression = _verbExpression(
        difficulty == 'hard' ? entry.word : entry.translation);
    final sentences =
        difficulty == 'hard' ? entry.examples : entry.examplesNative;
    final sentence = _sentenceAt(sentences, vocabPersonIndex(entry.key));
    final gapped = sentence == null
        ? null
        : _gapSentence(sentence, expression, target);
    if (gapped != null) return gapped;
  }

  return _translationHint(entry);
}

/// Waehlt fuer eine Verbgruppe den besten Infinitiv-Kandidaten samt Eintrag.
///
/// Der Infinitiv ist die haeufigste Form (wir/sie-Formen liefern denselben
/// Kandidaten wie "gehen"); bei Gleichstand gewinnt die laengere Form.
({String word, VocabEntry entry})? _pickInfinitive(List<VocabEntry> group) {
  ({String word, VocabEntry entry})? best;
  var bestCount = 0;
  for (final entry in group) {
    final word = deriveSearchWord(entry);
    if (word == null) continue;
    final count = group.where((o) => deriveSearchWord(o) == word).length;
    if (best == null ||
        count > bestCount ||
        (count == bestCount && word.length > best.word.length)) {
      best = (word: word, entry: entry);
      bestCount = count;
    }
  }
  return best;
}

/// Erzeugt eine Hangman-Runde (max. 5 Woerter) aus den [entries].
///
/// Es werden NUR Eintraege mit status 'seen' und level >= 1 verwendet
/// (Puzzle-Garantie in [_usableEntries]); Infinitive sind dedupliziert.
/// Die Runde startet mit 0 falschen Buchstaben und [livesFor] Leben.
HangmanRound createRound(List<VocabEntry> entries, String difficulty) {
  final byVerb = <String, List<VocabEntry>>{};
  for (final e in _usableEntries(entries)) {
    byVerb.putIfAbsent(vocabVerbKey(e.key), () => []).add(e);
  }

  final words = <HangmanWord>[];
  final seen = <String>{};
  for (final group in byVerb.values) {
    final best = _pickInfinitive(group);
    if (best == null) continue;
    if (!seen.add(best.word)) continue; // gleicher Infinitiv nur einmal
    words.add(HangmanWord(
      target: best.word,
      hint: buildHint(best.entry, difficulty),
    ));
  }

  words.shuffle(Random());
  return HangmanRound(
    entries: words.take(5).toList(),
    wrongGuesses: <String>[],
    lives: livesFor(difficulty),
    solvedCount: 0,
  );
}

/// Ratet [letter] fuer [word] (idempotent): fuegt den Buchstaben zu
/// `guessed` hinzu und liefert true, wenn er im Zielwort vorkommt.
///
/// Bereits geratene Buchstaben liefern false und aendern nichts.
bool guessLetter(HangmanWord word, String letter) {
  final l = letter.trim().toUpperCase();
  if (l.length != 1) return false;
  if (word.guessed.contains(l)) return false;
  word.guessed.add(l);
  return word.target.contains(l);
}

/// True, sobald alle Buchstaben des Wortes aufgedeckt sind.
bool isWordSolved(HangmanWord word) {
  final unique = <String>{...word.target.split('')};
  return unique.every(word.guessed.contains);
}

/// True, sobald die Runde vorbei ist (verloren ODER alle Woerter geloest).
bool isRoundOver(HangmanRound round) =>
    round.lost || round.solvedCount >= round.targetWordCount;

/// Liefert das Wort mit '_' fuer noch nicht aufgedeckte Buchstaben.
String revealedWord(HangmanWord word) => word.target
    .split('')
    .map((c) => word.guessed.contains(c) ? c : '_')
    .join();
import 'dart:math';

import '../models/app_models.dart';
import '../models/vocab_key.dart';

/// Fill-In-Engine – pure Dart, OHNE Flutter-Imports.
///
/// Wiederverwendete Patterns (nicht neu erfunden):
/// - Wortdaten: [VocabEntry] aus `app_models.dart`.
/// - Verbform-Ableitung: Der Gesucht-Ausdruck ist der Teil NACH dem Pronomen
///   der Konjugation (z. B. "gehe" aus "ich gehe", "gehen" aus
///   "ich werde gehen") - dieselbe Token-Logik wie in der Hangman-Engine.
/// - Spielbare Woerter: ausschliesslich status 'seen' UND level >= 1;
///   Kategorie-0-Woerter (status 'new' / level 0) landen NIE in der Runde.
/// - Eine Runde besteht aus Sätzen je Schwierigkeit (easy 25, medium 50,
///   hard 100), gedeckelt auf die verfuegbare Woerterzahl.

/// Anzahl Saetze je Schwierigkeit: easy 25, medium 50, hard 100.
int sentenceCountFor(String difficulty) => switch (difficulty) {
      'easy' => 25,
      'hard' => 100,
      _ => 50, // medium Default
    };

/// Ein einzelner Luecken-Satz der Fill-In-Runde.
class FillInItem {
  /// Beispielsatz in der Zielsprache, die Verbform durch Unterstriche ersetzt
  /// (Laenge der Unterstriche = Laenge der Loesung).
  final String sentence;

  /// Deutscher (Muttersprach-)Satz als zweite Hinweiszeile (leer moeglich).
  final String sentenceNative;

  /// Gesuchte Verbform (Teil nach dem Pronomen aus `entry.word`).
  final String solution;

  /// True, sobald dieser Satz korrekt geloest wurde (zahlt 1 Punkt).
  bool score;

  /// Anzahl abgegebener Versuche ([checkAnswer]-Aufrufe).
  int tries;

  /// Erster Buchstabe wurde nach 2 Fehlversuchen aufgedeckt (einmalig).
  bool hintShown;

  FillInItem({
    required this.sentence,
    required this.sentenceNative,
    required this.solution,
    this.score = false,
    this.tries = 0,
    this.hintShown = false,
  });
}

/// Eine Spielrunde: alle gereihten Saetze, aktueller Index, Punkte und
/// Startzeitpunkt (wird vom Screen beim Stoppuhr-Start gesetzt).
class FillInRound {
  final List<FillInItem> items;

  /// Zeigt auf den naechsten abzuarbeitenden Satz.
  int index;

  /// Punkte (Anzahl korrekt geloester Saetze).
  int score;

  /// Startzeitpunkt der Runde in Millisekunden bzw. null vor Spielbeginn.
  int? startTimeMs;

  FillInRound({
    required this.items,
    this.index = 0,
    this.score = 0,
    this.startTimeMs,
  });
}

/// Verbform-Ableitung: letztes Wort-Token der Konjugation (Teil NACH dem
/// Pronomen), z. B. "gehe" aus "ich gehe", "gehen" aus "ich werde gehen".
String _verbForm(String word) {
  final tokens =
      word.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  return tokens.isEmpty ? word.trim() : tokens.last;
}

/// Liefert den Satz an Position [person] (falls vorhanden und nicht leer),
/// sonst den ersten nicht-leeren Satz der Liste, sonst null.
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

/// Naives Ersetzen der Verbform im Satz durch Unterstriche (case-insensitiv,
/// ganze Wortgrenze, erste Fundstelle). Die Laenge der Unterstriche entspricht
/// der Laenge der Loesung. Liefert null, wenn die Verbform nicht vorkommt.
String? _gapSentence(String sentence, String expression) {
  if (expression.isEmpty) return null;
  final pattern = RegExp(
    '(?<![a-zäöüß])${RegExp.escape(expression)}(?![a-zäöüß])',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(sentence);
  if (match == null) return null;
  return sentence.replaceRange(match.start, match.end, '_' * expression.length);
}

/// Baut ein Luecken-Item aus einem Vokabel-Eintrag.
///
/// Loesung = Verbform aus `entry.word` (Teil nach dem Pronomen, z. B.
/// "gehe"). Der Beispielsatz (Zielsprache, `entry.examples`) wird an der
/// Verbform geoeffnet; der Muttersprach-Satz (`entry.examplesNative`) dient
/// als zweite Hinweiszeile.
///
/// Rueckfallebene: Wenn kein Beispielsatz vorhanden ist (oder die Verbform
/// nicht im Satz vorkommt), wird nur "translation: ___" ohne Satz gezeigt.
FillInItem buildItem(VocabEntry entry) {
  final solution = _verbForm(entry.word);
  final person = vocabPersonIndex(entry.key);
  final example = _sentenceAt(entry.examples, person);
  final gapped = example == null ? null : _gapSentence(example, solution);
  if (gapped != null) {
    return FillInItem(
      sentence: gapped,
      sentenceNative: _sentenceAt(entry.examplesNative, person) ?? '',
      solution: solution,
    );
  }
  return FillInItem(
    sentence: 'translation: ${'_' * solution.length}',
    sentenceNative: '',
    solution: solution,
  );
}

/// Erlaubt nur Eintraege, die spielbar sind: status 'seen' (Level egal).
///
/// Wird nach dem Laden zusaetzlich angewendet, damit NIE Woerter der
/// Kategorie 0 (status 'new') in die Runde gelangen. Seit Ticket #61 ist
/// der Filter identisch zum Turbo-Spiel: jedes gelesene Wort ist spielbar.
List<VocabEntry> _usableEntries(List<VocabEntry> entries) =>
    entries.where((e) => e.status == 'seen').toList();

/// Erzeugt eine Fill-In-Runde aus den [entries].
///
/// - Zufaellige Auswahl OHNE Wiederholung (shuffle + take).
/// - Satzahl je Schwierigkeit ([sentenceCountFor]), gedeckelt auf die
///   tatsaechlich verfuegbare Woerterzahl.
/// - NUR Eintraege mit status 'seen' und level >= 1 (Runden-Garantie).
FillInRound createRound(List<VocabEntry> entries, String difficulty) {
  final usable = _usableEntries(entries)..shuffle(Random());
  final target = min(sentenceCountFor(difficulty), usable.length);
  return FillInRound(
    items: [for (final e in usable.take(target)) buildItem(e)],
  );
}

/// Prueft die Eingabe gegen die Loesung (lowercase + trim).
///
/// Zahlt jeden Versuch ([FillInItem.tries]). Bei Richtig wird der Satz als
/// geloest markiert; nach 2 Fehlversuchen wird einmalig der erste Buchstabe
/// als Tipp freigegeben ([FillInItem.hintShown]).
bool checkAnswer(FillInItem item, String input) {
  item.tries++;
  final correct =
      input.trim().toLowerCase() == item.solution.trim().toLowerCase();
  if (correct) {
    item.score = true;
  } else if (item.tries >= 2 && !item.hintShown) {
    item.hintShown = true; // Tipp-Leak nach 2 terminierten Versuchen
  }
  return correct;
}

/// Runde ist vorbei, sobald alle gereihten Saetze abgearbeitet sind
/// (geloest ODER geskippt).
bool isRoundOver(FillInRound round) => round.index >= round.items.length;

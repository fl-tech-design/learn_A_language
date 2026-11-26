import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';

import 'helpers/fakes.dart';

/// Diagnose-Test (Ticket #73): Beurteilt, ob `getReadWords` für die
/// Sprachpaket-Sprachen `el`/`ru` korrekt gelesene ('seen') Wörter liefert.
///
/// Hintergrund des Tickets: „In Griechisch (A1) und Russisch (A1) zeigen die
/// Spiele … Keine gelesenen Wörter zum spielen", obwohl mehr als 10 Wörter
/// gelesen wurden. Das Ticket vermutet als Ursache 1, dass der Status
/// „gelesen" in den betroffenen Sprachdatensätzen nicht als `'seen'`
/// gespeichert wird.
///
/// Diese Diagnose prüft die Getter-Schicht selbst: `getReadWords` soll bei
/// gesetzten `'seen'`-Einträgen unabhängig vom Sprachcode zurückliefern.
/// Sie bestätigt damit, ob die Ursache im Getter liegt (→ dann Reparatur hier)
/// oder woanders (Daten-/Schreibpfad), ohne in `lib/` zu raten.
void main() {
  VocabEntry seenVocab(String key) => VocabEntry(
        key: key,
        word: key,
        translation: key,
        examples: const [],
        examplesNative: const [],
        level: 1,
        status: 'seen',
      );

  VocabEntry newVocab(String key) => VocabEntry(
        key: key,
        word: key,
        translation: key,
        examples: const [],
        examplesNative: const [],
      );

  /// EgeruserData mit getrennten Sprach-Buckets (wie es die App für Kurse
  /// mehrerer Sprachen anlegt).
  UserData userDataWithLangs(Map<String, Map<String, VocabEntry>> langs) =>
      UserData(
        uName: 'alice',
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        vocabByLang: langs,
      );

  test('getReadWords liefert seen-Wörter auch für el (Griechisch)', () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
        'el': {
          'el_verb_present_0': seenVocab('el_verb_present_0'),
          'el_verb_present_1': seenVocab('el_verb_present_1'),
          'el_verb_present_2': newVocab('el_verb_present_2'),
        },
      }));

    final q = VocabQueriesImpl(fake);
    final read = await q.getReadWords('alice', langCode: 'el');

    // 2 von 3 sind 'seen' → dürfen zurückkommen; die 'new'-Zeile nicht.
    expect(read.length, 2);
  });

  test('getReadWords liefert seen-Wörter auch für ru (Russisch)', () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
        'ru': {
          'ru_verb_present_0': seenVocab('ru_verb_present_0'),
          'ru_verb_present_1': newVocab('ru_verb_present_1'),
        },
      }));

    final q = VocabQueriesImpl(fake);
    final read = await q.getReadWords('alice', langCode: 'ru');

    expect(read.length, 1);
    expect(read.single.key, 'ru_verb_present_0');
  });

  test('getReadWords grenzt Sprachen gegeneinander ab (bucket-getrennt)',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
        'de': {'de_a': seenVocab('de_a')},
        'el': {'el_a': seenVocab('el_a')},
      }));

    final q = VocabQueriesImpl(fake);

    expect((await q.getReadWords('alice', langCode: 'el')).single.key, 'el_a');
    expect((await q.getReadWords('alice')).single.key, 'de_a');
  });
}
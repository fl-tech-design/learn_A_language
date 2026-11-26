import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';

import 'helpers/fakes.dart';

/// Diagnose-Test (Ticket #74): Belegt den SCHREIBPFAD „gelesen“ für die
/// Sprachpaket-Sprachen `el` (Griechisch) und `ru` (Russisch).
///
/// Ticket #73 hat die Getter-Seite repariert und per
/// `ticket73_diagnose_test.dart` bewiesen, dass `getReadWords` für
/// 'el'/'ru' korrekt `'seen'`-Wörter liefert, SOFERN sie im Bucket liegen.
/// Ticket #74 vermutet die Ursache vorgelagert: Im Fortschritts-Bucket
/// `userData.vocabByLang['el']` / `['ru']` fehlten die `status == 'seen'`-
/// Einträge („werden nie angelegt bzw. markiert“).
///
/// Dieser Test prüft genau diesen Schreibpfad:
/// - `checkWordAnswer` wird so aufgerufen wie der Word-Screen beim „Lesen“
///   (`word_screen.dart _onRead`: `userInput = word.translation`, `langCode`
///   = Kurssprache) – erwartet wird `status 'seen'` + Level 1 im RICHTIGEN
///   Bucket.
/// - sowie der Due-Word-Pfad (falsche Antwort → ebenfalls `'seen'` + Level 1).
/// - Am Ende eine End-to-End-Diagnose: Nach dem Schreiben muss
///   `getReadWords` die gelesenen Wörter für 'el'/'ru' zurückgeben.
void main() {
  /// Wort, wie es `initVocabForUser` anlegt: Level 0, Status 'new'.
  VocabEntry newVocab(String key) => VocabEntry(
        key: key,
        word: key,
        translation: key,
        examples: const [],
        examplesNative: const [],
      );

  /// UserData mit getrennten Sprach-Buckets (wie die App für Kurse
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

  test('checkWordAnswer schreibt gelesene Wörter als seen in den el-Bucket',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
            'el': {
              'el_verb_present_0': newVocab('el_verb_present_0'),
              'el_verb_present_1': newVocab('el_verb_present_1'),
            },
          }));

    final q = VocabQueriesImpl(fake);
    // „Lesen“ wie word_screen._onRead: userInput == translation.
    final result = await q.checkWordAnswer(
        'alice', 'el_verb_present_0', 'el_verb_present_0',
        langCode: 'el');

    expect(result.correct, isTrue);
    expect(result.statusChanged, isTrue);

    final saved = fake.getUser('alice')!;
    final el = saved.vocabByLang['el']!;
    expect(el['el_verb_present_0']!.status, 'seen');
    expect(el['el_verb_present_0']!.level, 1);
    // Ungelesenes Wort bleibt unverändert 'new'/Level 0.
    expect(el['el_verb_present_1']!.status, 'new');
    expect(el['el_verb_present_1']!.level, 0);
  });

  test('checkWordAnswer schreibt gelesene Wörter als seen in den ru-Bucket',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
            'ru': {'ru_verb_present_0': newVocab('ru_verb_present_0')},
          }));

    final q = VocabQueriesImpl(fake);
    final result = await q.checkWordAnswer(
        'alice', 'ru_verb_present_0', 'ru_verb_present_0',
        langCode: 'ru');

    expect(result.correct, isTrue);

    final saved = fake.getUser('alice')!;
    final ru = saved.vocabByLang['ru']!;
    expect(ru['ru_verb_present_0']!.status, 'seen');
    expect(ru['ru_verb_present_0']!.level, 1);
  });

  test('falsche Antwort setzt in el ebenfalls status seen (due-Pfad)',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
            'el': {'el_verb_present_2': newVocab('el_verb_present_2')},
          }));

    final q = VocabQueriesImpl(fake);
    final result = await q.checkWordAnswer(
        'alice', 'el_verb_present_2', '', langCode: 'el');

    expect(result.correct, isFalse);

    final saved = fake.getUser('alice')!;
    final el = saved.vocabByLang['el']!;
    expect(el['el_verb_present_2']!.status, 'seen');
    expect(el['el_verb_present_2']!.level, 1);
  });

  test('Schreiben in el bleibt bucket-getrennt (kein Kreuz-Schreiben nach de)',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
            'de': {'de_verb_present_0': newVocab('de_verb_present_0')},
            'el': {'el_verb_present_0': newVocab('el_verb_present_0')},
          }));

    final q = VocabQueriesImpl(fake);
    await q.checkWordAnswer(
        'alice', 'el_verb_present_0', 'el_verb_present_0', langCode: 'el');

    final saved = fake.getUser('alice')!;
    expect(saved.vocabByLang['el']!['el_verb_present_0']!.status, 'seen');
    // de-Bucket bleibt unangetastet.
    expect(saved.vocabByLang['de']!['de_verb_present_0']!.status, 'new');
    expect(saved.vocabByLang['de']!['de_verb_present_0']!.level, 0);
  });

  test('End-to-End: nach dem Lesen liefert getReadWords el- und ru-Wörter',
      () async {
    final fake = FakeUserManager()
      ..seed('alice', userDataWithLangs({
            'el': {
              'el_verb_present_0': newVocab('el_verb_present_0'),
              'el_verb_present_1': newVocab('el_verb_present_1'),
              'el_verb_present_2': newVocab('el_verb_present_2'),
            },
            'ru': {'ru_verb_present_0': newVocab('ru_verb_present_0')},
          }));

    final q = VocabQueriesImpl(fake);
    for (var i = 0; i < 3; i++) {
      await q.checkWordAnswer('alice', 'el_verb_present_$i',
          'el_verb_present_$i', langCode: 'el');
    }
    await q.checkWordAnswer(
        'alice', 'ru_verb_present_0', 'ru_verb_present_0', langCode: 'ru');

    final readEl = await q.getReadWords('alice', langCode: 'el');
    final readRu = await q.getReadWords('alice', langCode: 'ru');

    expect(readEl.length, 3);
    expect(readRu.length, 1);
  });
}

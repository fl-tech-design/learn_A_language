import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';

import 'helpers/fakes.dart';

UserData _userData(String username, Map<String, VocabEntry> vocab,
        {DayStreak? dayStreak}) =>
    UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocab: vocab,
      dayStreak: dayStreak,
    );

VocabEntry _vocab(
  String key, {
  int level = 0,
  String status = 'new',
  String? reviewDue,
  String? translation,
}) =>
    VocabEntry(
      key: key,
      word: key,
      translation: translation ?? key,
      examples: const [],
      examplesNative: const [],
      level: level,
      status: status,
      reviewDue: reviewDue,
    );

void main() {
  group('checkWordAnswer – Persistenz-Fehler', () {
    test('Schreibfehler liefert persistenceFailed statt Exception (kein Crash)',
        () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager(failSaveUsers: {'alice'});
      um.seed('alice', _userData('alice', {'w': _vocab('w', translation: 'w')}));
      final q = VocabQueriesImpl(um);

      final result = await q.checkWordAnswer('alice', 'w', 'w');

      // Antwort wird ausgewertet, aber Fortschritt nicht persistiert …
      expect(result.correct, isTrue);
      expect(result.persistenceFailed, isTrue);
      // … und einmalig gemeldet.
      expect(StorageErrorBus.instance.takeLast(),
          StorageErrorKind.progressNotSaved);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });

    test('ohne Fehler kein persistenceFailed', () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager();
      um.seed('alice', _userData('alice', {'w': _vocab('w', translation: 'w')}));
      final q = VocabQueriesImpl(um);

      final result = await q.checkWordAnswer('alice', 'w', 'w');

      expect(result.correct, isTrue);
      expect(result.persistenceFailed, isFalse);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });
  });

  group('getDueWords', () {
    test('filtert nach level, status und reviewDue', () async {
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'mastered': _vocab('mastered', level: 8, status: 'seen'),
          'unseen': _vocab('unseen'),
          'due_past': _vocab(
            'due_past',
            level: 1,
            status: 'seen',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ),
          'broken_due': _vocab('broken_due', level: 1, status: 'seen',
              reviewDue: 'kaputt'),
          'due_future': _vocab(
            'due_future',
            level: 1,
            status: 'seen',
            reviewDue: fmt(now.add(const Duration(days: 1))),
          ),
          'no_due': _vocab('no_due', level: 1, status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result = await queries.getDueWords('alice');

      expect(result, isA<List<VocabEntry>>());
      expect(
        result.map((e) => e.key).toSet(),
        {'due_past', 'broken_due', 'no_due'},
      );
    });
  });

  group('getNewWords + Paging + Count', () {
    test('sliced neue Wörter korrekt, zählt sie und filtert nach Level',
        () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          for (var i = 1; i <= 5; i++) 'new_$i': _vocab('new_$i'),
          'seen_1': _vocab('seen_1', status: 'seen'),
          'seen_2': _vocab('seen_2', status: 'seen'),
          'lvl3': _vocab('lvl3', level: 3, status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      final page0 = await queries.getNewWords('alice', limit: 2);
      final page2 = await queries.getNewWords('alice', limit: 2, offset: 2);
      final page4 = await queries.getNewWords('alice', limit: 2, offset: 4);

      expect(page0, isA<List<VocabEntry>>());
      expect(page0.length, 2);
      expect(page2.length, 2);
      expect(page4.length, 1);

      expect(await queries.getNewWordsCount('alice'), 5);

      final byLevel = await queries.getWordsByLevel('alice', 3);
      expect(byLevel, isA<List<VocabEntry>>());
      expect(byLevel.map((e) => e.key), ['lvl3']);
    });
  });

  group('getDayStreak + updateDayStreak', () {
    test('Default, Increment, no-op und Reset', () async {
      final now = DateTime.now();
      final fake = FakeUserManager();
      final queries = VocabQueriesImpl(fake);

      fake.seed('alice', _userData('alice', {}));
      final streak = await queries.getDayStreak('alice');
      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.lastDate, '');

      fake.seed(
        'alice',
        _userData('alice', {},
            dayStreak: DayStreak(
              current: 3,
              longest: 3,
              lastDate: fmt(now.subtract(const Duration(days: 1))),
            )),
      );
      await queries.updateDayStreak('alice');
      var saved = fake.lastSaved!;
      expect(saved.dayStreak!.current, 4);
      expect(saved.dayStreak!.longest, 4);
      expect(saved.dayStreak!.lastDate, fmt(now));

      final saveCountBefore = fake.saveCount;
      fake.seed(
        'alice',
        _userData('alice', {},
            dayStreak: DayStreak(current: 5, longest: 5, lastDate: fmt(now))),
      );
      await queries.updateDayStreak('alice');
      expect(fake.saveCount, saveCountBefore);

      fake.seed(
        'alice',
        _userData('alice', {},
            dayStreak:
                const DayStreak(current: 7, longest: 9, lastDate: '2000-01-01')),
      );
      await queries.updateDayStreak('alice');
      saved = fake.lastSaved!;
      expect(saved.dayStreak!.current, 1);
      expect(saved.dayStreak!.longest, 9);
      expect(saved.dayStreak!.lastDate, fmt(now));
    });
  });

  group('checkWordAnswer – korrekt', () {
    test('akzeptiert Whitespace/Case und persistiert neuen Level', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus', level: 3, translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result =
          await queries.checkWordAnswer('alice', 'haus', '  HAUS  ');

      expect(result.correct, true);
      expect(result.newLevel, greaterThan(3));
      expect(result.statusChanged, true);

      final saved = fake.lastSaved!;
      expect(saved.vocabByLang['de']!['haus']!.level, result.newLevel);
      expect(saved.vocabByLang['de']!['haus']!.status, 'seen');
    });

    test('bereits gesehenes Wort meldet statusChanged false', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus',
              level: 3, status: 'seen', translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result =
          await queries.checkWordAnswer('alice', 'haus', 'haus');

      expect(result.correct, true);
      expect(result.statusChanged, false);
      expect(fake.lastSaved!.vocabByLang['de']!['haus']!.status, 'seen');
    });

    test('Level 7 → 8: gelernt-Meldung und reviewDue wird geleert', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus',
              level: 7, status: 'seen', translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result =
          await queries.checkWordAnswer('alice', 'haus', 'haus');

      expect(result.correct, true);
      expect(result.newLevel, 8);
      expect(result.message, contains('Ausgezeichnet'));
      expect(result.statusChanged, false);

      final saved = fake.lastSaved!;
      expect(saved.vocabByLang['de']!['haus']!.level, 8);
      expect(saved.vocabByLang['de']!['haus']!.reviewDue, isNull);
    });

    test('Level 8 bleibt 8 und defektes Level 9 wird als gelernt gekappt',
        () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'learned': _vocab('learned',
              level: 8, status: 'seen', translation: 'gelernt'),
          'corrupt9': _vocab('corrupt9',
              level: 9, status: 'seen', translation: 'kaputt'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      final r8 = await queries.checkWordAnswer('alice', 'learned', 'gelernt');
      expect(r8.correct, true);
      expect(r8.newLevel, 8);
      expect(r8.message, contains('Ausgezeichnet'));
      final saved8 = fake.lastSaved!.vocabByLang['de']!['learned']!;
      expect(saved8.level, 8);
      expect(saved8.reviewDue, isNull);

      final r9 = await queries.checkWordAnswer('alice', 'corrupt9', 'kaputt');
      expect(r9.correct, true);
      expect(r9.newLevel, 8);
      final saved9 = fake.lastSaved!.vocabByLang['de']!['corrupt9']!;
      expect(saved9.level, 8);
      expect(saved9.reviewDue, isNull);
    });
  });

  group('checkWordAnswer – falsch / unbekannt', () {
    test('falsche Antwort: Zurueck auf LV1 (in Arbeit), nicht LV0 - kein Save bei unbekanntem Wort',
        () async {
      final fake = FakeUserManager();
      final now = DateTime.now();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus',
              level: 5,
              status: 'seen',
              translation: 'Haus',
              reviewDue: fmt(now.subtract(const Duration(days: 1)))),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      // Vor der falschen Antwort: faellig (in Arbeit), kein neues Wort.
      expect(await queries.getWordsDueCount('alice'), 1);
      expect(await queries.getNewWordsCount('alice'), 0);

      final wrong = await queries.checkWordAnswer('alice', 'haus', 'dog');
      expect(wrong.correct, false);
      // LV0 heisst „noch nie gelesen" – ein falsches Wort faellt auf den
      // Lernanfang LV1 zurueck und bleibt „in Arbeit" (nicht neu).
      expect(wrong.newLevel, 1);
      final savedEntry = fake.lastSaved!.vocabByLang['de']!['haus']!;
      expect(savedEntry.level, 1);
      expect(savedEntry.status, 'seen');
      final reviewDue = savedEntry.reviewDue;
      expect(reviewDue, isNotNull);
      // reviewDue ist morgen -> das Wort wird wieder faellig.
      expect(DateTime.parse(reviewDue!).isAfter(now), true);

      // Weder als neues (nie gesehenes) Wort gelistet noch jetzt faellig.
      expect(await queries.getNewWordsCount('alice'), 0);
      expect(await queries.getWordsDueCount('alice'), 0);

      final savedBefore = fake.lastSaved;
      final saveCountBefore = fake.saveCount;
      final notFound =
          await queries.checkWordAnswer('alice', 'gibtEsNicht', 'x');
      expect(notFound.correct, false);
      expect(notFound.message, 'Wort nicht gefunden');
      expect(fake.saveCount, saveCountBefore);
      expect(identical(fake.lastSaved, savedBefore), true);
    });
  });

  group('checkWordAnswer + getWordsDueCount kombiniert', () {
    test('korrekt beantwortetes fälliges Wort ist danach nicht mehr fällig',
        () async {
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'due': _vocab(
            'due',
            level: 1,
            status: 'seen',
            translation: 'Haus',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ),
        }),
      );
      final queries = VocabQueriesImpl(fake);

      expect(await queries.getWordsDueCount('alice'), 1);

      final result =
          await queries.checkWordAnswer('alice', 'due', '  HAUS  ');
      expect(result.correct, true);

      final saved = fake.lastSaved!;
      final reviewDue = saved.vocabByLang['de']!['due']!.reviewDue;
      expect(reviewDue, isNotNull);
      expect(DateTime.parse(reviewDue!).isAfter(now), true);

      expect(await queries.getWordsDueCount('alice'), 0);
    });
  });

  group('getAllWords / getReadWords / getLearnedWords / getNewWordsCount', () {
    test('liefert alle, nur gesehene, Level-8 und zählt neue Wörter', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'new1': _vocab('new1'),
          'seen1': _vocab('seen1', status: 'seen'),
          'seen2': _vocab('seen2', status: 'seen'),
          'done1': _vocab('done1', level: 8, status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      expect((await queries.getAllWords('alice')).length, 4);
      // Gelesene = alles schon Angeschaute (inkl. Level 8).
      expect((await queries.getReadWords('alice')).map((e) => e.key),
          ['seen1', 'seen2', 'done1']);
      // Gelernte = nur fertig gelernt (Level 8).
      expect((await queries.getLearnedWords('alice')).map((e) => e.key),
          ['done1']);
      expect(await queries.getNewWordsCount('alice'), 1);
    });

    test('unbekannter Benutzer liefert leere Listen und 0', () async {
      final queries = VocabQueriesImpl(FakeUserManager());

      expect(await queries.getDueWords('ghost'), isEmpty);
      expect(await queries.getNewWords('ghost'), isEmpty);
      expect(await queries.getWordsDueCount('ghost'), 0);
    });
  });

  group('getGroupWords + Kategorie-Helfer', () {
    test('filtert nach Kategorie und sortiert nach Verb/Zeitform/Person',
        () async {
      const cat = WordCategory(
        id: 'test',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be', 'to_have'],
      );
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_have_present_1': _vocab('to_have_present_1'),
          'to_be_present_0': _vocab('to_be_present_0'),
          'other_past_0': _vocab('other_past_0'),
          'to_be_past_0': _vocab('to_be_past_0'),
          'to_be_present_5': _vocab('to_be_present_5'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result = await queries.getGroupWords('alice', cat);

      expect(
        result.map((e) => e.key),
        ['to_be_past_0', 'to_be_present_0', 'to_be_present_5', 'to_have_present_1'],
      );
    });

    test('courseWordCategories deckt alle 30 Verben genau einmal ab', () {
      final counts = <String, int>{};
      for (final c in courseWordCategories) {
        for (final v in c.verbKeys) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
      }
      expect(counts.length, 30);
      expect(counts.values.where((n) => n == 1).length, 30);
    });

    test('courseWordCollections: Erste Verben + Weitere Verben mit 5 Gruppen',
        () {
      expect(courseWordCollections.length, 2);

      final erste = courseWordCollections
          .firstWhere((c) => c.id == 'erste_verben');
      expect(erste.categories.length, 1);
      expect(
        erste.categories.first.verbKeys,
        ['to_can', 'to_want', 'to_should', 'to_be_allowed_to', 'to_must'],
      );

      final weitere = courseWordCollections
          .firstWhere((c) => c.id == 'weitere_verben');
      expect(weitere.categories.length, 5);

      // Alle 30 Verben genau einmal über beide Sammlungen, 5 Gruppen à 5.
      final all = <String>[];
      for (final col in courseWordCollections) {
        for (final c in col.categories) {
          expect(c.verbKeys.length, 5);
          all.addAll(c.verbKeys);
        }
      }
      expect(all.length, 30);
      expect(all.toSet().length, 30);
    });

    test('containsEntryKey + Key-Helfer', () {
      final cat = courseWordCategories.firstWhere((c) => c.id == 'erste_verben');
      expect(cat.containsEntryKey('to_can_present_0'), true);
      expect(cat.containsEntryKey('to_must_present_0'), true);
      expect(cat.containsEntryKey('to_be_allowed_to_present_0'), true);
      expect(cat.containsEntryKey('to_be_present_0'), false);

      expect(vocabVerbKey('to_be_allowed_to_present_0'), 'to_be_allowed_to');
      expect(vocabTenseKey('to_be_allowed_to_present_0'), 'present');
      expect(vocabPersonIndex('to_be_present_3'), 3);
      expect(vocabTenseOrder('past'), 0);
      expect(vocabTenseOrder('present'), 1);
      expect(vocabTenseOrder('future'), 2);
    });

    test('getGroupNewWords filtert Level 0 pro Kategorie + Paging', () async {
      const cat = WordCategory(
        id: 'test2',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be', 'to_have'],
      );
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0': _vocab('to_be_present_0'),
          'to_have_present_0': _vocab('to_have_present_0'),
          'to_can_present_0': _vocab('to_can_present_0'),
          'to_be_past_0': _vocab('to_be_past_0', status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final all = await queries.getGroupNewWords('alice', cat);
      expect(
        all.map((e) => e.key).toSet(),
        {'to_be_present_0', 'to_have_present_0'},
      );

      final page = await queries.getGroupNewWords('alice', cat,
          limit: 1, offset: 1);
      expect(page.length, 1);
    });

    test('getGroupLearnWords liefert zuerst fällige, dann neue', () async {
      const cat = WordCategory(
        id: 'test3',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be'],
      );
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0': _vocab('to_be_present_0'),
          'to_be_past_0': _vocab(
            'to_be_past_0',
            level: 2,
            status: 'seen',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ),
          'to_be_past_1': _vocab('to_be_past_1', level: 8, status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final learn = await queries.getGroupLearnWords('alice', cat);
      expect(learn.map((e) => e.key), ['to_be_past_0', 'to_be_present_0']);
    });

    test('getGroupDueWords filtert fällige Wörter pro Kategorie', () async {
      const cat = WordCategory(
        id: 'test4',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be', 'to_have'],
      );
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_past_0': _vocab(
            'to_be_past_0',
            level: 1,
            status: 'seen',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ),
          'to_have_present_0': _vocab(
            'to_have_present_0',
            level: 2,
            status: 'seen',
            reviewDue: fmt(now.add(const Duration(days: 1))),
          ),
          'to_be_future_0': _vocab('to_be_future_0'), // neu -> nicht fällig
          'to_go_present_0': _vocab(
            'to_go_present_0',
            level: 1,
            status: 'seen',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ), // andere Kategorie -> nicht enthalten
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final due = await queries.getGroupDueWords('alice', cat);
      expect(due.map((e) => e.key), ['to_be_past_0']);
    });

    test('getGroupLearnedWords liefert nur Level-8-Wörter der Kategorie',
        () async {
      const cat = WordCategory(
        id: 'test5',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be'],
      );
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0':
              _vocab('to_be_present_0', level: 8, status: 'seen'),
          'to_be_past_0': _vocab('to_be_past_0', level: 7, status: 'seen'),
          'to_go_present_0':
              _vocab('to_go_present_0', level: 8, status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final learned = await queries.getGroupLearnedWords('alice', cat);
      expect(learned.map((e) => e.key), ['to_be_present_0']);
    });

    test('getGroupReadWords liefert alle gelesenen Wörter der Kategorie',
        () async {
      const cat = WordCategory(
        id: 'test6',
        order: 1,
        titleKey: 'catFirstVerbs',
        verbKeys: ['to_be'],
      );
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0': _vocab('to_be_present_0', status: 'seen'),
          // neu -> nicht gelesen
          'to_be_past_0': _vocab('to_be_past_0'),
          // Level 8 ist auch gelesen
          'to_be_future_0':
              _vocab('to_be_future_0', level: 8, status: 'seen'),
          // andere Kategorie -> nicht enthalten
          'to_go_present_0': _vocab('to_go_present_0', status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final read = await queries.getGroupReadWords('alice', cat);
      expect(read.map((e) => e.key).toSet(),
          {'to_be_present_0', 'to_be_future_0'});
    });

    test('getCategoryCounts zählt neu/fällig/gelernt/gesamt', () async {
      final cat =
          courseWordCategories.firstWhere((c) => c.id == 'erste_verben');
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_can_present_0': _vocab('to_can_present_0'),
          'to_want_past_0': _vocab(
            'to_want_past_0',
            level: 2,
            status: 'seen',
            reviewDue: fmt(now.subtract(const Duration(days: 1))),
          ),
          'to_must_present_0': _vocab('to_must_present_0',
              level: 8, status: 'seen'),
          'to_go_present_0': _vocab('to_go_present_0'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final counts = await queries.getCategoryCounts('alice');
      final c = counts[cat.id]!;
      expect(c.total, 3);
      expect(c.newCount, 1);
      expect(c.dueCount, 1);
      expect(c.readCount, 2);
      expect(c.learnedCount, 1);
    });
  });
  group('Kategorie-Präfixkollision (Fix: exakter Verb-Key-Match)', () {
    final erste = courseWordCategories.firstWhere((c) => c.id == 'erste_verben');
    final alltag =
        courseWordCategories.firstWhere((c) => c.id == 'grp_alltag');

    test('to_be_allowed_to_* gehört nur zu erste_verben, to_be_* nur zu grp_alltag',
        () {
      expect(erste.containsEntryKey('to_be_allowed_to_present_0'), true);
      expect(alltag.containsEntryKey('to_be_allowed_to_present_0'), false);
      expect(alltag.containsEntryKey('to_be_present_0'), true);
      expect(erste.containsEntryKey('to_be_present_0'), false);
    });

    test('getCategoryCounts: Summe über alle Kategorien == Einträge (Seed nur Verb-Keys)',
        () async {
      // Seed vollständig auf die 30 Verb-Keys gemappt, inkl. Kollisions-Keys
      // to_be_allowed_to_present_0 und to_be_present_0.
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_allowed_to_present_0': _vocab('to_be_allowed_to_present_0',
              level: 1, status: 'seen'),
          'to_be_present_0':
              _vocab('to_be_present_0', level: 1, status: 'seen'),
          'to_can_past_1': _vocab('to_can_past_1', level: 1, status: 'seen'),
        }),
      );
      final queries = VocabQueriesImpl(fake);
      final counts = await queries.getCategoryCounts('alice');
      final totalAll =
          counts.values.fold<int>(0, (sum, c) => sum + c.total);
      expect(totalAll, 3); // jeder Eintrag genau einmal
      expect(counts['erste_verben']!.total, 2); // to_be_allowed_to + to_can
      expect(counts['grp_alltag']!.total, 1); // to_be
    });

    test('getCategoryCounts: Legacy-Key i_want zählt in keiner Kategorie (eigener Seed)',
        () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'i_want': _vocab('i_want', level: 1, status: 'seen'),
          'to_be_present_0':
              _vocab('to_be_present_0', level: 1, status: 'seen'),
        }),
      );
      for (final c in courseWordCategories) {
        expect(c.containsEntryKey('i_want'), false);
      }
      final queries = VocabQueriesImpl(fake);
      final counts = await queries.getCategoryCounts('alice');
      final totalAll =
          counts.values.fold<int>(0, (sum, c) => sum + c.total);
      expect(totalAll, 1); // nur to_be_present_0, i_want in keiner Kategorie
      expect(counts['grp_alltag']!.total, 1);
    });

    test('getGroupWords: Sortierung in grp_alltag beginnt mit to_be, '
        'to_be_allowed_to_* ausgeschlossen', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_have_past_0': _vocab('to_have_past_0'),
          'to_be_present_1': _vocab('to_be_present_1'),
          'to_be_allowed_to_present_0': _vocab('to_be_allowed_to_present_0'),
          'to_be_past_0': _vocab('to_be_past_0'),
        }),
      );
      final queries = VocabQueriesImpl(fake);
      final words = await queries.getGroupWords('alice', alltag);
      expect(
        words.map((e) => e.key).toList(),
        ['to_be_past_0', 'to_be_present_1', 'to_have_past_0'],
      );
    });

    test('getGroupDueWords: fälliger to_be_allowed_to_* nicht in grp_alltag',
        () async {
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0': _vocab('to_be_present_0',
              level: 1, status: 'seen',
              reviewDue: fmt(now.subtract(const Duration(days: 1)))),
          'to_be_allowed_to_present_0': _vocab('to_be_allowed_to_present_0',
              level: 1, status: 'seen',
              reviewDue: fmt(now.subtract(const Duration(days: 1)))),
        }),
      );
      final queries = VocabQueriesImpl(fake);
      final dueWords = await queries.getGroupDueWords('alice', alltag);
      expect(dueWords.map((e) => e.key).toList(), ['to_be_present_0']);
    });

    test('getGroupLearnWords: to_be_allowed_to_* nicht in grp_alltag',
        () async {
      final now = DateTime.now();
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'to_be_present_0': _vocab('to_be_present_0',
              level: 1, status: 'seen',
              reviewDue: fmt(now.subtract(const Duration(days: 1)))),
          'to_be_allowed_to_present_0': _vocab('to_be_allowed_to_present_0',
              level: 1, status: 'seen',
              reviewDue: fmt(now.subtract(const Duration(days: 1)))),
        }),
      );
      final queries = VocabQueriesImpl(fake);
      final learnWords = await queries.getGroupLearnWords('alice', alltag);
      expect(learnWords.map((e) => e.key).toList(), ['to_be_present_0']);
    });
  });

  group('getUserStats', () {
    test('liefert alle fuenf Werte aus EINEM Load', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData(
          'alice',
          {
            // w1: neu (level 0 + status new)
            'w1_new': _vocab('w1_new'),
            // w2: gelesen + faellig (seen, review_due in der Vergangenheit)
            'w2_due': _vocab('w2_due',
                level: 1, status: 'seen', reviewDue: '2020-01-01'),
            // w3: gelesen, aber nicht faellig (review_due in der Zukunft)
            'w3_seen': _vocab('w3_seen',
                level: 1, status: 'seen', reviewDue: '2999-01-01'),
            // w4: gelesen + gelernt (level 8)
            'w4_learned': _vocab('w4_learned', level: 8, status: 'seen'),
            // w5: Edge-Case – level 1 + status new zaehlt nirgendwo
            'w5_edge': _vocab('w5_edge',
                level: 1, reviewDue: '2020-01-01'),
          },
          dayStreak: const DayStreak(current: 3, longest: 5),
        ),
      );

      final queries = VocabQueriesImpl(fake);
      final stats = await queries.getUserStats('alice');

      expect(stats.newCount, 1);
      expect(stats.dueCount, 1);
      expect(stats.readCount, 3);
      expect(stats.learnedCount, 1);
      expect(stats.streak.current, 3);
      expect(stats.streak.longest, 5);
      // Alle fuenf Werte stammen aus genau EINEM UserData-Load.
      expect(fake.loadCount, 1);
    });

    test('korrupte oder fehlende Datei liefert Default-UserStats (kein Crash)',
        () async {
      final corrupt = FakeUserManager(unreadableUsers: {'alice'});
      final q1 = VocabQueriesImpl(corrupt);
      final broken = await q1.getUserStats('alice');
      expect(broken.newCount, 0);
      expect(broken.dueCount, 0);
      expect(broken.readCount, 0);
      expect(broken.learnedCount, 0);
      expect(broken.streak.current, 0);
      expect(broken.streak.longest, 0);
      expect(broken.streak.lastDate, '');
      expect(corrupt.loadCount, 1);

      final missingUser = FakeUserManager();
      final q2 = VocabQueriesImpl(missingUser);
      final missing = await q2.getUserStats('nobody');
      expect(missing.newCount, 0);
      expect(missing.dueCount, 0);
      expect(missing.readCount, 0);
      expect(missing.learnedCount, 0);
      expect(missing.streak.current, 0);
      expect(missing.streak.longest, 0);
      expect(missingUser.loadCount, 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';

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
      expect(saved.vocab['haus']!.level, result.newLevel);
      expect(saved.vocab['haus']!.status, 'seen');
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
      expect(fake.lastSaved!.vocab['haus']!.status, 'seen');
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
      expect(saved.vocab['haus']!.level, 8);
      expect(saved.vocab['haus']!.reviewDue, isNull);
    });
  });

  group('checkWordAnswer – falsch / unbekannt', () {
    test('reset bei falscher Antwort, kein Save bei unbekanntem Wort', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus', level: 5, status: 'seen', translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      final wrong = await queries.checkWordAnswer('alice', 'haus', 'dog');
      expect(wrong.correct, false);
      expect(wrong.newLevel, 0);
      final saved = fake.lastSaved!;
      expect(saved.vocab['haus']!.level, 0);
      expect(saved.vocab['haus']!.status, 'new');
      expect(saved.vocab['haus']!.reviewDue, isNotNull);

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
      final reviewDue = saved.vocab['due']!.reviewDue;
      expect(reviewDue, isNotNull);
      expect(DateTime.parse(reviewDue!).isAfter(now), true);

      expect(await queries.getWordsDueCount('alice'), 0);
    });
  });

  group('getAllWords / getMasteredWords / getNewWordsCount', () {
    test('liefert alle, nur gesehene und zählt neue Wörter', () async {
      final fake = FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'new1': _vocab('new1'),
          'seen1': _vocab('seen1', status: 'seen'),
          'seen2': _vocab('seen2', status: 'seen'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      expect((await queries.getAllWords('alice')).length, 3);
      expect((await queries.getMasteredWords('alice')).map((e) => e.key),
          ['seen1', 'seen2']);
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
      expect(c.learnedCount, 1);
    });
  });
}

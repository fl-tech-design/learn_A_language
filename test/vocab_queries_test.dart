import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_manager.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';

/// Full fake analog zu test/vocab_manager_point3c_test.dart:49.
/// Speichert Benutzerdaten im Speicher und zählt saveUserdata-Aufrufe.
class _FakeUserManager implements UserManager {
  int saveCount = 0;
  UserData? _stored;
  String? _storedUsername;

  UserData? get lastSaved => _stored;

  void seed(String username, UserData data) {
    _stored = data;
    _storedUsername = username;
  }

  @override
  Future<String> createUserFile(
          String username, String mLang, Map<String, dynamic> languageDict) =>
      throw UnimplementedError('createUserFile');

  @override
  Future<UserData?> loadUserdata(String username) async {
    if (_storedUsername == username) return _stored;
    return null;
  }

  @override
  Future<void> saveUserdata(String username, UserData data) async {
    saveCount++;
    _stored = data;
    _storedUsername = username;
  }

  @override
  Future<void> addNewUserToList(String username) =>
      throw UnimplementedError('addNewUserToList');

  @override
  Future<String> deleteUser(String username) =>
      throw UnimplementedError('deleteUser');

  @override
  Future<void> changeLoginState({required bool newState}) =>
      throw UnimplementedError('changeLoginState');

  @override
  Future<void> setLoggedUname(String loggedUname) =>
      throw UnimplementedError('setLoggedUname');
}

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
      final fake = _FakeUserManager();
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
      final fake = _FakeUserManager();
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
      final fake = _FakeUserManager();
      final queries = VocabQueriesImpl(fake);

      // Ohne dayStreak → Default
      fake.seed('alice', _userData('alice', {}));
      final streak = await queries.getDayStreak('alice');
      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.lastDate, '');

      // lastDate = gestern → Increment-Pfad
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

      // lastDate = heute → no-op
      final saveCountBefore = fake.saveCount;
      fake.seed(
        'alice',
        _userData('alice', {},
            dayStreak: DayStreak(current: 5, longest: 5, lastDate: fmt(now))),
      );
      await queries.updateDayStreak('alice');
      expect(fake.saveCount, saveCountBefore);

      // lastDate = alte Vergangenheit → Reset auf 1
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
      final fake = _FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus', level: 3, translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);
      final result = await queries.checkWordAnswer('alice', 'haus', '  HAUS  ');

      expect(result.correct, true);
      expect(result.newLevel, greaterThan(3));
      expect(result.statusChanged, true);

      final saved = fake.lastSaved!;
      expect(saved.vocab['haus']!.level, result.newLevel);
      expect(saved.vocab['haus']!.status, 'seen');
    });
  });

  group('checkWordAnswer – falsch / unbekannt', () {
    test('reset bei falscher Antwort, kein Save bei unbekanntem Wort', () async {
      final fake = _FakeUserManager();
      fake.seed(
        'alice',
        _userData('alice', {
          'haus': _vocab('haus', level: 5, status: 'seen', translation: 'Haus'),
        }),
      );

      final queries = VocabQueriesImpl(fake);

      // Falsche Antwort → Reset-Pfad
      final wrong = await queries.checkWordAnswer('alice', 'haus', 'dog');
      expect(wrong.correct, false);
      expect(wrong.newLevel, 0);
      final saved = fake.lastSaved!;
      expect(saved.vocab['haus']!.level, 0);
      expect(saved.vocab['haus']!.status, 'new');
      expect(saved.vocab['haus']!.reviewDue, isNotNull);

      // Unbekanntes Wort → kein Save
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
      final fake = _FakeUserManager();
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
}
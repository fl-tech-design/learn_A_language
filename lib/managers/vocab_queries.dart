import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

export '../models/vocab_key.dart'
    show vocabVerbKey, vocabTenseKey, vocabPersonIndex, vocabTenseOrder;

import '../models/app_models.dart';
import '../models/vocab_key.dart';
import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
import 'user_manager.dart';
import 'vocab_manager.dart';

/// Word queries, streak, and answer checking — typed interface extracted
/// from the former static VocabQueries class.
abstract class VocabQueries {
  Future<List<VocabEntry>> getDueWords(String username,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getWordsByLevel(String username, int targetLevel,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getNewWords(String username,
      {String langCode = 'de', int limit = 10, int offset = 0});
  Future<List<VocabEntry>> getReadWords(String username,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getLearnedWords(String username,
      {String langCode = 'de'});
  Future<int> getWordsDueCount(String username, {String langCode = 'de'});
  Future<int> getNewWordsCount(String username, {String langCode = 'de'});
  Future<List<VocabEntry>> getAllWords(String username,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupWords(String username, WordCategory category,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupNewWords(String username,
      WordCategory category,
      {String langCode = 'de', int limit = 10, int offset = 0});
  Future<CategoryCounts> getGroupCounts(
      String username, WordCategory category,
      {String langCode = 'de'});
  Future<Map<String, CategoryCounts>> getCategoryCounts(String username,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupLearnWords(
      String username, WordCategory category,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupDueWords(
      String username, WordCategory category,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupLearnedWords(
      String username, WordCategory category,
      {String langCode = 'de'});
  Future<List<VocabEntry>> getGroupReadWords(
      String username, WordCategory category,
      {String langCode = 'de'});
  Future<DayStreak> getDayStreak(String username);
  Future<UserStats> getUserStats(String username, {String? langCode});
  Future<void> updateDayStreak(String username);
  Future<AnswerCheckResult> checkWordAnswer(
      String username, String wordKey, String userInput,
      {String langCode = 'de'});
}

/// Concrete implementation backed by [UserManager].
class VocabQueriesImpl implements VocabQueries {
  final UserManager _userManager;

  /// Serializes answer saves so parallel checkWordAnswer calls cannot
  /// overwrite each other (lost update guard).
  Future<void> _answerQueue = Future.value();

  VocabQueriesImpl(this._userManager);

  /// Lädt UserData für Lesezugriffe, ohne dass eine korrupte Datei den
  /// Aufrufer (Screen/Manager) crasht: Fehler werden geloggt, der
  /// [StorageErrorBus] informiert die UI einmalig, und es wird `null`
  /// zurückgegeben („kein User da" – wie bei fehlender Datei).
  Future<UserData?> _loadSafe(String username) async {
    try {
      return await _userManager.loadUserdata(username);
    } on PersistenceException catch (e) {
      developer.log('vocab_queries: Userdaten für $username unlesbar ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.userDataUnloadable);
      return null;
    }
  }

  @override
  Future<List<VocabEntry>> getDueWords(String username,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final today = DateTime.now();
    final dueWords = <VocabEntry>[];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};

    for (final ve in vocab.values) {
      if (ve.level == 8) continue;
      if (ve.status == 'new') continue;

      final reviewDueStr = ve.reviewDue;
      if (reviewDueStr != null && reviewDueStr.isNotEmpty) {
        try {
          final reviewDue = DateTime.parse(reviewDueStr);
          if (!reviewDue.isAfter(today)) {
            dueWords.add(ve);
          }
        } catch (_) {
          dueWords.add(ve);
        }
      } else {
        dueWords.add(ve);
      }
    }
    return dueWords;
  }

  @override
  Future<List<VocabEntry>> getWordsByLevel(String username, int targetLevel,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    return vocab.values.where((ve) => ve.level == targetLevel).toList();
  }

  @override
  Future<List<VocabEntry>> getNewWords(String username,
      {String langCode = 'de', int limit = 10, int offset = 0}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final newWords = vocab.values
        .where((ve) => ve.level == 0 && ve.status == 'new')
        .toList();
    final start = offset.clamp(0, newWords.length);
    final end = (offset + limit).clamp(0, newWords.length);
    return newWords.sublist(start, end);
  }

  @override
  Future<List<VocabEntry>> getReadWords(String username,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    // „Gelesene Wörter": alles, was mindestens einmal angeschaut wurde.
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    return vocab.values.where((ve) => ve.status == 'seen').toList();
  }

  @override
  Future<List<VocabEntry>> getLearnedWords(String username,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    // „Gelernte Wörter": fertig gelernt (Level 8) – über alle Kategorien.
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    return vocab.values.where((ve) => ve.level >= 8).toList();
  }

  @override
  Future<int> getWordsDueCount(String username,
          {String langCode = 'de'}) async =>
      (await getDueWords(username, langCode: langCode)).length;

  @override
  Future<int> getNewWordsCount(String username,
          {String langCode = 'de'}) async {
    final words = await getWordsByLevel(username, 0, langCode: langCode);
    return words.where((w) => w.status == 'new').length;
  }

  @override
  Future<List<VocabEntry>> getAllWords(String username,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    return vocab.values.toList();
  }

  @override
  Future<List<VocabEntry>> getGroupWords(String username, WordCategory category,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final entries = vocab.values
        .where((ve) => category.containsEntryKey(ve.key))
        .toList();
    entries.sort((a, b) => _compareEntries(category, a, b));
    return entries;
  }

  @override
  Future<List<VocabEntry>> getGroupNewWords(String username,
      WordCategory category,
      {String langCode = 'de', int limit = 10, int offset = 0}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final newWords = vocab.values
        .where((ve) =>
            ve.level == 0 &&
            ve.status == 'new' &&
            category.containsEntryKey(ve.key))
        .toList();
    final start = offset.clamp(0, newWords.length);
    final end = (offset + limit).clamp(0, newWords.length);
    return newWords.sublist(start, end);
  }

  @override
  Future<CategoryCounts> getGroupCounts(
      String username, WordCategory category,
      {String langCode = 'de'}) async {
    final all = await getCategoryCounts(username, langCode: langCode);
    return all[category.id] ?? const CategoryCounts();
  }

  @override
  Future<Map<String, CategoryCounts>> getCategoryCounts(String username,
      {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    final result = <String, CategoryCounts>{};
    if (ud == null) return result;
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final today = DateTime.now();
    for (final cat in courseWordCategories) {
      var total = 0;
      var newC = 0;
      var due = 0;
      var read = 0;
      var learned = 0;
      for (final ve in vocab.values) {
        if (!cat.containsEntryKey(ve.key)) continue;
        total++;
        if (ve.status == 'seen') read++;
        if (ve.level >= 8) {
          learned++;
          continue;
        }
        if (ve.level == 0 && ve.status == 'new') {
          newC++;
          continue;
        }
        if (ve.status == 'seen') {
          if (_isDue(ve, today)) due++;
        }
      }
      result[cat.id] = CategoryCounts(
        total: total,
        newCount: newC,
        dueCount: due,
        readCount: read,
        learnedCount: learned,
      );
    }
    return result;
  }

  @override
  Future<List<VocabEntry>> getGroupLearnWords(String username,
      WordCategory category, {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final due = <VocabEntry>[];
    final fresh = <VocabEntry>[];
    final today = DateTime.now();
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    for (final ve in vocab.values) {
      if (!category.containsEntryKey(ve.key)) continue;
      if (ve.level >= 8) continue;
      if (ve.level == 0 && ve.status == 'new') {
        fresh.add(ve);
        continue;
      }
      if (ve.status == 'seen' && _isDue(ve, today)) {
        due.add(ve);
      }
    }
    // Wiederverwendung der bestehenden Sortierung (Verb, Zeitform, Person).
    due.sort((a, b) => _compareEntries(category, a, b));
    fresh.sort((a, b) => _compareEntries(category, a, b));
    return [...due, ...fresh];
  }

  @override
  Future<List<VocabEntry>> getGroupDueWords(String username,
      WordCategory category, {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final today = DateTime.now();
    final due = <VocabEntry>[];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    for (final ve in vocab.values) {
      if (!category.containsEntryKey(ve.key)) continue;
      if (ve.level == 8) continue;
      if (ve.status == 'new') continue;
      if (_isDue(ve, today)) due.add(ve);
    }
    due.sort((a, b) => _compareEntries(category, a, b));
    return due;
  }

  @override
  Future<List<VocabEntry>> getGroupLearnedWords(String username,
      WordCategory category, {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final learned = vocab.values
        .where((ve) => ve.level >= 8 && category.containsEntryKey(ve.key))
        .toList();
    learned.sort((a, b) => _compareEntries(category, a, b));
    return learned;
  }

  @override
  Future<List<VocabEntry>> getGroupReadWords(String username,
      WordCategory category, {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return [];
    final vocab = ud.vocabByLang[langCode] ?? const <String, VocabEntry>{};
    final read = vocab.values
        .where((ve) =>
            ve.status == 'seen' && category.containsEntryKey(ve.key))
        .toList();
    read.sort((a, b) => _compareEntries(category, a, b));
    return read;
  }

  bool _isDue(VocabEntry ve, DateTime today) {
    final r = ve.reviewDue;
    if (r == null || r.isEmpty) return true;
    try {
      return !DateTime.parse(r).isAfter(today);
    } catch (_) {
      return true;
    }
  }

  /// Sortiert nach Verb (Reihenfolge in der Kategorie), dann Zeitform, dann
  /// Person.
  int _compareEntries(WordCategory category, VocabEntry a, VocabEntry b) {
    final aVerb = vocabVerbKey(a.key);
    final bVerb = vocabVerbKey(b.key);
    if (aVerb != bVerb) {
      return category.verbKeys
          .indexOf(aVerb)
          .compareTo(category.verbKeys.indexOf(bVerb));
    }
    final aTense = vocabTenseKey(a.key);
    final bTense = vocabTenseKey(b.key);
    if (aTense != bTense) {
      return vocabTenseOrder(aTense).compareTo(vocabTenseOrder(bTense));
    }
    return vocabPersonIndex(a.key).compareTo(vocabPersonIndex(b.key));
  }

  @override
  Future<DayStreak> getDayStreak(String username) async {
    final ud = await _loadSafe(username);
    return ud?.dayStreak ?? const DayStreak();
  }

  @override
  Future<UserStats> getUserStats(String username, {String? langCode}) async {
    final ud = await _loadSafe(username);
    if (ud == null) return const UserStats();
    final today = DateTime.now();
    var newCount = 0;
    var dueCount = 0;
    var readCount = 0;
    var learnedCount = 0;
    // Ohne langCode werden alle Sprachen aggregiert (Startbildschirm).
    final values = (langCode != null && langCode.isNotEmpty)
        ? (ud.vocabByLang[langCode] ?? const <String, VocabEntry>{}).values
        : ud.vocabByLang.values.expand((m) => m.values);
    for (final ve in values) {
      if (ve.level == 0 && ve.status == 'new') newCount++;
      if (ve.status == 'seen') readCount++;
      if (ve.level >= 8) learnedCount++;
      if (ve.level != 8 && ve.status != 'new' && _isDue(ve, today)) {
        dueCount++;
      }
    }
    return UserStats(
      newCount: newCount,
      dueCount: dueCount,
      readCount: readCount,
      learnedCount: learnedCount,
      streak: ud.dayStreak ?? const DayStreak(),
    );
  }

  @override
  Future<void> updateDayStreak(String username) async {
    final ud = await _loadSafe(username);
    if (ud == null) return;
    final streak = ud.dayStreak ?? const DayStreak();

    final today = DateTime.now();
    final todayStr = fmt(today);
    if (streak.lastDate == todayStr) return;
    final yesterdayStr = fmt(today.subtract(const Duration(days: 1)));

    final int newCurrent;
    if (streak.lastDate == yesterdayStr) {
      newCurrent = streak.current + 1;
    } else {
      newCurrent = 1;
    }
    final newLongest = max<int>(streak.longest, newCurrent);

    try {
      await _userManager.saveUserdata(
          username,
          ud.copyWith(
              dayStreak: DayStreak(
            current: newCurrent,
            longest: newLongest,
            lastDate: todayStr,
          )));
    } on PersistenceException catch (e) {
      developer.log('updateDayStreak: Speichern für $username fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
    }
  }

  @override
  Future<AnswerCheckResult> checkWordAnswer(
      String username, String wordKey, String userInput,
      {String langCode = 'de'}) {
    final completer = Completer<AnswerCheckResult>();
    _answerQueue = _answerQueue.then((_) async {
      try {
        completer.complete(await _checkWordAnswer(
            username, wordKey, userInput,
            langCode: langCode));
      } catch (e, st) {
        // Letzte Verteidigung: niemals eine unbehandelte Async-Exception in
        // die Screens entlassen – der Antwort-Pfad läuft mit Hinweis weiter.
        developer.log('checkWordAnswer: unerwarteter Fehler ($e)\n$st');
        completer.complete(const AnswerCheckResult(
          correct: false,
          message: 'Interner Fehler.',
          persistenceFailed: true,
        ));
      }
    });
    return completer.future;
  }

  /// Actual answer checking + persistence, serialized via [_answerQueue].
  Future<AnswerCheckResult> _checkWordAnswer(String username, String wordKey,
      String userInput, {String langCode = 'de'}) async {
    final ud = await _loadSafe(username);
    final vocab = ud?.vocabByLang[langCode];
    if (ud == null || vocab == null || !vocab.containsKey(wordKey)) {
      return const AnswerCheckResult(
        correct: false,
        message: 'Wort nicht gefunden',
      );
    }

    final ve = vocab[wordKey]!;
    final correctTranslation = ve.translation;
    final currentLevel = ve.level;
    final currentStatus = ve.status;

    final userClean = userInput.trim().toLowerCase().replaceAll(' ', '');
    final correctClean =
        correctTranslation.trim().toLowerCase().replaceAll(' ', '');
    final isCorrect = userClean == correctClean;

    if (isCorrect) {
      final newLevel = (currentLevel + 1).clamp(0, 8);
      final now = DateTime.now();
      final statusChanged = currentStatus == 'new';
      final newReviewDue = newLevel < 8
          ? fmt(now.add(
              Duration(days: VocabManager.repeatIntervalDays[newLevel] ?? 1)))
          : null;

      final updated = ve.copyWith(
        level: newLevel,
        status: statusChanged ? 'seen' : null,
        lastReviewed: now.toIso8601String(),
        reviewDue: newReviewDue,
        clearReviewDue: newLevel >= 8,
      );

      final newVocab = Map<String, VocabEntry>.from(vocab);
      newVocab[wordKey] = updated;
      final vocabByLang =
          Map<String, Map<String, VocabEntry>>.from(ud.vocabByLang)
            ..[langCode] = newVocab;
      try {
        await _userManager.saveUserdata(
            username, ud.copyWith(vocabByLang: vocabByLang));
      } on PersistenceException catch (e) {
        developer.log('checkWordAnswer: Fortschritt nicht gespeichert ($e)');
        StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
        return AnswerCheckResult(
          correct: true,
          correctWord: correctTranslation,
          newLevel: newLevel,
          message: 'Fortschritt konnte nicht gespeichert werden.',
          statusChanged: statusChanged,
          persistenceFailed: true,
        );
      }

      return AnswerCheckResult(
        correct: true,
        correctWord: correctTranslation,
        newLevel: newLevel,
        message: newLevel == 8
            ? 'Ausgezeichnet! Wort gelernt (Level 8).'
            : 'Richtig! Gut gemacht.',
        statusChanged: statusChanged,
      );
    } else {
      final now = DateTime.now();
      // Falsch beantwortet: auf den Lernanfang zurueckfallen lassen – aber auf
      // LV1 ("in Arbeit"), NICHT auf LV0 (LV0 = "noch nie gelesen"). Das Wort
      // bleibt damit status 'seen' und wird ueber reviewDue (= morgen) wieder
      // faellig, statt als neues Wort zu gelten.
      const wrongLevel = 1;
      final updated = ve.copyWith(
        level: wrongLevel,
        status: 'seen',
        lastReviewed: now.toIso8601String(),
        reviewDue: fmt(now.add(const Duration(days: 1))),
      );

      final newVocab = Map<String, VocabEntry>.from(vocab);
      newVocab[wordKey] = updated;
      final vocabByLang =
          Map<String, Map<String, VocabEntry>>.from(ud.vocabByLang)
            ..[langCode] = newVocab;
      try {
        await _userManager.saveUserdata(
            username, ud.copyWith(vocabByLang: vocabByLang));
      } on PersistenceException catch (e) {
        developer.log('checkWordAnswer: Fortschritt nicht gespeichert ($e)');
        StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
        return AnswerCheckResult(
          correct: false,
          correctWord: correctTranslation,
          newLevel: wrongLevel,
          message: 'Fortschritt konnte nicht gespeichert werden.',
          persistenceFailed: true,
        );
      }

      return AnswerCheckResult(
        correct: false,
        correctWord: correctTranslation,
        newLevel: wrongLevel,
        message: 'Leider falsch. Richtig wäre: $correctTranslation',
      );
    }
  }
}

String fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

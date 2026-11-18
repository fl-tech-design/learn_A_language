import 'dart:async';
import 'dart:math';

import '../models/app_models.dart';
import 'user_manager.dart';
import 'vocab_manager.dart';

/// Word queries, streak, and answer checking — typed interface extracted
/// from the former static VocabQueries class.
abstract class VocabQueries {
  Future<List<VocabEntry>> getDueWords(String username);
  Future<List<VocabEntry>> getWordsByLevel(
      String username, int targetLevel);
  Future<List<VocabEntry>> getNewWords(String username,
      {int limit = 10, int offset = 0});
  Future<List<VocabEntry>> getMasteredWords(String username);
  Future<int> getWordsDueCount(String username);
  Future<int> getNewWordsCount(String username);
  Future<List<VocabEntry>> getAllWords(String username);
  Future<List<VocabEntry>> getGroupWords(
      String username, WordCategory category);
  Future<List<VocabEntry>> getGroupNewWords(String username,
      WordCategory category, {int limit = 10, int offset = 0});
  Future<CategoryCounts> getGroupCounts(
      String username, WordCategory category);
  Future<Map<String, CategoryCounts>> getCategoryCounts(String username);
  Future<List<VocabEntry>> getGroupLearnWords(
      String username, WordCategory category);
  Future<List<VocabEntry>> getGroupDueWords(
      String username, WordCategory category);
  Future<List<VocabEntry>> getGroupLearnedWords(
      String username, WordCategory category);
  Future<DayStreak> getDayStreak(String username);
  Future<void> updateDayStreak(String username);
  Future<AnswerCheckResult> checkWordAnswer(
      String username, String wordKey, String userInput);
}

/// Concrete implementation backed by [UserManager].
class VocabQueriesImpl implements VocabQueries {
  final UserManager _userManager;

  /// Serializes answer saves so parallel checkWordAnswer calls cannot
  /// overwrite each other (lost update guard).
  Future<void> _answerQueue = Future.value();

  VocabQueriesImpl(this._userManager);

  @override
  Future<List<VocabEntry>> getDueWords(String username) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final today = DateTime.now();
    final dueWords = <VocabEntry>[];

    for (final ve in ud.vocab.values) {
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
  Future<List<VocabEntry>> getWordsByLevel(
      String username, int targetLevel) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    return ud.vocab.values.where((ve) => ve.level == targetLevel).toList();
  }

  @override
  Future<List<VocabEntry>> getNewWords(String username,
      {int limit = 10, int offset = 0}) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final newWords = ud.vocab.values
        .where((ve) => ve.level == 0 && ve.status == 'new')
        .toList();
    final start = offset.clamp(0, newWords.length);
    final end = (offset + limit).clamp(0, newWords.length);
    return newWords.sublist(start, end);
  }

  @override
  Future<List<VocabEntry>> getMasteredWords(String username) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    return ud.vocab.values.where((ve) => ve.status == 'seen').toList();
  }

  @override
  Future<int> getWordsDueCount(String username) async =>
      (await getDueWords(username)).length;

  @override
  Future<int> getNewWordsCount(String username) async {
    final words = await getWordsByLevel(username, 0);
    return words.where((w) => w.status == 'new').length;
  }

  @override
  Future<List<VocabEntry>> getAllWords(String username) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    return ud.vocab.values.toList();
  }

  @override
  Future<List<VocabEntry>> getGroupWords(
      String username, WordCategory category) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final entries = ud.vocab.values
        .where((ve) => category.containsEntryKey(ve.key))
        .toList();
    entries.sort((a, b) => _compareEntries(category, a, b));
    return entries;
  }

  @override
  Future<List<VocabEntry>> getGroupNewWords(String username,
      WordCategory category, {int limit = 10, int offset = 0}) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final newWords = ud.vocab.values
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
      String username, WordCategory category) async {
    final all = await getCategoryCounts(username);
    return all[category.id] ?? const CategoryCounts();
  }

  @override
  Future<Map<String, CategoryCounts>> getCategoryCounts(
      String username) async {
    final ud = await _userManager.loadUserdata(username);
    final result = <String, CategoryCounts>{};
    if (ud == null) return result;
    final today = DateTime.now();
    for (final cat in courseWordCategories) {
      var total = 0;
      var newC = 0;
      var due = 0;
      var learned = 0;
      for (final ve in ud.vocab.values) {
        if (!cat.containsEntryKey(ve.key)) continue;
        total++;
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
        learnedCount: learned,
      );
    }
    return result;
  }

  @override
  Future<List<VocabEntry>> getGroupLearnWords(
      String username, WordCategory category) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final due = <VocabEntry>[];
    final fresh = <VocabEntry>[];
    final today = DateTime.now();
    for (final ve in ud.vocab.values) {
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
  Future<List<VocabEntry>> getGroupDueWords(
      String username, WordCategory category) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final today = DateTime.now();
    final due = <VocabEntry>[];
    for (final ve in ud.vocab.values) {
      if (!category.containsEntryKey(ve.key)) continue;
      if (ve.level == 8) continue;
      if (ve.status == 'new') continue;
      if (_isDue(ve, today)) due.add(ve);
    }
    due.sort((a, b) => _compareEntries(category, a, b));
    return due;
  }

  @override
  Future<List<VocabEntry>> getGroupLearnedWords(
      String username, WordCategory category) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return [];
    final learned = ud.vocab.values
        .where((ve) => ve.level >= 8 && category.containsEntryKey(ve.key))
        .toList();
    learned.sort((a, b) => _compareEntries(category, a, b));
    return learned;
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
    final ud = await _userManager.loadUserdata(username);
    return ud?.dayStreak ?? const DayStreak();
  }

  @override
  Future<void> updateDayStreak(String username) async {
    final ud = await _userManager.loadUserdata(username);
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

    await _userManager.saveUserdata(
        username,
        ud.copyWith(
            dayStreak: DayStreak(
          current: newCurrent,
          longest: newLongest,
          lastDate: todayStr,
        )));
  }

  @override
  Future<AnswerCheckResult> checkWordAnswer(
      String username, String wordKey, String userInput) {
    final completer = Completer<AnswerCheckResult>();
    _answerQueue = _answerQueue.then((_) async {
      try {
        completer.complete(
            await _checkWordAnswer(username, wordKey, userInput));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Actual answer checking + persistence, serialized via [_answerQueue].
  Future<AnswerCheckResult> _checkWordAnswer(
      String username, String wordKey, String userInput) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null || !ud.vocab.containsKey(wordKey)) {
      return const AnswerCheckResult(
        correct: false,
        message: 'Wort nicht gefunden',
      );
    }

    final ve = ud.vocab[wordKey]!;
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

      final newVocab = Map<String, VocabEntry>.from(ud.vocab);
      newVocab[wordKey] = updated;
      await _userManager.saveUserdata(
          username, ud.copyWith(vocab: newVocab));

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
      final updated = ve.copyWith(
        level: 0,
        status: 'new',
        lastReviewed: now.toIso8601String(),
        reviewDue: fmt(now.add(const Duration(days: 1))),
      );

      final newVocab = Map<String, VocabEntry>.from(ud.vocab);
      newVocab[wordKey] = updated;
      await _userManager.saveUserdata(
          username, ud.copyWith(vocab: newVocab));

      return AnswerCheckResult(
        correct: false,
        correctWord: correctTranslation,
        newLevel: 0,
        message: 'Leider falsch. Richtig wäre: $correctTranslation',
      );
    }
  }
}

String fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Key-Hilfsfunktionen für Vokabel-Keys ───────────────────────────────
// Vocab-Keys haben das Format '<verb>_<zeitform>_<person>' (z. B. 'be_present_0'
// oder 'be_allowed_to_present_0'). Die folgenden Funktionen extrahieren die
// einzelnen Segmente robust, auch wenn der Verb-Schlüssel Unterstriche enthält.

/// Liefert den Verb-Schlüssel (z. B. 'be_allowed_to') eines Vocab-Keys.
String vocabVerbKey(String entryKey) {
  final parts = entryKey.split('_');
  return parts.length <= 2 ? entryKey : parts.sublist(0, parts.length - 2).join('_');
}

/// Liefert das Zeitform-Segment ('past' | 'present' | 'future').
String vocabTenseKey(String entryKey) {
  final parts = entryKey.split('_');
  return parts.length >= 2 ? parts[parts.length - 2] : '';
}

/// Liefert den Personen-Index (letztes Segment) eines Vocab-Keys.
int vocabPersonIndex(String entryKey) =>
    int.tryParse(entryKey.split('_').last) ?? 0;

/// Sortierreihenfolge der Zeitformen (past -> present -> future).
int vocabTenseOrder(String tense) =>
    switch (tense) { 'past' => 0, 'present' => 1, _ => 2 };

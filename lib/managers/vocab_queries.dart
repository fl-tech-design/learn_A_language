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

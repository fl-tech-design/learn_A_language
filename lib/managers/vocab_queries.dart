import 'dart:math';
import 'user_manager.dart';
import 'vocab_manager.dart';

/// Word queries, streak, and answer checking – separated from vocab_manager.
class VocabQueries {
  VocabQueries._();

  // ── Word queries ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDueWords(
    String username,
  ) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};
    final today = DateTime.now();
    final dueWords = <Map<String, dynamic>>[];

    for (final entry in vocab.entries) {
      final wordEntry = entry.value as Map<String, dynamic>;
      final level = wordEntry['level'] as int? ?? 0;
      if (level == 8) continue;
      if ((wordEntry['status']?.toString() ?? 'new') == 'new') continue;

      final reviewDueStr = wordEntry['review_due']?.toString();
      if (reviewDueStr != null && reviewDueStr.isNotEmpty) {
        try {
          final reviewDue = DateTime.parse(reviewDueStr);
          if (!reviewDue.isAfter(today)) {
            dueWords.add({...wordEntry, 'key': entry.key});
          }
        } catch (_) {
          dueWords.add({...wordEntry, 'key': entry.key});
        }
      } else {
        dueWords.add({...wordEntry, 'key': entry.key});
      }
    }
    return dueWords;
  }

  static Future<List<Map<String, dynamic>>> getWordsByLevel(
      String username, int targetLevel) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};
    return vocab.entries
        .where((e) => (e.value as Map<String, dynamic>)['level'] == targetLevel)
        .map((e) => {...e.value as Map<String, dynamic>, 'key': e.key})
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getNewWords(String username,
      {int limit = 10, int offset = 0}) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};
    final newWords = vocab.entries
        .where((e) {
          final v = e.value as Map<String, dynamic>;
          return (v['level'] ?? 0) == 0 && (v['status'] ?? 'new') == 'new';
        })
        .map((e) => {...e.value as Map<String, dynamic>, 'key': e.key})
        .toList();
    final start = offset.clamp(0, newWords.length);
    final end = (offset + limit).clamp(0, newWords.length);
    return newWords.sublist(start, end);
  }

  static Future<List<Map<String, dynamic>>> getMasteredWords(
      String username) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};
    return vocab.entries
        .where((e) => (e.value as Map<String, dynamic>)['status'] == 'seen')
        .map((e) => {...e.value as Map<String, dynamic>, 'key': e.key})
        .toList();
  }

  static Future<int> getWordsDueCount(String username) async =>
      (await getDueWords(username)).length;

  static Future<int> getNewWordsCount(String username) async {
    final words = await getWordsByLevel(username, 0);
    return words.where((w) => (w['status'] ?? 'new') == 'new').length;
  }

  static Future<List<Map<String, dynamic>>> getAllWords(String username) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};
    return vocab.entries
        .map((e) => {...e.value as Map<String, dynamic>, 'key': e.key})
        .toList();
  }
// ── Day streak ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDayStreak(String username) async {
    final userData = await UserManager.loadUserdata(username);
    return userData['day_streak'] as Map<String, dynamic>? ??
        {'current': 0, 'longest': 0, 'last_date': ''};
  }

  static Future<void> updateDayStreak(String username) async {
    final userData = await UserManager.loadUserdata(username);
    var streak = userData['day_streak'] as Map<String, dynamic>? ??
        {'current': 0, 'longest': 0, 'last_date': ''};

    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final todayStr = fmt(today);
    // Already counted today → do nothing (matches vocab_manager.py).
    if (streak['last_date'] == todayStr) return;
    final yesterdayStr = fmt(today.subtract(const Duration(days: 1)));

    if (streak['last_date'] == yesterdayStr) {
      streak['current'] = (streak['current'] as int? ?? 0) + 1;
    } else {
      streak['current'] = 1;
    }
    streak['longest'] = max<int>(
      streak['longest'] as int? ?? 0,
      streak['current'] as int? ?? 0,
    );
    streak['last_date'] = todayStr;

    userData['day_streak'] = streak;
    await UserManager.saveUserdata(username, userData);
  }

  // ── Word checking ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkWordAnswer(
      String username, String wordKey, String userInput) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>? ?? {};

    if (!vocab.containsKey(wordKey)) {
      return {
        'correct': false,
        'correct_word': '',
        'new_level': 0,
        'message': 'Wort nicht gefunden',
        'status_changed': false,
      };
    }

    final wordEntry = vocab[wordKey] as Map<String, dynamic>;
    final correctTranslation = wordEntry['translation']?.toString() ?? '';
    final currentLevel = wordEntry['level'] as int? ?? 0;
    final currentStatus = wordEntry['status']?.toString() ?? 'new';

    final userClean = userInput.trim().toLowerCase().replaceAll(' ', '');
    final correctClean =
        correctTranslation.trim().toLowerCase().replaceAll(' ', '');
    final isCorrect = userClean == correctClean;

    final result = <String, dynamic>{
      'correct': isCorrect,
      'correct_word': correctTranslation,
      'new_level': currentLevel,
      'message': '',
      'status_changed': false,
    };

    if (isCorrect) {
      final newLevel = (currentLevel + 1).clamp(0, 8);
      wordEntry['level'] = newLevel;
      wordEntry['last_reviewed'] = DateTime.now().toIso8601String();

      if (currentStatus == 'new') {
        wordEntry['status'] = 'seen';
        result['status_changed'] = true;
      }

      if (newLevel < 8) {
        final days = VocabManager.repeatIntervalDays[newLevel] ?? 1;
        final nextDue = DateTime.now().add(Duration(days: days));
        wordEntry['review_due'] = fmt(nextDue);
      } else {
        wordEntry['review_due'] = null;
      }

      result['new_level'] = newLevel;
      result['message'] = newLevel == 8
          ? 'Ausgezeichnet! Wort gelernt (Level 8).'
          : 'Richtig! Gut gemacht.';
    } else {
      wordEntry['level'] = 0;
      wordEntry['status'] = 'new';
      wordEntry['last_reviewed'] = DateTime.now().toIso8601String();
      wordEntry['review_due'] =
          fmt(DateTime.now().add(const Duration(days: 1)));
      result['new_level'] = 0;
      result['message'] = 'Leider falsch. Richtig wäre: $correctTranslation';
    }

    userData['vocab'] = vocab;
    await UserManager.saveUserdata(username, userData);
    return result;
  }
}

String fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

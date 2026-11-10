import 'dart:math';
import '../models/app_models.dart';
import '../services/file_service.dart';
import 'user_manager.dart';

/// Pure static vocabulary management – 1:1 from vocab_manager.py.
class VocabManager {
  VocabManager._();

  /// Spaced repetition: days until next review per level.
  static const Map<int, int?> repeatIntervalDays = {
    0: 1, 1: 2, 2: 3, 3: 5, 4: 7, 5: 10, 6: 14, 7: 21, 8: null,
  };

  /// Loads merged language dictionary from app documents.
  static Future<Map<String, dynamic>> loadLanguageDictFromDir(
    String langCode,
  ) async {
    return FileService.loadLanguageDictFromDir(langCode);
  }

  /// Recursively extracts all words/sentences from a nested language dict.
  static List<Map<String, dynamic>> extractAllWordsFromLanguageDict(
    Map<String, dynamic> languageDict,
  ) {
    final words = <Map<String, dynamic>>[];

    void recurse(dynamic data, String currentKey) {
      if (data is Map<String, dynamic>) {
        if (data.containsKey('translation') && !data.containsKey('word')) {
          final wordKey = currentKey.split('/').last;
          final wordText = wordKey.replaceAll('_', ' ');
          final rawExamples = data['example'] ?? data['examples'] ?? {};
          final examples = <String>[];
          if (rawExamples is Map) {
            examples.addAll(rawExamples.values.map((e) => e.toString()));
          } else if (rawExamples is String && rawExamples.isNotEmpty) {
            examples.add(rawExamples);
          }
          words.add({
            'key': wordKey,
            'word': wordText,
            'translation': data['translation'],
            'examples': examples.isNotEmpty ? examples : [''],
          });
        } else {
          data.forEach((key, value) {
            final newKey = currentKey.isEmpty ? key : '$currentKey/$key';
            recurse(value, newKey);
          });
        }
      } else if (data is List) {
        for (final item in data) {
          recurse(item, currentKey);
        }
      }
    }

    recurse(languageDict, '');
    return words;
  }

  /// Initializes the vocab dictionary in the user file.
  static Future<void> initVocabForUser(
    String username,
    Map<String, dynamic> languageDict,
  ) async {
    final userData = await UserManager.loadUserdata(username);
    final existingVocab = userData['vocab'];
    if (existingVocab is Map && existingVocab.isNotEmpty) return;

    final mLang = userData['m_lang']?.toString() ?? 'de';
    var langDict = languageDict;
    if (langDict.isEmpty) {
      langDict = await loadLanguageDictFromDir(mLang);
      if (langDict.isEmpty) return;
    }

    final targetWords = extractAllWordsFromLanguageDict(langDict);

    final nativeWords = <String, String>{};
    final nativeExamples = <String, List<String>>{};
    if (mLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(mLang);
      if (nativeDict.isNotEmpty) {
        for (final w in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[w['key'] as String] = w['translation'] as String;
          nativeExamples[w['key'] as String] =
              (w['examples'] as List?)?.cast<String>() ?? [''];
        }
      }
    }

    final vocab = <String, dynamic>{};
    for (final w in targetWords) {
      final key = w['key'] as String;
      vocab[key] = {
        'word': w['translation'],
        'translation': nativeWords[key] ?? w['translation'],
        'examples': w['examples'],
        'examples_native': nativeExamples[key] ?? [''],
        'level': 0,
        'status': 'new',
        'last_reviewed': null,
        'review_due': null,
      };
    }

    userData['vocab'] = vocab;
    await UserManager.saveUserdata(username, userData);
  }
// ── Migration ───────────────────────────────────────────────

  static Future<void> migrateVocabForUser(String username) async {
    final userData = await UserManager.loadUserdata(username);
    final vocab = userData['vocab'] as Map<String, dynamic>?;
    if (vocab == null || vocab.isEmpty) return;

    var changed = false;
    final mLang = userData['m_lang']?.toString() ?? 'de';
    final targetLang = mLang == 'de' ? 'en' : 'de';

    final targetWordsMap = <String, String>{};
    final targetDict = await loadLanguageDictFromDir(targetLang);
    if (targetDict.isNotEmpty) {
      for (final w in extractAllWordsFromLanguageDict(targetDict)) {
        targetWordsMap[w['key'] as String] = w['translation'] as String;
      }
    }

    final nativeWords = <String, String>{};
    final nativeWordsMap = <String, Map<String, dynamic>>{};
    if (mLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(mLang);
      if (nativeDict.isNotEmpty) {
        for (final w in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[w['key'] as String] = w['translation'] as String;
          nativeWordsMap[w['key'] as String] = w;
        }
      }
    }

    for (final entry in vocab.entries) {
      final we = entry.value as Map<String, dynamic>;
      if (!we.containsKey('status')) {
        we['status'] = (we['level'] ?? 0) == 0 ? 'new' : 'seen';
        changed = true;
      }
      if (!we.containsKey('review_due')) { we['review_due'] = null; changed = true; }
      if (!we.containsKey('last_reviewed')) { we['last_reviewed'] = null; changed = true; }
      if (!we.containsKey('level')) { we['level'] = 0; changed = true; }
      if (!we.containsKey('examples')) {
        final old = we['example'] ?? '';
        we['examples'] = (old is String && old.isNotEmpty) ? [old] : [''];
        changed = true;
      }
      if (targetWordsMap.containsKey(entry.key)) {
        final c = targetWordsMap[entry.key]!;
        if (we['word'] != c) { we['word'] = c; changed = true; }
      }
      if (nativeWords.containsKey(entry.key)) {
        final c = nativeWords[entry.key]!;
        if (we['translation'] != c) { we['translation'] = c; changed = true; }
      }
      if (!we.containsKey('examples_native')) {
        we['examples_native'] = nativeWordsMap[entry.key]?['examples'] ?? [''];
        changed = true;
      }
    }

    if (changed) {
      await UserManager.saveUserdata(username, userData);
    }
  }
}
import '../services/file_service.dart';
import 'user_manager.dart';

/// Vocabulary management — interface extracted from the former static
/// VocabManager class (point2, Commit A).
abstract class VocabManager {
  static const Map<int, int?> repeatIntervalDays = {
    1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: null,
  };

  Future<Map<String, dynamic>> loadLanguageDictFromDir(String langCode);
  List<Map<String, dynamic>> extractAllWordsFromLanguageDict(
      Map<String, dynamic> languageDict);
  Future<void> initVocabForUser(
      String username, Map<String, dynamic> languageDict);
  Future<void> migrateVocabForUser(String username);
}

/// Concrete implementation backed by [UserManager] and [FileService].
class VocabManagerImpl implements VocabManager {
  final UserManager _userManager;
  final FileService _fileService;

  VocabManagerImpl(this._userManager, this._fileService);

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(
      String langCode) async {
    return _fileService.loadLanguageDictFromDir(langCode);
  }

  @override
  List<Map<String, dynamic>> extractAllWordsFromLanguageDict(
      Map<String, dynamic> languageDict) {
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

  @override
  Future<void> initVocabForUser(
      String username, Map<String, dynamic> languageDict) async {
    final userData = await _userManager.loadUserdata(username);
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
    await _userManager.saveUserdata(username, userData);
  }

  @override
  Future<void> migrateVocabForUser(String username) async {
    final userData = await _userManager.loadUserdata(username);
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
      if (!we.containsKey('review_due')) {
        we['review_due'] = null;
        changed = true;
      }
      if (!we.containsKey('last_reviewed')) {
        we['last_reviewed'] = null;
        changed = true;
      }
      if (!we.containsKey('level')) {
        we['level'] = 0;
        changed = true;
      }
      if (!we.containsKey('examples')) {
        final old = we['example'] ?? '';
        we['examples'] = (old is String && old.isNotEmpty) ? [old] : [''];
        changed = true;
      }
      if (targetWordsMap.containsKey(entry.key)) {
        final c = targetWordsMap[entry.key]!;
        if (we['word'] != c) {
          we['word'] = c;
          changed = true;
        }
      }
      if (nativeWords.containsKey(entry.key)) {
        final c = nativeWords[entry.key]!;
        if (we['translation'] != c) {
          we['translation'] = c;
          changed = true;
        }
      }
      if (!we.containsKey('examples_native')) {
        we['examples_native'] = nativeWordsMap[entry.key]?['examples'] ?? [''];
        changed = true;
      }
    }

    for (final entry in vocab.entries) {
      final we = entry.value as Map<String, dynamic>;
      final level = we['level'] as int? ?? 0;
      final status = we['status']?.toString() ?? 'new';
      if (status != 'seen' || level < 1 || level >= 8) continue;

      final lastReviewedStr = we['last_reviewed']?.toString();
      if (lastReviewedStr == null || lastReviewedStr.isEmpty) continue;
      final lastReviewed = DateTime.tryParse(lastReviewedStr);
      if (lastReviewed == null) continue;

      final days = VocabManager.repeatIntervalDays[level];
      if (days == null) continue;
      final due = lastReviewed.add(Duration(days: days));
      final newDue =
          '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      if (we['review_due']?.toString() != newDue) {
        we['review_due'] = newDue;
        changed = true;
      }
    }

    if (changed) {
      await _userManager.saveUserdata(username, userData);
    }
  }
}

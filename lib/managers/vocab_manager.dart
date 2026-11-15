import '../models/app_models.dart';
import '../services/file_service.dart';
import 'user_manager.dart';

/// Vocabulary management — interface extracted from the former static
/// VocabManager class (point2, Commit A).
abstract class VocabManager {
  static const Map<int, int?> repeatIntervalDays = {
    1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: null,
  };

  Future<Map<String, dynamic>> loadLanguageDictFromDir(String langCode);
  List<LangDictWord> extractAllWordsFromLanguageDict(
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
  List<LangDictWord> extractAllWordsFromLanguageDict(
      Map<String, dynamic> languageDict) {
    final words = <LangDictWord>[];

    void recurse(dynamic data, String currentKey) {
      if (data is Map<String, dynamic>) {
        // New list-based verb schema: tense level has 'translations' list
        if (!data.containsKey('translation') &&
            !data.containsKey('word') &&
            data.containsKey('translations') &&
            data['translations'] is List) {
          final segments = currentKey.split('/');
          if (segments.length >= 2) {
            final verbName = segments[0];
            final tenseName = segments[1];
            final infinitive =
                (languageDict[verbName] is Map<String, dynamic>)
                    ? (languageDict[verbName] as Map<String, dynamic>)[
                                'infinitive']
                            ?.toString() ??
                        verbName.replaceAll('_', ' ')
                    : verbName.replaceAll('_', ' ');
            final translations = (data['translations'] as List)
                .map((e) => e.toString())
                .toList();
            final allExamples = data['examples'] as List?;
            for (var i = 0; i < translations.length; i++) {
              final wordKey = '${verbName}_${tenseName}_$i';
              final exList = <String>[];
              if (allExamples != null && i < allExamples.length) {
                final row = allExamples[i];
                if (row is List) exList.addAll(row.map((e) => e.toString()));
              }
              words.add(LangDictWord(
                key: wordKey,
                word: infinitive,
                translation: translations[i],
                examples: exList.isNotEmpty ? exList : [''],
              ));
            }
          }
          return;
        }

        // Legacy map-based schema: person-level objects with 'translation'
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
          words.add(LangDictWord(
            key: wordKey,
            word: wordText,
            translation: data['translation']?.toString() ?? '',
            examples: examples.isNotEmpty ? examples : [''],
          ));
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
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return;

    // Early-exit: vocab already initialized
    if (ud.vocab.isNotEmpty) return;

    var langDict = languageDict;
    if (langDict.isEmpty) {
      langDict = await loadLanguageDictFromDir(ud.mLang);
      if (langDict.isEmpty) return;
    }

    final targetWords = extractAllWordsFromLanguageDict(langDict);

    final nativeWords = <String, String>{};
    final nativeExamples = <String, List<String>>{};
    if (ud.mLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(ud.mLang);
      if (nativeDict.isNotEmpty) {
        for (final nw in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[nw.key] = nw.translation;
          nativeExamples[nw.key] = nw.examples;
        }
      }
    }

    final vocab = <String, VocabEntry>{};
    for (final tw in targetWords) {
      vocab[tw.key] = VocabEntry(
        key: tw.key,
        word: tw.translation,
        translation: nativeWords[tw.key] ?? tw.translation,
        examples: tw.examples,
        examplesNative: nativeExamples[tw.key] ?? [''],
      );
    }

    await _userManager.saveUserdata(username, ud.copyWith(vocab: vocab));
  }

  @override
  Future<void> migrateVocabForUser(String username) async {
    final ud = await _userManager.loadUserdata(username);
    if (ud == null) return;
    if (ud.vocab.isEmpty) return;

    final vocabMap = Map<String, VocabEntry>.from(ud.vocab);
    var changed = false;
    final targetLang = ud.mLang == 'de' ? 'en' : 'de';

    final targetWordsMap = <String, String>{};
    final targetDict = await loadLanguageDictFromDir(targetLang);
    if (targetDict.isNotEmpty) {
      for (final tw in extractAllWordsFromLanguageDict(targetDict)) {
        targetWordsMap[tw.key] = tw.translation;
      }
    }

    final nativeWords = <String, String>{};
    final nativeWordsMap = <String, LangDictWord>{};
    if (ud.mLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(ud.mLang);
      if (nativeDict.isNotEmpty) {
        for (final nw in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[nw.key] = nw.translation;
          nativeWordsMap[nw.key] = nw;
        }
      }
    }

    // Pass 1: sync word/translation/examples_native with dictionaries
    for (final key in vocabMap.keys.toList()) {
      var ve = vocabMap[key]!;

      // status based on level (only if still default 'new')
      if (ve.level > 0 && ve.status == 'new') {
        ve = ve.copyWith(status: 'seen');
        changed = true;
      }

      // word sync from target dictionary
      if (targetWordsMap.containsKey(key)) {
        final correctWord = targetWordsMap[key]!;
        if (ve.word != correctWord) {
          ve = ve.copyWith(word: correctWord);
          changed = true;
        }
      }

      // translation sync from native dictionary
      if (nativeWords.containsKey(key)) {
        final correctTrans = nativeWords[key]!;
        if (ve.translation != correctTrans) {
          ve = ve.copyWith(translation: correctTrans);
          changed = true;
        }
      }

      // examples_native sync from native dictionary
      if (nativeWordsMap.containsKey(key)) {
        final nw = nativeWordsMap[key]!;
        final nativeExamples = nw.examples;
        if (nativeExamples.isNotEmpty) {
          bool differ =
              ve.examplesNative.length != nativeExamples.length;
          if (!differ) {
            for (var i = 0; i < nativeExamples.length; i++) {
              if (ve.examplesNative[i] != nativeExamples[i]) {
                differ = true;
                break;
              }
            }
          }
          if (differ) {
            ve = ve.copyWith(examplesNative: nativeExamples);
            changed = true;
          }
        }
      }

      vocabMap[key] = ve;
    }

    // Pass 2: recalculate review_due for seen words
    for (final key in vocabMap.keys.toList()) {
      final ve = vocabMap[key]!;
      if (ve.status != 'seen' || ve.level < 1 || ve.level >= 8) continue;
      if (ve.lastReviewed == null || ve.lastReviewed!.isEmpty) continue;
      final lastReviewed = DateTime.tryParse(ve.lastReviewed!);
      if (lastReviewed == null) continue;

      final days = VocabManager.repeatIntervalDays[ve.level];
      if (days == null) continue;
      final due = lastReviewed.add(Duration(days: days));
      final newDue =
          '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      if (ve.reviewDue != newDue) {
        vocabMap[key] = ve.copyWith(reviewDue: newDue);
        changed = true;
      }
    }

    if (changed) {
      await _userManager.saveUserdata(
          username, ud.copyWith(vocab: vocabMap));
    }
  }
}

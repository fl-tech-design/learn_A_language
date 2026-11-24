import 'dart:developer' show log;

import '../models/app_models.dart';
import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
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
  /// Füllt den Wortschatz von [username] für die Zielsprache [langCode] mit
  /// vorhandenen Asset-Daten. [nativeLang] ist die Muttersprache und bestimmt
  /// die Übersetzungsrichtung (`translation`/`examplesNative`). Bestehende
  /// Einträge (Level/Status) bleiben unangetastet.
  Future<void> initVocabForUser(
      String username, String langCode, String nativeLang);
  /// Migriert/synchronisiert den Wortschatz von [username] für [langCode]
  /// gegen die aktuellen Asset-Dicts (Zielsprache [langCode],
  /// Übersetzungsrichtung [nativeLang]).
  Future<void> migrateVocabForUser(
      String username, String langCode, String nativeLang);
}

/// Concrete implementation backed by [UserManager] and [FileService].
class VocabManagerImpl implements VocabManager {
  final UserManager _userManager;
  final FileService _fileService;

  VocabManagerImpl(this._userManager, this._fileService);

  /// Lädt UserData, ohne dass eine korrupte Datei den Aufrufer crasht
  /// (Log + einmalige Bus-Meldung, Rückgabe `null` wie bei fehlender Datei).
  Future<UserData?> _loadSafe(String username) async {
    try {
      return await _userManager.loadUserdata(username);
    } on PersistenceException catch (e) {
      log('vocab_manager: Userdaten für $username unlesbar ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.userDataUnloadable);
      return null;
    }
  }

  /// Speichert UserData; Fehler werden geloggt und per Bus gemeldet, statt
  /// den Aufrufer (Login, main.dart, Init/Migration) crashen zu lassen.
  Future<void> _saveSafe(String username, UserData data) async {
    try {
      await _userManager.saveUserdata(username, data);
    } on PathRejectedException catch (e) {
      log('vocab_manager: Speichern für $username abgelehnt ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
    } on PersistenceException catch (e) {
      log('vocab_manager: Speichern für $username fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
    }
  }

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
      String username, String langCode, String nativeLang) async {
    final ud = await _loadSafe(username);
    if (ud == null || langCode.isEmpty) return;

    final langDict = await loadLanguageDictFromDir(langCode);
    if (langDict.isEmpty) return;

    // Zielsprache des Kurses (z. B. 'de', 'en', 'fr') – NICHT aus der
    // Muttersprache abgeleitet.
    final targetWords = extractAllWordsFromLanguageDict(langDict);

    // Übersetzungsrichtung über die Muttersprache.
    final nativeWords = <String, String>{};
    final nativeExamples = <String, List<String>>{};
    if (nativeLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(nativeLang);
      if (nativeDict.isNotEmpty) {
        for (final nw in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[nw.key] = nw.translation;
          nativeExamples[nw.key] = nw.examples;
        }
      }
    }

    // Bestehende Einträge UNVERÄNDERT behalten (Fortschritt/Level/Status),
    // nur fehlende Kurs-Wörter als neue Wörter ergänzen (idempotent; ersetzt
    // das frühere early-exit bei vollem vocab). Je Zielsprache getrennt.
    final langVocab = Map<String, VocabEntry>.from(
        ud.vocabByLang[langCode] ?? const <String, VocabEntry>{});
    var changed = false;
    for (final tw in targetWords) {
      if (langVocab.containsKey(tw.key)) continue;
      langVocab[tw.key] = VocabEntry(
        key: tw.key,
        word: tw.translation,
        translation: nativeWords[tw.key] ?? tw.translation,
        examples: tw.examples,
        examplesNative: nativeExamples[tw.key] ?? [''],
      );
      changed = true;
    }

    // Eingebettetes language-Feld einmalig leeren, damit künftig IMMER die
    // aktuellen Asset-Dicts als Quelle dienen (bisher übernahm es login).
    final clearLanguage = ud.language.isNotEmpty;
    if (changed || clearLanguage) {
      final vocabByLang =
          Map<String, Map<String, VocabEntry>>.from(ud.vocabByLang)
            ..[langCode] = langVocab;
      await _saveSafe(username, ud.copyWith(
        vocabByLang: vocabByLang,
        language: clearLanguage ? const {} : ud.language,
      ));
    }
  }

  @override
  Future<void> migrateVocabForUser(
      String username, String langCode, String nativeLang) async {
    final ud = await _loadSafe(username);
    if (ud == null) return;
    final langVocab = ud.vocabByLang[langCode];
    if (langVocab == null || langVocab.isEmpty) return;

    final vocabMap = Map<String, VocabEntry>.from(langVocab);
    var changed = false;

    final targetWordsMap = <String, String>{};
    final targetWordObjects = <String, LangDictWord>{};
    final targetDict = await loadLanguageDictFromDir(langCode);
    if (targetDict.isNotEmpty) {
      for (final tw in extractAllWordsFromLanguageDict(targetDict)) {
        targetWordsMap[tw.key] = tw.translation;
        targetWordObjects[tw.key] = tw;
      }
    }

    final nativeWords = <String, String>{};
    final nativeWordsMap = <String, LangDictWord>{};
    if (nativeLang.isNotEmpty) {
      final nativeDict = await loadLanguageDictFromDir(nativeLang);
      if (nativeDict.isNotEmpty) {
        for (final nw in extractAllWordsFromLanguageDict(nativeDict)) {
          nativeWords[nw.key] = nw.translation;
          nativeWordsMap[nw.key] = nw;
        }
      }
    }

    // Pass 0: Alte Key-Formate (z. B. 'i_want', 'he_she_it_is' aus der
    // Kivy-Ära) auf das neue Schema ('<verb>_<tense>_<person>') mappen.
    // Zuordnung über Wort + Übersetzung gegen das aktuelle Wörterbuch;
    // Level/Status/Fälligkeitsdaten der Bestands-Einträge bleiben erhalten.
    if (targetWordsMap.isNotEmpty) {
      final wordToKeys = <String, Set<String>>{};
      for (final e in targetWordsMap.entries) {
        wordToKeys.putIfAbsent(e.value, () => <String>{}).add(e.key);
      }
      final transToKeys = <String, Set<String>>{};
      for (final e in nativeWords.entries) {
        transToKeys.putIfAbsent(e.value, () => <String>{}).add(e.key);
      }

      for (final oldKey in vocabMap.keys.toList()) {
        if (targetWordsMap.containsKey(oldKey)) continue; // bereits neues Schema
        final ve = vocabMap[oldKey]!;
        final wordMatches = wordToKeys[ve.word] ?? const <String>{};
        final transMatches = transToKeys[ve.translation] ?? const <String>{};
        final candidates = wordMatches.intersection(transMatches);
        if (candidates.length != 1) continue; // nicht eindeutig -> behalten
        final newKey = candidates.first;
        final tw = targetWordObjects[newKey];
        final nw = nativeWordsMap[newKey];
        final examples =
            (tw != null && tw.examples.isNotEmpty) ? tw.examples : ve.examples;
        final examplesNative = (nw != null && nw.examples.isNotEmpty)
            ? nw.examples
            : ve.examplesNative;
        vocabMap.remove(oldKey);
        vocabMap[newKey] = ve.copyWith(
          key: newKey,
          word: tw?.translation ?? ve.word,
          translation: nativeWords[newKey] ?? ve.translation,
          examples: examples,
          examplesNative: examplesNative,
        );
        changed = true;
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
      final vocabByLang =
          Map<String, Map<String, VocabEntry>>.from(ud.vocabByLang)
            ..[langCode] = vocabMap;
      await _saveSafe(username, ud.copyWith(vocabByLang: vocabByLang));
    }
  }
}

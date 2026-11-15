import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_manager.dart';
import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/services/file_service.dart';

/// Full fake that throws on unexpected calls.
class _FakeFileService implements FileService {
  final Map<String, Map<String, dynamic>> languageDictData;

  _FakeFileService(this.languageDictData);

  @override
  Future<String> get appDir => throw UnimplementedError('appDir');

  @override
  Future<void> initialize() => throw UnimplementedError('initialize');

  @override
  Future<Map<String, dynamic>> loadJson(String relativePath) =>
      throw UnimplementedError('loadJson');

  @override
  Future<void> saveJson(
          String relativePath, Map<String, dynamic> data) =>
      throw UnimplementedError('saveJson');

  @override
  Future<void> updateJsonKey(
          String relativePath, String key, Object? value) =>
      throw UnimplementedError('updateJsonKey');

  @override
  Future<Map<String, dynamic>> loadBundledJson(String assetPath) =>
      throw UnimplementedError('loadBundledJson');

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(
      String langCode) async {
    return languageDictData[langCode] ?? {};
  }
}

/// Full fake that counts saveUserdata calls; throws on unexpected.
class _FakeUserManager implements UserManager {
  int saveCount = 0;
  UserData? _stored;
  String? _storedUsername;

  UserData? get lastSaved => _stored;

  @override
  Future<String> createUserFile(
          String username, String mLang,
          Map<String, dynamic> languageDict) =>
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
  Future<void> changeLoginState(bool newState) =>
      throw UnimplementedError('changeLoginState');

  @override
  Future<void> setLoggedUname(String loggedUname) =>
      throw UnimplementedError('setLoggedUname');
}

/// Minimal dict mimicking the new list-based verb schema.
Map<String, dynamic> _tinyDict(String word, String trans, String example) => {
      'to_go': {
        'infinitive': word,
        'present': {
          'translations': [trans, '$word you', '', '', '', ''],
          'examples': [
            [example, '', ''],
            ['', '', ''],
            ['', '', ''],
            ['', '', ''],
            ['', '', ''],
            ['', '', ''],
          ],
          'audio': [[], [], [], [], [], []],
        },
      },
    };

void main() {
  // ── Test (a) – extractAllWordsFromLanguageDict with real JSON ─────
  group('extractAllWordsFromLanguageDict', () {
    test('echtes de_to_go.json → 18 Wörter + Felder korrekt', () {
      const path = 'assets/language_dict/de/de_to_go.json';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'cwd=${Directory.current.path}, expected $path');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final mgr = VocabManagerImpl(
          _FakeUserManager(), _FakeFileService({}));
      final words = mgr.extractAllWordsFromLanguageDict(json);

      expect(words.length, 18);
      final iWent = words.firstWhere((w) => w.key == 'i_went');
      expect(iWent.word, 'i went');
      expect(iWent.translation, 'ich ging');
      expect(iWent.examples, ['Ich ging in den Park.']);

      final theyWillGo = words.firstWhere((w) => w.key == 'they_will_go');
      expect(theyWillGo.word, 'they will go');
      expect(theyWillGo.translation, 'sie werden gehen');
      expect(theyWillGo.examples, ['Sie werden zur Party gehen.']);
    });
test('neues Listen-Schema de_to_be.json → 18 Wörter, Keys, 3 examples',
        () {
      const path = 'assets/language_dict/de/de_to_be.json';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'cwd=${Directory.current.path}, expected $path');
      final verbJson =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      // Simulate loadLanguageDictFromDir wrapping (key = file name suffix)
      final langDict = <String, dynamic>{'to_be': verbJson};

      final mgr =
          VocabManagerImpl(_FakeUserManager(), _FakeFileService({}));
      final words = mgr.extractAllWordsFromLanguageDict(langDict);

      expect(words.length, 18);

      // past index 0
      final past0 = words.firstWhere((w) => w.key == 'to_be_past_0');
      expect(past0.word, 'sein');
      expect(past0.translation, 'ich war');
      expect(past0.examples, ['Ich war im Park.', '', '']);

      // present index 5
      final pres5 = words.firstWhere((w) => w.key == 'to_be_present_5');
      expect(pres5.word, 'sein');
      expect(pres5.translation, 'sie sind');
      expect(pres5.examples, ['Sie sind freundlich.', '', '']);

      // future index 2
      final fut2 = words.firstWhere((w) => w.key == 'to_be_future_2');
      expect(fut2.word, 'sein');
      expect(fut2.translation, 'er/sie/es wird sein');
      expect(fut2.examples, ['Er wird hier sein.', '', '']);
    });
  });

  // ── Test (b) – initVocabForUser idempotent ─────────────────────
  group('initVocabForUser', () {
    test('zweiter Aufruf speichert nicht erneut (early-exit)', () async {
      final userMgr = _FakeUserManager();
      final fs = _FakeFileService({
        'en': _tinyDict('go', 'gehen', 'Ich gehe.'),
        'de': _tinyDict('gehen', 'go', 'I go.'),
      });
      final mgr = VocabManagerImpl(userMgr, fs);

      // A user with empty vocab
      await userMgr.saveUserdata('test', UserData(
        uName: 'test',
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        vocab: const {},
      ));
      userMgr.saveCount = 0;

      // 1st call: should init and save
      await mgr.initVocabForUser('test', {});
      expect(userMgr.saveCount, 1);
      final afterFirst = userMgr.lastSaved;
      expect(afterFirst!.vocab.length, 6);

      // 2nd call: early-exit, no save
      await mgr.initVocabForUser('test', {});
      expect(userMgr.saveCount, 1);
    });
  });

  // ── Test (c) – migrateVocabForUser idempotent ─────────────────────
  group('migrateVocabForUser', () {
    test('zweiter Aufruf ohne Änderungen speichert nicht', () async {
      final userMgr = _FakeUserManager();
      final fs = _FakeFileService({
        'en': _tinyDict('go', 'gehen', 'Ich gehe.'),
        'de': _tinyDict('gehen', 'go', 'I go.'),
      });
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', UserData(
        uName: 'test',
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        vocab: {
          'to_go_present_0': VocabEntry(
            key: 'to_go_present_0',
            word: 'gehen',
            translation: 'go',
            examples: const ['Ich gehe.', '', ''],
            examplesNative: const ['I go.', '', ''],
            level: 1,
            status: 'seen',
            lastReviewed: '2026-01-01',
            reviewDue: '2026-01-02',
          ),
        },
      ));

      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test');
      expect(userMgr.saveCount, 0);

      await mgr.migrateVocabForUser('test');
      expect(userMgr.saveCount, 0);
    });

    test('detektiert word-Update aus Dict und speichert', () async {
      final userMgr = _FakeUserManager();
      final fs = _FakeFileService({
        'en': _tinyDict('go', 'gehen', 'Ich gehe.'),
        'de': _tinyDict('gehen', 'go', 'I go.'),
      });
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', UserData(
        uName: 'test',
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        vocab: {
          'to_go_present_0': VocabEntry(
            key: 'to_go_present_0',
            word: 'OLD_WORD',
            translation: 'gehen',
            examples: const [],
            examplesNative: const [],
            level: 1,
            status: 'seen',
            lastReviewed: '2026-01-01',
            reviewDue: '2026-01-02',
          ),
        },
      ));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test');
      expect(userMgr.saveCount, 1);

      await mgr.migrateVocabForUser('test');
      expect(userMgr.saveCount, 1);
    });
  });
}
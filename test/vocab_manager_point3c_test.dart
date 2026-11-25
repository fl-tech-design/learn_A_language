import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/models/app_models.dart';

import 'helpers/fakes.dart';

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

/// Dictionary-Mix, wie ihn initVocabForUser/migrateVocabForUser erwarten.
/// - en ist die Zielsprache (mLang 'de'), de die Muttersprache.
(Map<String, Map<String, dynamic>>, Map<String, Map<String, dynamic>>)
    _dictMix() {
  final target = <String, Map<String, dynamic>>{
    'en': _tinyDict('go', 'gehen', 'Ich gehe.'),
    'de': _tinyDict('gehen', 'go', 'I go.'),
  };
  return (target, target);
}

UserData _userData(String username, Map<String, VocabEntry> vocab) => UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocabByLang: {'en': vocab},
    );

VocabEntry _entry({
  String key = 'to_go_present_0',
  String word = 'gehen',
  String translation = 'go',
  List<String> examples = const ['Ich gehe.', '', ''],
  List<String> examplesNative = const ['I go.', '', ''],
  int level = 1,
  String status = 'seen',
  String? lastReviewed = '2026-01-01',
  String? reviewDue = '2026-01-02',
}) =>
    VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: examples,
      examplesNative: examplesNative,
      level: level,
      status: status,
      lastReviewed: lastReviewed,
      reviewDue: reviewDue,
    );

void main() {
  // ── Test (a) – extractAllWordsFromLanguageDict with real JSON ─────
  group('extractAllWordsFromLanguageDict', () {
    test('echtes de_to_go.json (neues Schema) → 18 Wörter + Keys', () {
      const path = 'assets/language_dict/de/de_to_go.json';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'cwd=${Directory.current.path}, expected $path');
      final verbJson =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final langDict = <String, dynamic>{'to_go': verbJson};

      final mgr = VocabManagerImpl(FakeUserManager(), FakeFileService());
      final words = mgr.extractAllWordsFromLanguageDict(langDict);

      expect(words.length, 18);

      final past0 = words.firstWhere((w) => w.key == 'to_go_past_0');
      expect(past0.word, 'gehen');
      expect(past0.translation, 'ich ging');
      expect(past0.examples, ['Ich ging in den Park.', '', '']);

      final fut5 = words.firstWhere((w) => w.key == 'to_go_future_5');
      expect(fut5.word, 'gehen');
      expect(fut5.translation, 'sie werden gehen');
      expect(fut5.examples, ['Sie werden zur Party gehen.', '', '']);
    });

    test('neues Listen-Schema de_to_be.json → 18 Wörter, Keys, 3 examples',
        () {
      const path = 'assets/language_dict/de/de_to_be.json';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'cwd=${Directory.current.path}, expected $path');
      final verbJson =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final langDict = <String, dynamic>{'to_be': verbJson};

      final mgr = VocabManagerImpl(FakeUserManager(), FakeFileService());
      final words = mgr.extractAllWordsFromLanguageDict(langDict);

      expect(words.length, 18);

      final past0 = words.firstWhere((w) => w.key == 'to_be_past_0');
      expect(past0.word, 'sein');
      expect(past0.translation, 'ich war');
      expect(past0.examples, ['Ich war im Park.', '', '']);

      final pres5 = words.firstWhere((w) => w.key == 'to_be_present_5');
      expect(pres5.word, 'sein');
      expect(pres5.translation, 'sie sind');
      expect(pres5.examples, ['Sie sind freundlich.', '', '']);

      final fut2 = words.firstWhere((w) => w.key == 'to_be_future_2');
      expect(fut2.word, 'sein');
      expect(fut2.translation, 'er/sie/es wird sein');
      expect(fut2.examples, ['Er wird hier sein.', '', '']);
    });

    test('Legacy Map-Schema (alt) → 2 Wörter aus inline Fixture', () {
      final oldDict = <String, dynamic>{
        'old_verb': {
          'infinitive': 'test',
          'level': 0,
          'present': {
            'i_test': {
              'translation': 'ich teste',
              'level': 0,
              'example': {'ex': 'Beispiel'},
            },
            'you_test': {
              'translation': 'du testest',
              'level': 0,
              'example': {},
            },
          },
        },
      };

      final mgr = VocabManagerImpl(FakeUserManager(), FakeFileService());
      final words = mgr.extractAllWordsFromLanguageDict(oldDict);

      expect(words.length, 2);
      expect(words[0].key, 'i_test');
      expect(words[0].word, 'i test');
      expect(words[0].translation, 'ich teste');
      expect(words[0].examples, ['Beispiel']);
    });
  });

  // ── Test (b) – initVocabForUser idempotent ─────────────────────
  group('initVocabForUser', () {
    test('zweiter Aufruf speichert nicht erneut (early-exit)', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata(
          'test', _userData('test', const {}));
      userMgr.saveCount = 0;

      await mgr.initVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 1);
      final afterFirst = userMgr.lastSaved;
      expect(afterFirst!.vocabByLang['en']!.length, 6);

      await mgr.initVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 1);
    });

    test('ergänzt fehlende Kurs-Wörter und behält bestehende Einträge',
        () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      // Nur ein Eintrag vorhanden; die übrigen 5 des Mini-Dicts fehlen.
      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(level: 0, status: 'new'),
      }));
      userMgr.saveCount = 0;

      await mgr.initVocabForUser('test', 'en', 'de');

      final saved = userMgr.lastSaved!;
      final savedVocab = saved.vocabByLang['en']!;
      expect(savedVocab.length, 6);
      expect(savedVocab.containsKey('to_go_present_0'), true);
      expect(savedVocab['to_go_present_1']!.level, 0);
      expect(savedVocab['to_go_present_1']!.status, 'new');
      expect(userMgr.saveCount, 1);
    });
  });

  // ── Test (c) – migrateVocabForUser idempotent ─────────────────────
  group('migrateVocabForUser', () {
    test('zweiter Aufruf ohne Änderungen speichert nicht', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 0);

      await mgr.migrateVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 0);
    });

    test('mappt alte Keys (Kivy-Schema) auf neues Schema und erhält Fortschritt',
        () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      // Alter Key aus der Kivy-Ära. Die _entry-Defaults (word 'gehen',
      // translation 'go', status 'seen') entsprechen genau dem
      // Wörterbuch-Eintrag 'to_go_present_0' (en: 'gehen', de: 'go').
      await userMgr.saveUserdata('test', _userData('test', {
        'i_want': _entry(level: 3, reviewDue: '2026-01-04'),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      final saved = userMgr.lastSaved!;
      final vocab = saved.vocabByLang['en']!;
      expect(vocab.containsKey('i_want'), false);
      expect(vocab.containsKey('to_go_present_0'), true);
      final ve = vocab['to_go_present_0']!;
      expect(ve.level, 3);
      expect(ve.status, 'seen');
      expect(ve.reviewDue, '2026-01-04');
      expect(userMgr.saveCount, 1);
    });

    test('detektiert word-Update aus Dict und speichert', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(word: 'OLD_WORD'),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 1);
      expect(
          userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!.word,
          'gehen');

      await mgr.migrateVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 1);
    });

    test('synct translation aus Muttersprachen-Dict', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(translation: 'FALSCH'),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 1);
      expect(userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!
          .translation, 'go');
    });

    test('synct examplesNative aus Muttersprachen-Dict', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(examplesNative: ['alt1', 'alt2']),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 1);
      expect(userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!
          .examplesNative, ['I go.', '', '']);
    });

    test('stuft status new→seen, wenn level > 0', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(level: 2, status: 'new'),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 1);
      expect(
          userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!.status,
          'seen');
    });

    test('hebt gelesene Woerter mit level 0 auf level 1 (Ticket #61)', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        // Bestandswort aus der Kivy-Ära: gelesen (status seen ist der
        // _entry-Default), aber level 0.
        'to_go_present_0': _entry(level: 0),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 1);
      final ve = userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!;
      expect(ve.level, 1,
          reason: 'gelesen (status seen) bedeutet per Semantik „in Arbeit" '
              '→ mindestens Level 1');
      expect(ve.status, 'seen');

      // Idempotent: zweiter Lauf ändert nichts mehr.
      userMgr.saveCount = 0;
      await mgr.migrateVocabForUser('test', 'en', 'de');
      expect(userMgr.saveCount, 0);
    });

    test('laesst ungesehene Woerter (status new, level 0) unangetastet '
        '(Ticket #61)', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0': _entry(level: 0, status: 'new'),
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 0,
          reason: 'kein Fortschritt nötig – status new bleibt new, '
              'level 0 bleibt level 0');
      expect(userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!.level, 0);
      expect(userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!.status,
          'new');
    });

    test('berechnet reviewDue aus lastReviewed neu (Pass 2)', () async {
      final userMgr = FakeUserManager();
      final dict = _dictMix();
      final fs = FakeFileService(languageDicts: dict.$1);
      final mgr = VocabManagerImpl(userMgr, fs);

      await userMgr.saveUserdata('test', _userData('test', {
        'to_go_present_0':
            _entry(reviewDue: '2026-12-31'), // veralteter Wert
      }));
      userMgr.saveCount = 0;

      await mgr.migrateVocabForUser('test', 'en', 'de');

      expect(userMgr.saveCount, 1);
      expect(userMgr.lastSaved!.vocabByLang['en']!['to_go_present_0']!
          .reviewDue, '2026-01-02');
    });
  });

  group('initVocabForUser – eingebettetes language-Feld (Ticket 3)', () {
    // Alt-User: mLang 'de' → Zielsprache 'en'; dict liefert to_go_present_0..5.
    (VocabManagerImpl, FakeUserManager, FakeFileService) setup({
      required Map<String, VocabEntry> vocab,
      Map<String, dynamic> language = const {'to_go': {'infinitive': 'go'}},
    }) {
      final fs = FakeFileService(languageDicts: {
        'en': _tinyDict('go', 'gehen', 'Ich gehe.'),
        'de': _tinyDict('gehen', 'go', 'I go.'),
      });
      final userMgr = FakeUserManager();
      userMgr.seed('test', UserData(
            uName: 'test',
            mLang: 'de',
            progress: const {},
            learnedLanguages: const [],
            language: language,
            vocabByLang: {'en': vocab},
          ));
      userMgr.saveCount = 0;
      return (VocabManagerImpl(userMgr, fs), userMgr, fs);
    }

    test('bekommt neue Asset-Wörter, erhält Fortschritt, leert language',
        () async {
      final (mgr, userMgr, _) = setup(vocab: {
        'to_go_present_0': _entry(
          level: 3,
          reviewDue: '2026-01-04',
        ),
      });

      await mgr.initVocabForUser('test', 'en', 'de');

      final saved = userMgr.getUser('test')!;
      // language wird geleert (einmalig) – künftig kommen Wörter nur noch aus
      // den aktuellen Asset-Dicts.
      expect(saved.language, isEmpty);
      // Bestehender Fortschritt bleibt unverändert erhalten.
      final e0 = saved.vocabByLang['en']!['to_go_present_0']!;
      expect(e0.level, 3);
      expect(e0.status, 'seen');
      expect(e0.reviewDue, '2026-01-04');
      // Neue Asset-Wörter werden ergänzt.
      expect(saved.vocabByLang['en']!.containsKey('to_go_present_1'), isTrue);
      expect(saved.vocabByLang['en']!.length, 6);
      expect(userMgr.saveCount, 1);
    });

    test('leert language auch, wenn vocab bereits vollständig ist', () async {
      final fullVocab = {
        for (var i = 0; i < 6; i++)
          'to_go_present_$i': _entry(key: 'to_go_present_$i'),
      };
      final (mgr, userMgr, _) = setup(vocab: fullVocab);

      await mgr.initVocabForUser('test', 'en', 'de');

      final saved = userMgr.getUser('test')!;
      expect(saved.language, isEmpty);
      // Keine neuen Wörter nötig, aber das Feld wird trotzdem geleert.
      expect(saved.vocabByLang['en']!.length, 6);
      expect(userMgr.saveCount, 1);
    });
  });
}

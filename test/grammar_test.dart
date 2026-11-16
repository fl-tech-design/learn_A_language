import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/grammar_manager.dart';
import 'package:learn_a_language/models/grammar_models.dart';

import 'helpers/fakes.dart';

GrammarDocument _realDoc() {
  const path = 'assets/grammar/grammar_de_en.json';
  final file = File(path);
  expect(file.existsSync(), isTrue,
      reason: 'cwd=${Directory.current.path}, expected $path');
  return GrammarDocument.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

void main() {
  group('GrammarDocument – echtes Asset', () {
    test('lädt Schema-Informationen und Dokument-Struktur korrekt', () {
      final doc = _realDoc();
      expect(doc.schemaVersion, '1.0.0');
      expect(doc.framework, 'CEFR');
      expect(doc.levels, ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
      expect(doc.direction['l1'], 'de');
      expect(doc.direction['l2'], 'en');
      expect(doc.uiLanguages, contains('de'));
      expect(doc.uiLanguages, contains('en'));
      expect(doc.levelsInfo.length, 6);
      expect(doc.categories.length, greaterThan(0));
      expect(doc.blocks.length, greaterThan(0));
    });

    test('jede Kategorie hat mindestens einen Block', () {
      final doc = _realDoc();
      for (final category in doc.sortedCategories) {
        expect(doc.blocksOfCategory(category.id), isNotEmpty,
            reason: 'Kategorie ${category.id} ohne Blöcke');
      }
    });

    test('sortedCategories sortiert nach order-Feld', () {
      final doc = _realDoc();
      final sorted = doc.sortedCategories;
      expect(sorted.map((c) => c.id).take(3).toList(),
          ['sentence_structure', 'verbs_tenses', 'questions_negation']);
    });

    test('blocksOfCategory filtert und sortiert nach order', () {
      final doc = _realDoc();
      final blocks = doc.blocksOfCategory('sentence_structure');
      expect(blocks, isNotEmpty);
      expect(blocks.every((b) => b.category == 'sentence_structure'), isTrue);
      for (var i = 1; i < blocks.length; i++) {
        expect(blocks[i].order, greaterThanOrEqualTo(blocks[i - 1].order));
      }
    });

    test('Blöcke erfüllen das Schema (Pflichtfelder gefüllt)', () {
      final doc = _realDoc();
      for (final b in doc.blocks) {
        expect(b.id, isNotEmpty);
        expect(b.level, isNotEmpty);
        expect(b.category, isNotEmpty);
        expect(b.title.pick('de'), isNotNull);
        expect(b.summary.pick('de'), isNotNull);
        expect(b.explanation.pick('de'), isNotNull);
      }
      expect(doc.blocks.any((b) => b.pitfall != null), isTrue);
      expect(doc.blocks.any((b) => b.quickCheck != null), isTrue);
    });
  });

  group('LocalizedText.pick', () {
    test('liefert die gewünschte Sprache oder den ersten Fallback', () {
      const text = LocalizedText({'de': 'Hallo', 'en': 'Hello'});
      expect(text.pick('de'), 'Hallo');
      expect(text.pick('en'), 'Hello');
      expect(text.pick('fr'), 'Hallo');
      expect(const LocalizedText({}).pick('de'), isNull);
    });
  });

  group('GrammarExample.pick', () {
    test('fällt bei leerem Text auf die andere Sprache zurück', () {
      const emptyDe = GrammarExample(de: '', en: 'Hello');
      expect(emptyDe.pick('de'), 'Hello');
      expect(emptyDe.pick('en'), 'Hello');

      const emptyEn = GrammarExample(de: 'Hallo', en: '');
      expect(emptyEn.pick('de'), 'Hallo');
      expect(emptyEn.pick('en'), 'Hallo');
    });

    test('fromJson mit kaputten Daten → leere Werte', () {
      final ex = GrammarExample.fromJson('kaputt');
      expect(ex.de, '');
      expect(ex.en, '');
      expect(ex.hint, isNull);
    });
  });

  group('GrammarManagerImpl', () {
    test('lädt und cached das Dokument', () async {
      final fs = FakeFileService(bundled: {
        'schema_version': '9.9.9',
        'content_version': '123',
        'framework': 'CEFR',
        'levels': ['A1'],
        'direction': {'l1': 'de', 'l2': 'en'},
        'ui_languages': ['de'],
        'levels_info': const [],
        'categories': const [],
        'blocks': const [],
      });
      final mgr = GrammarManagerImpl(fs);

      final first = await mgr.load();
      final second = await mgr.load();

      expect(first.schemaVersion, '9.9.9');
      expect(first.direction['l2'], 'en');
      expect(identical(first, second), isTrue);
      expect(fs.bundledLoadCount, 1);
    });
  });
}

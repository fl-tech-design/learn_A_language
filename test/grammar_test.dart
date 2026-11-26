import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/grammar_manager.dart';
import 'package:learn_a_language/models/grammar_models.dart';

import 'helpers/fakes.dart';

// Seit der Sprachpaket-Auslagerung (Ticket #68) sind die echten Grammar-JSONs
// NICHT mehr Teil des App-Bundles, sondern kommen als nachinstallierbare
// Sprachpakete (PackManager). Diese Gruppe prüft deshalb die Model-/Schema-Logik
// anhand einer repräsentativen Inline-Fixture statt eines entfernten Bundle-Assets.
GrammarDocument _fixtureDoc() {
  Map<String, Object?> lr(String de, String en) => {'de': de, 'en': en};

  Map<String, Object?> block(String id, String category, int order,
          {bool pitfall = false, bool quickCheck = false}) =>
      {
        'id': id,
        'level': 'A1',
        'category': category,
        'order': order,
        'title': lr('Titel $id', 'Title $id'),
        'summary': lr('Zusammenfassung $id', 'Summary $id'),
        'explanation': lr('Erklärung $id', 'Explanation $id'),
        if (pitfall)
          'pitfall': {
            'wrong': 'falsch',
            'correct': 'richtig',
            'why': lr('Weil…', 'Because…'),
          },
        if (quickCheck)
          'quick_check': {
            'task': lr('Aufgabe?', 'Task?'),
            'solution': 'lösung',
            'accepted': ['alternative'],
          },
      };

  return GrammarDocument.fromJson({
    'schema_version': '1.0.0',
    'content_version': '1',
    'framework': 'CEFR',
    'levels': ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
    'direction': {'l1': 'de', 'l2': 'en'},
    'ui_languages': ['de', 'en'],
    'levels_info': [
      for (final l in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'])
        {
          'level': l,
          'title': lr('$l Titel', '$l title'),
          'can_do': lr('$l kann …', '$l can …'),
        },
    ],
    'categories': [
      {
        'id': 'sentence_structure',
        'order': 1,
        'title': lr('Satzbau', 'Sentence structure'),
        'levels': ['A1'],
      },
      {
        'id': 'verbs_tenses',
        'order': 2,
        'title': lr('Verben & Zeiten', 'Verbs & tenses'),
        'levels': ['A1'],
      },
      {
        'id': 'questions_negation',
        'order': 3,
        'title': lr('Fragen & Verneinung', 'Questions & negation'),
        'levels': ['A1'],
      },
    ],
    'blocks': [
      block('ss_1', 'sentence_structure', 1, pitfall: true),
      block('ss_2', 'sentence_structure', 2, quickCheck: true),
      block('vt_1', 'verbs_tenses', 1),
      block('qn_1', 'questions_negation', 1),
    ],
  });
}

void main() {
  group('GrammarDocument – repräsentative Fixture', () {
    test('lädt Schema-Informationen und Dokument-Struktur korrekt', () {
      final doc = _fixtureDoc();
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
      final doc = _fixtureDoc();
      for (final category in doc.sortedCategories) {
        expect(doc.blocksOfCategory(category.id), isNotEmpty,
            reason: 'Kategorie ${category.id} ohne Blöcke');
      }
    });

    test('sortedCategories sortiert nach order-Feld', () {
      final doc = _fixtureDoc();
      final sorted = doc.sortedCategories;
      expect(sorted.map((c) => c.id).take(3).toList(),
          ['sentence_structure', 'verbs_tenses', 'questions_negation']);
    });

    test('blocksOfCategory filtert und sortiert nach order', () {
      final doc = _fixtureDoc();
      final blocks = doc.blocksOfCategory('sentence_structure');
      expect(blocks, isNotEmpty);
      expect(blocks.every((b) => b.category == 'sentence_structure'), isTrue);
      for (var i = 1; i < blocks.length; i++) {
        expect(blocks[i].order, greaterThanOrEqualTo(blocks[i - 1].order));
      }
    });

    test('Blöcke erfüllen das Schema (Pflichtfelder gefüllt)', () {
      final doc = _fixtureDoc();
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
      final fs = FakeFileService(store: {
        'grammar/grammar_de/grammar_de_en.json': {
          'schema_version': '9.9.9',
          'content_version': '123',
          'framework': 'CEFR',
          'levels': ['A1'],
          'direction': {'l1': 'de', 'l2': 'en'},
          'ui_languages': ['de'],
          'levels_info': const [],
          'categories': const [],
          'blocks': const [],
        },
      });
      final mgr = GrammarManagerImpl(fs);

      final first = await mgr.load();
      final second = await mgr.load();

      expect(first.schemaVersion, '9.9.9');
      expect(first.direction['l2'], 'en');
      expect(identical(first, second), isTrue);
    });
  });
}

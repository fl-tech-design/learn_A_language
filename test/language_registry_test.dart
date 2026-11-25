import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/language_registry.dart';

/// Fester, gültiger Mini-Sprachkatalog für die Lade-Tests.
Map<String, dynamic> miniConfig({bool korrupt = false}) => {
      'languages': [
        {
          'code': 'de',
          'flagAsset': 'assets/images/flag_germany.png',
          'labelKey': 'german',
          'nameDe': 'Deutsch',
          'aliases': ['deutsch', 'german'],
          'ui': true,
          'seed': true,
          'course': true,
        },
        {
          'code': 'xx',
          'flagAsset': 'assets/images/flag_new.png',
          'labelKey': 'new',
          'nameDe': 'Neu',
          'aliases': ['neu', 'new'],
          'ui': false,
          'seed': false,
          'course': true,
        },
        if (korrupt)
          {
            'code': 42, // absichtlich ungültig → ganze Config verwerfen
          },
      ],
    };

void main() {
  setUp(resetLanguageRegistry);

  group('language_registry – datengetrieben (Ticket #52)', () {
    test('Defaults ohne Config: Katalog wie vor dem Umbau', () {
      expect(languageConfigApplied, isFalse);
      expect(dictLanguageCodes, {'de', 'en', 'fr'});
      expect(courseCandidateCodes, [
        'de', 'en', 'fr', 'es', 'ru', 'el', 'it', 'pt',
      ]);
      expect(appLanguages.map((c) => c.code).toList(),
          ['de', 'en', 'es', 'fr', 'ru', 'el']);
      expect(courseLanguageName('it'), 'Italienisch');
      expect(courseFlagAsset('pt'), 'assets/images/flag_por.png');
      expect(languageCodeForName('Englisch'), 'en');
    });

    test('neue Sprache nur per Config-Eintrag – ohne Codeänderung', () async {
      await loadLanguageConfig(assetLoader: (_) async => miniConfig());

      expect(languageConfigApplied, isTrue);
      // 'xx' wird Kurs-Kandidat (Copy + Discovery) …
      expect(courseCandidateCodes, contains('xx'));
      // … bleibt aber KEINE UI-Sprache (ui: false, keine l10n-Datei).
      expect(appLanguages.map((c) => c.code), isNot(contains('xx')));
      expect(dictLanguageCodes, {'de'});
      // Name, Flagge und Namensauflösung aus der Config.
      expect(courseLanguageName('xx'), 'Neu');
      expect(courseFlagAsset('xx'), 'assets/images/flag_new.png');
      expect(languageCodeForName('new'), 'xx');
      expect(languageCodeForName('New'), 'xx');

      // Copy-Liste enthält die neue Sprache (Akzeptanzkriterium 1) und nur die
      // in der Config gelisteten Kurs-Kandidaten (hier de + xx).
      final files = buildCourseDictFiles();
      expect(files, contains('language_dict/xx/xx_to_go.json'));
      expect(files, contains('language_dict/de/de_to_go.json'));
      expect(files, isNot(contains('language_dict/it/it_to_go.json')));
    });

    test('ungültige Config wird verworfen – Defaults bleiben aktiv', () async {
      await loadLanguageConfig(assetLoader: (_) async => miniConfig(korrupt: true));

      expect(languageConfigApplied, isFalse);
      expect(courseCandidateCodes, [
        'de', 'en', 'fr', 'es', 'ru', 'el', 'it', 'pt',
      ]);
      expect(dictLanguageCodes, {'de', 'en', 'fr'});
    });

    test('Config-Datei fehlt (leere Map) → Defaults bleiben aktiv', () async {
      await loadLanguageConfig(assetLoader: (_) async => const {});

      expect(languageConfigApplied, isFalse);
      expect(dictLanguageCodes, {'de', 'en', 'fr'});
    });

    test('resetLanguageRegistry stellt eingebettete Defaults wieder her',
        () async {
      await loadLanguageConfig(assetLoader: (_) async => miniConfig());
      expect(languageConfigApplied, isTrue);

      resetLanguageRegistry();

      expect(languageConfigApplied, isFalse);
      expect(courseCandidateCodes, [
        'de', 'en', 'fr', 'es', 'ru', 'el', 'it', 'pt',
      ]);
    });
  });
}

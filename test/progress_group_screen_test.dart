import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/models/language_registry.dart';
import 'package:learn_a_language/screens/progress_group_screen.dart';

import 'helpers/fakes.dart';

UserData _userData(String username, List<VocabEntry> words,
        {String lang = 'de'}) =>
    UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocabByLang: {lang: {for (final w in words) w.key: w}},
    );

VocabEntry _entry(String key, {int level = 0, String? word}) => VocabEntry(
      key: key,
      word: word ?? key,
      translation: 'übersetzung',
      examples: const [],
      examplesNative: const [],
      level: level,
      status: level == 0 ? 'new' : 'seen',
      reviewDue: level == 0 ? null : '2020-01-01',
    );

/// Start-Home, das nach Tipp auf „OPEN“ `/progress_group` mit [categoryId]
/// als Argument öffnet.
class _Launcher extends StatelessWidget {
  final String categoryId;

  const _Launcher({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context)
              .pushNamed('/progress_group', arguments: categoryId),
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

/// Baut den ProgressGroupScreen mit Fake-Providern auf.
Future<void> _pumpProgressGroup(
  WidgetTester tester,
  String categoryId,
  List<VocabEntry> words, {
  Locale locale = const Locale('de'),
  String? activeLangCode,
  String seedLang = 'de',
}) async {
  final fakeFile = FakeFileService(store: {
    'data_app/app_data.json': {
      'registered_user': ['alice'],
      'logged_u_name': 'alice',
      'user_logged_in': true,
      'stay_logged_in': true,
    },
    'data_base/base_data.json': {'curr_lang': locale.languageCode},
  });
  final dataState = DataState(fakeFile);
  await dataState.loadAppData();

  final userManager = FakeUserManager();
  userManager.seed('alice', _userData('alice', words, lang: seedLang));
  final vq = VocabQueriesImpl(userManager);

  final navState = NavigationState();
  if (activeLangCode != null) {
    navState.setActiveCourse(LanguageCourse(
      id: '${activeLangCode}_verben_a1',
      languageCode: activeLangCode,
      languageName: courseLanguageName(activeLangCode),
      level: 'A1',
      category: 'Verben',
      flagAsset: courseFlagAsset(activeLangCode),
    ));
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataState>.value(value: dataState),
        ChangeNotifierProvider<NavigationState>.value(value: navState),
        // Gebraucht für die Sprachauflösung (resolveActiveLang).
        ChangeNotifierProvider<UserState>.value(
          value: UserState(
            userManager: userManager,
            vocabManager: FakeVocabManager(),
          ),
        ),
        Provider<VocabQueries>.value(value: vq),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        routes: {
          '/progress_group': (_) => const ProgressGroupScreen(),
        },
        home: _Launcher(categoryId: categoryId),
      ),
    ),
  );

  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Finder _flagFinder(String assetName) => find.byWidgetPredicate(
    (w) => w is Image && w.image is AssetImage &&
        (w.image as AssetImage).assetName == assetName);

void main() {
  group('ProgressGroupScreen – Summary-Beschriftung (T2/E4)', () {
    testWidgets('mittlere Spalte „In Arbeit“ mit den Zaehlern (de)',
        (tester) async {
      await _pumpProgressGroup(tester, 'erste_verben', [
        _entry('to_can_present_0', level: 8),
        _entry('to_can_present_1', level: 3),
        _entry('to_can_present_2'),
      ]);

      expect(find.text('In Arbeit'), findsOneWidget);
      expect(find.text('Fällige Wörter'), findsNothing,
          reason: 'T2 ersetzt catDueWords durch catInProgressWords');
      // Zaehler: gelernt=1, in Arbeit=1, neu=1 → dreimal die Ziffer 1.
      expect(find.text('1'), findsNWidgets(3));
    });

    testWidgets('mittlere Spalte „In progress“ (en)', (tester) async {
      await _pumpProgressGroup(
        tester,
        'erste_verben',
        [
          _entry('to_can_present_0', level: 8),
          _entry('to_can_present_1', level: 3),
          _entry('to_can_present_2'),
        ],
        locale: const Locale('en'),
      );

      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('In Arbeit'), findsNothing);
    });
  });

  group('ProgressGroupScreen – zusammenklappbare Verben (T6/D12/D13)', () {
    testWidgets(
        'Standard zugeklappt; Klick auf Verb-Kopf klappt ein und wieder aus '
        '(Chevron)', (tester) async {
      await _pumpProgressGroup(tester, 'erste_verben', [
        _entry('to_can_present_0', level: 8, word: 'ich kann'),
        _entry('to_can_present_1', level: 3, word: 'du kannst'),
      ]);

      // Anfangs zugeklappt: nur Verb-Kopf, keine Tenses-/Personenzeilen.
      expect(find.text('Can'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.text('Gegenwart'), findsNothing);
      expect(find.text('ich kann'), findsNothing);

      // Aufklappen per Klick auf den Verb-Kopf.
      await tester.tap(find.text('Can'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.text('Gegenwart'), findsOneWidget);
      expect(find.text('ich kann'), findsOneWidget);
      expect(find.text('du kannst'), findsOneWidget);
      // Read-only-Anzeige: Level-Kreise statt Eingabefelder.
      expect(find.byTooltip('Level 3'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Wieder zuklappen.
      await tester.tap(find.text('Can'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.text('Gegenwart'), findsNothing);
      expect(find.text('ich kann'), findsNothing);
    });
  });

  group('ProgressGroupScreen – Sprachanzeige (T4)', () {
    testWidgets('Flagge + Kurssprachen-Name (el → „Griechisch“)',
        (tester) async {
      await _pumpProgressGroup(
        tester,
        'erste_verben',
        [_entry('to_can_present_0', level: 8)],
        activeLangCode: 'el',
        seedLang: 'el',
      );

      expect(find.text('Griechisch'), findsOneWidget);
      expect(_flagFinder('assets/images/flag_gre.png'), findsOneWidget);
    });
  });

  group('ProgressGroupScreen – read-only / leere Liste', () {
    testWidgets('leere Wortliste zeigt l10n.noWords und keine Eingabe',
        (tester) async {
      await _pumpProgressGroup(tester, 'erste_verben', const []);

      expect(find.text('Keine Wörter verfügbar'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing,
          reason: 'read-only: keine Aktions-Buttons');
    });
  });

  group('E4 – l10n-Vollstaendigkeit (catInProgressWords, catVerbs)', () {
    test('in allen 8 Locales gefuellt und vom Key verschieden', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        expect(l10n.catInProgressWords, isNotEmpty,
            reason: '$locale catInProgressWords');
        expect(l10n.catInProgressWords, isNot('catInProgressWords'));
        expect(l10n.catVerbs, isNotEmpty, reason: '$locale catVerbs');
        expect(l10n.catVerbs, isNot('catVerbs'));
      }
      // Verbatim-Texte vom Pruefer (D15) stichprobenhaft de/en.
      expect(lookupAppLocalizations(const Locale('de')).catInProgressWords,
          'In Arbeit');
      expect(lookupAppLocalizations(const Locale('en')).catInProgressWords,
          'In progress');
      expect(lookupAppLocalizations(const Locale('de')).catVerbs, 'Verben');
      expect(lookupAppLocalizations(const Locale('en')).catVerbs, 'Verbs');
    });
  });
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/category_screen.dart';

import 'helpers/fakes.dart';

/// [VocabQueries], dessen [getGroupCounts] erst nach [countsCompleter] liefert.
/// Damit ist der „erster Frame deaktiviert (E1)“-Zustand beobachtbar.
class _SlowVocabQueries extends VocabQueriesImpl {
  final Completer<CategoryCounts> countsCompleter;

  _SlowVocabQueries(super.userManager, this.countsCompleter);

  @override
  Future<CategoryCounts> getGroupCounts(
          String username, WordCategory category,
          {String langCode = 'de'}) =>
      countsCompleter.future;
}


UserData _userData(String username, List<VocabEntry> words) => UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocab: {for (final w in words) w.key: w},
    );

/// Ein Wort der Kategorie [cat] (erster Verb-Key, eine Person-Position).
VocabEntry _categoryWord(WordCategory cat, {int level = 0}) {
  final verb = cat.verbKeys.first;
  return VocabEntry(
    key: '${verb}_present_0',
    word: 'beispiel',
    translation: 'translation',
    examples: const [],
    examplesNative: const [],
    level: level,
    status: level == 0 ? 'new' : 'seen',
    reviewDue: level == 0 ? null : '2020-01-01',
  );
}

/// Start-Home, das nach Tipp auf „OPEN“ die [route] mit [arguments] öffnet.
class _Launcher extends StatelessWidget {
  final String route;
  final Object? arguments;

  const _Launcher({required this.route, this.arguments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(route, arguments: arguments),
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

/// Marker für `/progress_group`: zeigt das übergebene Argument an und bietet
/// einen POP-Button für den Rückweg.
class _ProgressGroupMarker extends StatelessWidget {
  const _ProgressGroupMarker();

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('PG:$arg'),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('POP'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baut den CategoryScreen mit Fake-Providern auf und öffnet die Kategorie
/// [categoryId] (ein Tipp + ein Frame, ohne Settle – damit der „erste Frame
/// deaktiviert“-Fall beobachtbar bleibt).
Future<({FakeUserManager userManager, NavigationState navState})>
    _pumpCategory(
  WidgetTester tester,
  String categoryId,
  List<VocabEntry> words, {
  VocabQueries? queries,
}) async {
  final fakeFile = FakeFileService(store: {
    'data_app/app_data.json': {
      'registered_user': ['alice'],
      'logged_u_name': 'alice',
      'user_logged_in': true,
      'stay_logged_in': true,
    },
    'data_base/base_data.json': {'curr_lang': 'de'},
  });
  final dataState = DataState(fakeFile);
  await dataState.loadAppData();

  final userManager = FakeUserManager();
  userManager.seed('alice', _userData('alice', words));
  final vq = queries ?? VocabQueriesImpl(userManager);
  final navState = NavigationState();

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
        locale: const Locale('de'),
        navigatorObservers: [routeObserver],
        routes: {
          '/category': (_) => const CategoryScreen(),
          '/progress_group': (_) => const _ProgressGroupMarker(),
          // Sicherheitsnetz: Modus-Buttons würden hierhin navigieren.
          '/word': (_) => const _ProgressGroupMarker(),
          '/dueword': (_) => const _ProgressGroupMarker(),
        },
        home: _Launcher(route: '/category', arguments: categoryId),
      ),
    ),
  );

  await tester.tap(find.text('OPEN'));
  await tester.pump();

  return (userManager: userManager, navState: navState);
}

Finder _progressButton() => find.widgetWithText(OutlinedButton, 'Lernfortschritt');

bool _progressEnabled(WidgetTester tester) =>
    tester.widget<OutlinedButton>(_progressButton()).onPressed != null;

void main() {
  group('CategoryScreen – Lernfortschritt-Button (T1/E2)', () {
    for (final cat in courseWordCategories) {
      testWidgets(
          'Kategorie ${cat.id}: Button sichtbar, letztes Element, aktiv',
          (tester) async {
        await _pumpCategory(tester, cat.id, [_categoryWord(cat)]);
        await tester.pumpAndSettle();

        final backButton = find.widgetWithText(TextButton, 'Zurück');
        expect(_progressButton(), findsOneWidget);
        expect(backButton, findsOneWidget);
        expect(_progressEnabled(tester), isTrue,
            reason: 'Zähler > 0 → Button aktiv');

        // „Letztes Element“ geometrisch: Button liegt unter dem Zurück-Button
        // (dieser ist das unmittelbar davor liegende Element).
        final progBottom = tester.getBottomRight(_progressButton()).dy;
        final backBottom = tester.getBottomRight(backButton).dy;
        expect(progBottom, greaterThan(backBottom));
      });
    }

    testWidgets('Erster Frame deaktiviert, aktiv nach _refreshCounts (E1)',
        (tester) async {
      final completer = Completer<CategoryCounts>();
      await _pumpCategory(tester, 'erste_verben', const [],
          queries: _SlowVocabQueries(FakeUserManager(), completer));
      // Route-Transition abschliessen, Zaehler bleibt aber offen.
      await tester.pumpAndSettle();

      // Erster Frame: _counts ist noch null → counts.total == 0 → disabled.
      expect(_progressButton(), findsOneWidget);
      expect(_progressEnabled(tester), isFalse,
          reason: 'erster Frame muss deaktiviert sein (E1)');

      completer.complete(const CategoryCounts(total: 1, newCount: 1));
      await tester.pumpAndSettle();
      expect(_progressEnabled(tester), isTrue,
          reason: 'nach _refreshCounts aktiv');
    });

    testWidgets('deaktiviert, wenn total == 0 (leerer Wortschatz)',
        (tester) async {
      await _pumpCategory(tester, 'erste_verben', const []);
      await tester.pumpAndSettle();

      expect(_progressButton(), findsOneWidget);
      expect(_progressEnabled(tester), isFalse);
    });

    testWidgets('deaktiviert, wenn die Kategorie nicht aufloesbar ist',
        (tester) async {
      await _pumpCategory(tester, 'gibt_es_nicht', const []);
      await tester.pumpAndSettle();

      expect(_progressButton(), findsOneWidget);
      expect(_progressEnabled(tester), isFalse);
    });

    testWidgets(
        'Navigation: /progress_group mit Kategorie-Id als Argument, '
        'keine Seiteneffekte', (tester) async {
      final cat = wordCategoryById('grp_alltag')!;
      final harness =
          await _pumpCategory(tester, cat.id, [_categoryWord(cat)]);
      await tester.pumpAndSettle();

      await tester.tap(_progressButton());
      await tester.pumpAndSettle();

      // Argument ist exakt die Kategorie-Id (Route Settings).
      expect(find.text('PG:grp_alltag'), findsOneWidget);

      // Keine Seiteneffekte auf wordMode/selectedCategoryId.
      expect(harness.navState.wordMode, 'new');
      expect(harness.navState.selectedCategoryId, isNull);
    });

    testWidgets('Zaehler-Refresh nach Rueckprung via didPopNext',
        (tester) async {
      final cat = wordCategoryById('erste_verben')!;
      final harness =
          await _pumpCategory(tester, cat.id, [_categoryWord(cat)]);
      await tester.pumpAndSettle();
      expect(_progressEnabled(tester), isTrue);

      // Wortschatz leeren, dann vor und zurueck navigieren: didPopNext muss
      // die Zaehler neu laden (total == 0 → Button deaktiviert).
      harness.userManager.seed('alice', _userData('alice', const []));

      await tester.tap(_progressButton());
      await tester.pumpAndSettle();
      expect(find.text('PG:erste_verben'), findsOneWidget);

      await tester.tap(find.text('POP'));
      await tester.pumpAndSettle();

      expect(_progressEnabled(tester), isFalse,
          reason: 'nach Rueckprung muss der Zaehler neu geladen sein');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/start_screen.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';

import 'helpers/fakes.dart';

const _appDataPath = 'data_app/app_data.json';

/// Harness fuer den StartScreen. Die UserInfoBox-Stats laufen ueber einen
/// echten [VocabQueriesImpl], der auf dem [FakeUserManager] lastet ->
/// [FakeUserManager.loadCount] zaehlt damit exakt die UserData-Datei-Loads
/// (getUserStats = genau 1 Load, Einzelmethoden unveraendert daneben).
Widget _app({
  required FakeUserManager userManager,
  required FakeVocabManager vocabManager,
  required DataState dataState,
  required NavigationState navState,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DataState>.value(value: dataState),
      ChangeNotifierProvider<NavigationState>.value(value: navState),
      ChangeNotifierProvider<UserState>.value(
        value: UserState(
          userManager: userManager,
          vocabManager: vocabManager,
        ),
      ),
      Provider<VocabQueries>.value(value: VocabQueriesImpl(userManager)),
    ],
    child: MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [routeObserver],
      home: const StartScreen(),
    ),
  );
}

UserData _userData(String username, Map<String, VocabEntry> vocab,
        {DayStreak? dayStreak}) =>
    UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocab: vocab,
      dayStreak: dayStreak,
    );

VocabEntry _vocab(String key,
        {int level = 0, String status = 'new', String? reviewDue}) =>
    VocabEntry(
      key: key,
      word: key,
      translation: key,
      examples: const [],
      examplesNative: const [],
      level: level,
      status: status,
      reviewDue: reviewDue,
    );

/// Eintraege decken jede Stat-Klasse ab (Klassifikation aus Ticket 4):
/// new=1, due=1, read=3, learned=1, Streak 3/5.
void _seedAlice(FakeUserManager um) {
  um.seed(
    'alice',
    _userData(
      'alice',
      {
        'w1_new': _vocab('w1_new'),
        'w2_due': _vocab('w2_due',
            level: 1, status: 'seen', reviewDue: '2020-01-01'),
        'w3_seen': _vocab('w3_seen',
            level: 1, status: 'seen', reviewDue: '2999-01-01'),
        'w4_learned': _vocab('w4_learned', level: 8, status: 'seen'),
        'w5_edge': _vocab('w5_edge',
            level: 1, reviewDue: '2020-01-01'),
      },
      dayStreak: const DayStreak(current: 3, longest: 5),
    ),
  );
}

Map<String, Map<String, dynamic>> _appDataStore({String logged = 'alice'}) => {
      _appDataPath: {
        'registered_user': ['alice', 'bob'],
        'logged_u_name': logged,
        'user_logged_in': true,
        'stay_logged_in': true,
      },
    };

void _useLandscapeSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(StorageErrorBus.instance.clear);
  tearDown(StorageErrorBus.instance.clear);

  testWidgets('UserInfoBox zeigt alle Stats aus genau einem Load',
      (tester) async {
    _useLandscapeSize(tester);
    final um = FakeUserManager();
    _seedAlice(um);
    final dataState = DataState(FakeFileService(store: _appDataStore()));
    await dataState.loadAppData();
    final navState = NavigationState();

    await tester.pumpWidget(_app(
      userManager: um,
      vocabManager: FakeVocabManager(),
      dataState: dataState,
      navState: navState,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Neue Wörter: 1'), findsOneWidget);
    expect(find.text('Fällige Wörter: 1'), findsOneWidget);
    expect(find.text('Gelesene Wörter: 3'), findsOneWidget);
    expect(find.text('Gelernte Wörter: 1'), findsOneWidget);
    expect(find.text('Tag 3  |  Rekord: 5'), findsOneWidget);
    expect(um.loadCount, 1);
  });

  testWidgets('Rebuild ohne statsVersion-Wechsel laedt nicht neu',
      (tester) async {
    _useLandscapeSize(tester);
    final um = FakeUserManager();
    _seedAlice(um);
    final dataState = DataState(FakeFileService(store: _appDataStore()));
    await dataState.loadAppData();
    final navState = NavigationState();

    await tester.pumpWidget(_app(
      userManager: um,
      vocabManager: FakeVocabManager(),
      dataState: dataState,
      navState: navState,
    ));
    await tester.pumpAndSettle();
    expect(um.loadCount, 1);

    // MediaQuery-Wechsel bei gleicher Orientierung => Rebuild desselben
    // Elementzustands ohne User-/Versionswechsel -> kein neuer Load.
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(um.loadCount, 1);

    // notifyListeners-Rebuild (DataState) ohne User-/Versionswechsel.
    await dataState.loadAppData();
    await tester.pumpAndSettle();
    expect(um.loadCount, 1);
  });

  testWidgets('statsVersion++ loest genau einen neuen Load aus',
      (tester) async {
    _useLandscapeSize(tester);
    final um = FakeUserManager();
    _seedAlice(um);
    final dataState = DataState(FakeFileService(store: _appDataStore()));
    await dataState.loadAppData();
    final navState = NavigationState();

    await tester.pumpWidget(_app(
      userManager: um,
      vocabManager: FakeVocabManager(),
      dataState: dataState,
      navState: navState,
    ));
    await tester.pumpAndSettle();
    expect(um.loadCount, 1);

    // Direkte Benachrichtigung (wie didPopNext -> notifyStatsChanged).
    navState.notifyStatsChanged();
    await tester.pumpAndSettle();
    expect(um.loadCount, 2);

    // didPopNext-Pfad: Route auf den StartScreen schieben und zurueckpoppen.
    final ctx = tester.element(find.byType(StartScreen));
    final navigator = Navigator.of(ctx);
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('DUMMY-ROUTE')),
    ));
    await tester.pumpAndSettle();
    expect(um.loadCount, 2);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(um.loadCount, 3);
    expect(find.text('DUMMY-ROUTE'), findsNothing);
  });

  testWidgets('username-Wechsel loest genau einen neuen Load aus',
      (tester) async {
    _useLandscapeSize(tester);
    final um = FakeUserManager();
    _seedAlice(um);
    final fs = FakeFileService(store: _appDataStore());
    final dataState = DataState(fs);
    await dataState.loadAppData();
    final navState = NavigationState();

    await tester.pumpWidget(_app(
      userManager: um,
      vocabManager: FakeVocabManager(),
      dataState: dataState,
      navState: navState,
    ));
    await tester.pumpAndSettle();
    expect(um.loadCount, 1);

    // User-Wechsel auf 'bob' (wie _showLogin -> dataState.loadAppData()).
    um.seed('bob', _userData('bob', {'bob_new': _vocab('bob_new')}));
    fs.store[_appDataPath]!['logged_u_name'] = 'bob';
    await dataState.loadAppData();
    await tester.pumpAndSettle();

    expect(um.loadCount, 2);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('Neue Wörter: 1'), findsOneWidget);
  });

  testWidgets('frischer User: Meine Kurse leer, Neue Kurse bietet Englisch an',
      (tester) async {
    // Ticket #35: Soeben erstellter User ohne Kurse und ohne Vokabeln.
    _useLandscapeSize(tester);
    final um = FakeUserManager();
    um.seed('carol', _userData('carol', const {}));
    final fs = FakeFileService(store: _appDataStore(logged: 'carol'));
    final dataState = DataState(fs);
    await dataState.loadAppData();
    final navState = NavigationState();

    await tester.pumpWidget(_app(
      userManager: um,
      vocabManager: FakeVocabManager(),
      dataState: dataState,
      navState: navState,
    ));
    await tester.pumpAndSettle();

    // „Meine Kurse“ ist beim neuen User leer (kein Auto-Load von Kursen).
    // Hinweis: Im leeren Zustand wird ausschließlich „Keine Kurse“ gezeigt.
    expect(find.text('Keine Kurse'), findsOneWidget);

    // „Neue Kurse“ darunter bietet (u. a.) Englisch zum eigenständigen
    // Hinzufügen an – es wird weiterhin nichts vorausgewählt.
    expect(find.text('Neue Sprachen entdecken'), findsOneWidget);
    expect(find.text('Englisch'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/grammar_manager.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/session_manager.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/loading_screen.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';
import 'package:learn_a_language/widgets/app_widgets.dart';

import 'helpers/fakes.dart';

/// Marker für die `/start`-Route des Tests (der echte StartScreen würde mehr
/// Dependencies brauchen).
class _StartMarker extends StatelessWidget {
  const _StartMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('START-MARKER'));
}

/// Marker für eine wiederhergestellte Lern-Route.
class _LearningMarker extends StatelessWidget {
  const _LearningMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('LEARNING-MARKER'));
}

/// Marker für eine wiederhergestellte Kategorie-Route.
class _CategoryMarker extends StatelessWidget {
  const _CategoryMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('CATEGORY-MARKER'));
}

Widget _app({
  required Map<String, Map<String, dynamic>> store,
  FakeUserManager? userManager,
  FakeVocabManager? vocabManager,
}) {
  final fs = FakeFileService(store: store);
  final dataState = DataState(fs);
  final userState = UserState(
    userManager: userManager ?? FakeUserManager(),
    vocabManager: vocabManager ?? FakeVocabManager(),
  );
  final sessionManager = SessionManager(fs, GrammarManagerImpl(fs));
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DataState>.value(value: dataState),
      ChangeNotifierProvider<NavigationState>.value(value: NavigationState()),
      ChangeNotifierProvider<UserState>.value(value: userState),
      Provider<SessionManager>.value(value: sessionManager),
    ],
    child: MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          StorageWarningListener(child: child ?? const SizedBox.shrink()),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoadingScreen(),
        '/start': (_) => const _StartMarker(),
        '/learning': (_) => const _LearningMarker(),
        '/category': (_) => const _CategoryMarker(),
      },
    ),
  );
}

/// App-Daten mit eingeloggtem Benutzer [logged].
Map<String, Map<String, dynamic>> _appDataStore({String logged = 'alice'}) => {
      'data_app/app_data.json': {
        'registered_user': [logged],
        'logged_u_name': logged,
        'user_logged_in': true,
        'stay_logged_in': true,
      },
    };

FakeUserManager _userManagerWith(String username) {
  final um = FakeUserManager();
  um.seed(username, UserData(
        uName: username,
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        selectedCourses: const ['de_verben_a1'],
      ));
  return um;
}

void main() {
  setUp(StorageErrorBus.instance.clear);
  tearDown(StorageErrorBus.instance.clear);

  testWidgets('Bootstrap navigiert ohne Login nach /start', (tester) async {
    await tester.pumpWidget(_app(store: {}));
    // Asynchrone Init-Schritte + 300-ms-Verweildauer abwarten.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(_StartMarker), findsOneWidget);
  });

  testWidgets(
      'Bootstrap mit Auto-Login: genau ein Init- + Migrationslauf -> /start',
      (tester) async {
    final um = _userManagerWith('alice');
    final vm = FakeVocabManager();

    await tester.pumpWidget(_app(
      store: _appDataStore(),
      userManager: um,
      vocabManager: vm,
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(_StartMarker), findsOneWidget);
    // Genau EIN Login-Lauf = genau ein Init + ein Migrate (kein Doppelt-Migrate).
    expect(vm.initCount, 1);
    expect(vm.migrateCount, 1);
  });

  testWidgets('Auto-Login-Fehler wird sichtbar (SnackBar) und navigiert weiter',
      (tester) async {
    StorageErrorBus.instance.clear();
    final um = FakeUserManager(unreadableUsers: {'alice'});

    await tester.pumpWidget(_app(
      store: _appDataStore(),
      userManager: um,
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Fehlersichtbarkeit aus Ticket 2 bleibt erhalten: SnackBar über den Bus.
    expect(find.byType(_StartMarker), findsOneWidget);
    expect(
        find.text('Deine Benutzerdaten konnten nicht geladen werden.'),
        findsOneWidget);
  });

  testWidgets(
      'Gespeicherte Session: Bootstrap stellt die zuletzt geöffnete Seite '
      'wieder her', (tester) async {
    final store = _appDataStore();
    store['data_app/last_session.json'] = {
      'version': 1,
      'user': 'alice',
      'wordMode': 'new',
      'selectedCategoryId': null,
      'routes': [
        {'name': '/learning'},
      ],
    };

    await tester.pumpWidget(_app(
      store: store,
      userManager: _userManagerWith('alice'),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Statt des Start-Menüs erscheint die zuletzt geöffnete Lern-Seite.
    expect(find.byType(_LearningMarker), findsOneWidget);
  });

  testWidgets(
      'Gespeicherte Session mit Argumenten: Kategorie wird samt Argument '
      'wiederhergestellt', (tester) async {
    final store = _appDataStore();
    store['data_app/last_session.json'] = {
      'version': 1,
      'user': 'alice',
      'wordMode': 'new',
      'selectedCategoryId': 'erste_verben',
      'routes': [
        {'name': '/learning'},
        {
          'name': '/category',
          'args': {'type': 'string', 'value': 'erste_verben'},
        },
      ],
    };

    await tester.pumpWidget(_app(
      store: store,
      userManager: _userManagerWith('alice'),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(_CategoryMarker), findsOneWidget);
  });

  testWidgets(
      'Session eines anderen Benutzers wird verworfen -> normaler Start',
      (tester) async {
    final store = _appDataStore(logged: 'bob');
    store['data_app/last_session.json'] = {
      'version': 1,
      'user': 'alice', // gehört NICHT dem eingeloggten bob
      'wordMode': 'new',
      'selectedCategoryId': null,
      'routes': [
        {'name': '/learning'},
      ],
    };

    await tester.pumpWidget(_app(
      store: store,
      userManager: _userManagerWith('bob'),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(_StartMarker), findsOneWidget);
    // Fremde Session wurde gelöscht.
    expect(store['data_app/last_session.json'], isNull);
  });

  testWidgets('Korrupte Session führt zum normalen Start', (tester) async {
    final store = _appDataStore();
    store['data_app/last_session.json'] = {
      'version': 99, // unbekannte Version -> verwerfen
      'user': 'alice',
      'routes': [
        {'name': '/learning'},
      ],
    };

    await tester.pumpWidget(_app(
      store: store,
      userManager: _userManagerWith('alice'),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(_StartMarker), findsOneWidget);
  });
}

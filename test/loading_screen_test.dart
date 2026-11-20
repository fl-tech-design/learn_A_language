import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
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
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DataState>.value(value: dataState),
      ChangeNotifierProvider<UserState>.value(value: userState),
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
      },
    ),
  );
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
    final um = FakeUserManager();
    um.seed('alice', UserData(
          uName: 'alice',
          mLang: 'de',
          progress: const {},
          learnedLanguages: const [],
          language: const {},
          vocab: const {},
        ));
    final vm = FakeVocabManager();

    await tester.pumpWidget(_app(
      store: {
        'data_app/app_data.json': {
          'registered_user': ['alice'],
          'logged_u_name': 'alice',
          'user_logged_in': true,
          'stay_logged_in': true,
        },
      },
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
      store: {
        'data_app/app_data.json': {
          'logged_u_name': 'alice',
          'user_logged_in': true,
          'stay_logged_in': true,
        },
      },
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
}

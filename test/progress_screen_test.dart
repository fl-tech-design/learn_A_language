import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/progress_screen.dart';

import 'helpers/fakes.dart';

class _DummyPage extends StatelessWidget {
  const _DummyPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('DUMMY')));
}

UserState _userState() =>
    UserState(userManager: FakeUserManager(), vocabManager: FakeVocabManager());

Widget _app({
  required NavigationState navState,
  required UserState userState,
  Locale locale = const Locale('de'),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationState>.value(value: navState),
      ChangeNotifierProvider<UserState>.value(value: userState),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: {
        // Zielrouten der Sammlungs-Buttons (im Test nicht angetippt).
        '/progress_group': (_) => const _DummyPage(),
        '/collection': (_) => const _DummyPage(),
      },
      home: const ProgressScreen(),
    ),
  );
}

Finder _flagFinder(String assetName) => find.byWidgetPredicate(
    (w) => w is Image && w.image is AssetImage &&
        (w.image as AssetImage).assetName == assetName);

void main() {
  group('ProgressScreen – Titel ohne Hartkodierung (T3/D10=c)', () {
    testWidgets('Locale de zeigt l10n.titPageProgress', (tester) async {
      await tester.pumpWidget(
          _app(navState: NavigationState(), userState: _userState()));

      expect(find.text('Lernfortschritt'), findsOneWidget);
    });

    testWidgets('Locale en zeigt „Learning Progress“, nicht den deutschen Text',
        (tester) async {
      await tester.pumpWidget(_app(
        navState: NavigationState(),
        userState: _userState(),
        locale: const Locale('en'),
      ));

      expect(find.text('Learning Progress'), findsOneWidget);
      expect(find.text('Lernfortschritt'), findsNothing,
          reason: 'kein hartkodierter Titel');
    });
  });

  group('ProgressScreen – Ueberkategorie „Verben“ (T7/D14/D16)', () {
    testWidgets('de: „Verben“ mit beiden Verb-Sammlungen', (tester) async {
      await tester.pumpWidget(
          _app(navState: NavigationState(), userState: _userState()));

      expect(find.text('Verben'), findsOneWidget);
      expect(find.text('Erste Verben'), findsOneWidget);
      expect(find.text('Weitere Verben'), findsOneWidget);
    });

    testWidgets('en: „Verbs“ mit beiden Verb-Sammlungen (App-Locale)',
        (tester) async {
      await tester.pumpWidget(_app(
        navState: NavigationState(),
        userState: _userState(),
        locale: const Locale('en'),
      ));

      expect(find.text('Verbs'), findsOneWidget);
      expect(find.text('First Verbs'), findsOneWidget);
      expect(find.text('More Verbs'), findsOneWidget);
    });

    test('courseTopCategories-Struktur: Dach-Ebene mit beiden Sammlungen',
        () {
      final tops = courseTopCategories.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      expect(tops, hasLength(1));
      final verbs = tops.single;
      expect(verbs.id, 'verbs');
      expect(verbs.titleKey, 'catVerbs');
      expect(verbs.collectionIds, ['erste_verben', 'weitere_verben']);
      expect(verbs.collections.map((c) => c.id).toList(),
          ['erste_verben', 'weitere_verben']);
      // Adjektive docken spaeter auf gleicher Ebene an: mehrere Dach-Gruppen
      // sind strukturell erlaubt (order + id je Gruppe).
    });
  });

  group('ProgressScreen – Sprachanzeige (T4)', () {
    testWidgets('Flagge + Kurssprachen-Name (fr → „Französisch“)',
        (tester) async {
      final nav = NavigationState();
      nav.setActiveCourse(const LanguageCourse(
        id: 'fr_verben_a1',
        languageCode: 'fr',
        languageName: 'Französisch',
        level: 'A1',
        category: 'Verben',
        flagAsset: 'assets/images/flag_fra.png',
      ));

      await tester.pumpWidget(_app(navState: nav, userState: _userState()));

      expect(find.text('Französisch'), findsOneWidget);
      expect(_flagFinder('assets/images/flag_fra.png'), findsOneWidget);
    });
  });
}

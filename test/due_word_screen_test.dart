import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/due_word_screen.dart';
import 'package:learn_a_language/theme/app_theme.dart';

import 'helpers/fakes.dart';

/// Fälliges Wort (status 'seen', Level > 0, Termin in der Vergangenheit).
VocabEntry _dueWord(String key, String word, String translation,
        {int level = 1}) =>
    VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: const [],
      examplesNative: const [],
      level: level,
      status: 'seen',
      reviewDue: '2000-01-01',
    );

UserData _userData(String username, List<VocabEntry> words) => UserData(
      uName: username,
      mLang: 'de',
      progress: const {},
      learnedLanguages: const [],
      language: const {},
      vocab: {for (final w in words) w.key: w},
    );

/// Baut den DueWordScreen mit Fake-Providern auf.
Future<void> _pumpDueWordScreen(
  WidgetTester tester,
  List<VocabEntry> words,
) async {
  final fakeFile = FakeFileService(store: {
    'data_app/app_data.json': {
      'registered_user': ['alice'],
      'logged_u_name': 'alice',
      'user_logged_in': true,
      'stay_logged_in': true,
      'words_per_session': 10,
    },
    'data_base/base_data.json': {'curr_lang': 'de'},
  });
  final dataState = DataState(fakeFile);
  await dataState.loadAppData();

  final userManager = FakeUserManager();
  userManager.seed('alice', _userData('alice', words));
  final vq = VocabQueriesImpl(userManager);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataState>.value(value: dataState),
        ChangeNotifierProvider<NavigationState>.value(
            value: NavigationState()),
        Provider<VocabQueries>.value(value: vq),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('de'),
        home: DueWordScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Liest den Klartext der Antwort-Anzeige (Text.rich, fontSize 28) und
/// entfernt die geschützten Leerzeichen (NBSP) der Wort-Verbindungen.
String _answerPlain(WidgetTester tester) {
  final text = tester.widget<Text>(find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontSize == 28 && w.data == null));
  return (text.textSpan?.toPlainText() ?? '').replaceAll('\u00A0', '');
}

/// True, sobald das Wort gelöst ist („Nächstes Wort"-Button sichtbar).
bool _isChecked(WidgetTester tester) =>
    find.text('Nächstes Wort').evaluate().isNotEmpty;

Future<void> _typeLetters(WidgetTester tester, String letters) async {
  for (final c in letters.split('')) {
    await tester.enterText(find.byType(TextField), c);
    await tester.pump();
  }
}
void main() {
  testWidgets('Niveau wird in der Abfrage angezeigt', (tester) async {
    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_3', 'he/she/it can', 'er/sie/es kann', level: 2),
    ]);

    expect(find.text('Level: 2'), findsOneWidget);
  });

  testWidgets('"/" wird automatisch ergänzt (he/she/it can)', (tester) async {
    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_3', 'he/she/it can', 'er/sie/es kann', level: 2),
    ]);

    // Schon nach zwei Buchstaben ist der Schrägstrich automatisch da.
    await _typeLetters(tester, 'he');
    expect(_answerPlain(tester), startsWith('he/'));

    // Ohne je ein "/" einzutippen wird das ganze Wort gelöst.
    await _typeLetters(tester, 'sheit can');
    expect(_isChecked(tester), isTrue);
    expect(_answerPlain(tester).trim(), 'he/she/it can');
  });

  testWidgets('"(pl)" wird nicht abgefragt, nach Lösung aber angezeigt',
      (tester) async {
    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_4', 'you can (pl)', 'ihr könnt', level: 3),
    ]);

    // Beim Tippen: keine Klammern/Unterstriche für "(pl)".
    expect(_answerPlain(tester), isNot(contains('(')));
    expect(_answerPlain(tester), isNot(contains(')')));

    // Korrekt lösen, ohne "(pl)" einzutippen.
    await _typeLetters(tester, 'you can');
    expect(_isChecked(tester), isTrue);
    expect(find.text('Richtig!'), findsOneWidget);

    // Nach der Lösung ist das Original mit "(pl)" wieder sichtbar.
    expect(_answerPlain(tester).trim(), 'you can (pl)');
  });

  testWidgets('aktive Position wird farblich hervorgehoben', (tester) async {
    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_1', 'you can', 'du kannst'),
    ]);

    final textSpan = tester
        .widget<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 28 && w.data == null))
        .textSpan!;

    bool foundActive = false;
    bool foundGrey = false;
    textSpan.visitChildren((span) {
      if (span is TextSpan && (span.text == '_')) {
        if (span.style?.color == AppTheme.colorPrimary) foundActive = true;
        if (span.style?.color == AppTheme.grey4) foundGrey = true;
      }
      return true;
    });
    expect(foundActive, isTrue, reason: 'nächste Position muss auffallen');
    expect(foundGrey, isTrue, reason: 'übrige Lücken müssen gedämpft sein');
  });

  testWidgets('ingetipptes Leerzeichen wird sichtbar gemacht', (tester) async {
    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_1', 'can do', 'kann machen'),
    ]);

    // Vor dem Leerzeichen: die Wortlücke wird als "·" angezeigt.
    await _typeLetters(tester, 'can');
    expect(_answerPlain(tester), contains('·'));

    // Nach Eingabe des Leerzeichens ist die Lücke ein normales Leerzeichen.
    await _typeLetters(tester, ' ');
    expect(_answerPlain(tester), isNot(contains('·')));
  });

  testWidgets('Querformat: Bodenleiste verschwindet bei offener Tastatur',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDueWordScreen(tester, [
      _dueWord('can_present_3', 'he/she/it can', 'er/sie/es kann', level: 2),
    ]);

    // Ohne Tastatur: Bodenleiste sichtbar.
    expect(find.text('Einstellungen'), findsOneWidget);

    // Mit simulierter Tastatur: Bodenleiste ausgeblendet, Eingabe sichtbar.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
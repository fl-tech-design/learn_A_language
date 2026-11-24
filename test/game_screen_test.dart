import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/user_manager.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/managers/vocab_queries.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/screens/game_screen.dart';

import 'helpers/fakes.dart';

/// Bereits gelesenes Wort (status 'seen'), damit es im Turbo-Pool landet.
VocabEntry _seenWord(String key, String word, String translation) => VocabEntry(
      key: key,
      word: word,
      translation: translation,
      examples: const [],
      examplesNative: const [],
      level: 1,
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

/// Baut den Turbo-GameScreen (Standard: mittel, Startzeit 15s, Bonus +2s)
/// mit Fake-Providern auf.
Future<void> _pumpGameScreen(
  WidgetTester tester,
  List<VocabEntry> words, {
  String difficulty = 'medium',
}) async {
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
        ChangeNotifierProvider<NavigationState>.value(value: NavigationState()),
        // Gebraucht für die Sprachauflösung des Spiels.
        ChangeNotifierProvider<UserState>.value(
            value: UserState(
                userManager: userManager,
                vocabManager: FakeVocabManager())),
        Provider<UserManager>.value(value: userManager),
        Provider<VocabQueries>.value(value: vq),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: GameScreen(difficulty: difficulty),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Aktuelle Timer-Anzeige der Statusleiste (z. B. "15s").
String _timerText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byWidgetPredicate((w) =>
      w is Text && w.data != null && RegExp(r'^\d+s$').hasMatch(w.data!)));
  return text.data!;
}

/// Wort der aktuell sichtbaren Frage (aus der Übersetzungs-Anzeige
/// rückgerechnet). Nötig, weil die Fragen zufällig gemischt werden.
String _currentWord(WidgetTester tester, List<VocabEntry> words) {
  final question = tester
      .widget<Text>(
          find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 30))
      .data!;
  return words.firstWhere((w) => w.translation == question).word;
}

void main() {
  testWidgets('Startzeit (mittel = 15s) wird beim Spielstart gesetzt',
      (tester) async {
    await _pumpGameScreen(tester, [
      _seenWord('cat_present_0', 'cat', 'Katze'),
      _seenWord('dog_present_0', 'dog', 'Hund'),
      _seenWord('bird_present_0', 'bird', 'Vogel'),
      _seenWord('fish_present_0', 'fish', 'Fisch'),
    ]);

    expect(_timerText(tester), '15s');
  });

  testWidgets('Zeitbonus bleibt beim Fragenwechsel erhalten (kein Reset)',
      (tester) async {
    final words = [
      _seenWord('cat_present_0', 'cat', 'Katze'),
      _seenWord('dog_present_0', 'dog', 'Hund'),
      _seenWord('bird_present_0', 'bird', 'Vogel'),
      _seenWord('fish_present_0', 'fish', 'Fisch'),
    ];
    await _pumpGameScreen(tester, words);

    expect(_timerText(tester), '15s');

    // Richtige Antwort klicken -> +2s Bonus (mittel).
    final correctWord = _currentWord(tester, words);
    await tester.tap(find.text(correctWord));
    await tester.pump();
    expect(_timerText(tester), '17s');

    // Wechsel zur nächsten Frage (300 ms Verzögerung): Die Restzeit inkl.
    // Bonus darf NICHT auf die Startzeit zurückgesetzt werden.
    await tester.pump(const Duration(milliseconds: 300));
    expect(_timerText(tester), '17s');
  });

  testWidgets(
      'Nach Zeitablauf startet die nächste Frage mit frischer Startzeit',
      (tester) async {
    final words = [
      _seenWord('cat_present_0', 'cat', 'Katze'),
      _seenWord('dog_present_0', 'dog', 'Hund'),
    ];
    await _pumpGameScreen(tester, words);

    expect(_timerText(tester), '15s');

    // 15 Sekunden verstreichen lassen -> Zeit der 1. Frage aufgebraucht
    // (Leben -1). Die 2. Frage startet erneut mit der Startzeit statt mit 0s.
    await tester.pump(const Duration(seconds: 15));
    expect(_timerText(tester), '15s');
  });
}

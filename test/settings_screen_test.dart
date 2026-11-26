import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/managers/data_state.dart';
import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/models/language_registry.dart';
import 'package:learn_a_language/screens/settings_screen.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';
import 'package:learn_a_language/widgets/app_widgets.dart';

import 'helpers/fakes.dart';

/// Baut den SettingsScreen mit Fake-Providern auf.
///
/// [dictLanguages] = von [FakeFileService.discoverLanguageDicts] gemeldete
/// Sprachen (entspricht installierten Sprachpaketen, Ticket #68).
/// [languageConfig] aktiviert optional die datengetriebene Sprach-Config
/// (languages.json-Aequivalent) – inkl. it/pt als UI-Sprachen (Ticket #71).
/// [mLang] ist die Muttersprache des eingeloggten Users (Ueber login()).
Future<void> _pumpSettings(
  WidgetTester tester, {
  Set<String> dictLanguages = const {},
  String mLang = 'de',
  Map<String, dynamic>? languageConfig,
}) async {
  PackageInfo.setMockInitialValues(
    appName: 'learn_a_language',
    packageName: 'learn_a_language',
    version: '1.13.0',
    buildNumber: '27',
    buildSignature: '',
  );
  if (languageConfig != null) {
    await loadLanguageConfig(assetLoader: (_) async => languageConfig);
  }

  final fakeFile = FakeFileService(
    store: {
      'data_app/app_data.json': {
        'registered_user': ['alice'],
        'logged_u_name': 'alice',
        'user_logged_in': true,
        'stay_logged_in': true,
      },
      'data_base/base_data.json': {'curr_lang': 'de'},
    },
    languageDicts: {for (final code in dictLanguages) code: {}},
  );
  final dataState = DataState(fakeFile);
  await dataState.loadAppData();
  await dataState.refreshLanguages();

  final userManager = FakeUserManager();
  userManager.seed(
    'alice',
    UserData(
      uName: 'alice',
      mLang: mLang,
      progress: const {},
      learnedLanguages: const [],
      language: const {},
    ),
  );
  final userState = UserState(
    userManager: userManager,
    vocabManager: FakeVocabManager(),
  );
  await userState.login('alice');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataState>.value(value: dataState),
        ChangeNotifierProvider<UserState>.value(value: userState),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('de'),
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Minimale Sprach-Config mit it/pt als UI-Sprachen (languages.json-Aequivalent,
/// Ticket #71: it/pt sind vollwertige App-Sprachen).
const Map<String, dynamic> _configItPtUi = {
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
      'code': 'en',
      'flagAsset': 'assets/images/flag_uk.png',
      'labelKey': 'english',
      'nameDe': 'Englisch',
      'aliases': ['englisch', 'english'],
      'ui': true,
      'seed': true,
      'course': true,
    },
    {
      'code': 'it',
      'flagAsset': 'assets/images/flag_ita.png',
      'labelKey': 'italian',
      'nameDe': 'Italienisch',
      'aliases': ['italienisch', 'italian'],
      'ui': true,
      'seed': false,
      'course': true,
    },
    {
      'code': 'pt',
      'flagAsset': 'assets/images/flag_por.png',
      'labelKey': 'portuguese',
      'nameDe': 'Portugiesisch',
      'aliases': ['portugiesisch', 'portuguese'],
      'ui': true,
      'seed': false,
      'course': true,
    },
  ],
};

void main() {
  setUp(() {
    StorageErrorBus.instance.clear();
    resetLanguageRegistry();
  });
  tearDown(() {
    StorageErrorBus.instance.clear();
    resetLanguageRegistry();
  });

  group('SettingsScreen – Crash-Fix (Ticket #71)', () {
    testWidgets('rendert mit installiertem it-Dict ohne Exception',
        (tester) async {
      // it ist KEINE Default-UI-Sprache: Vorher warf das `appLanguages
      // .firstWhere` in der build-Methode einen StateError ("No element") ->
      // weisser Bildschirm. Jetzt greift der sichere Lookup.
      await _pumpSettings(tester, dictLanguages: const {'de', 'en', 'it'});

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(ChoiceChip, 'Deutsch'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Englisch'), findsOneWidget);
      // Nicht-UI-Sprache: Label ueber den deutschen Kursnamen (Fallback).
      expect(find.widgetWithText(ChoiceChip, 'Italienisch'), findsOneWidget);
    });

    testWidgets('rendert mit installiertem pt-Dict ohne Exception',
        (tester) async {
      await _pumpSettings(tester, dictLanguages: const {'de', 'pt'});

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(ChoiceChip, 'Portugiesisch'), findsOneWidget);
    });
  });

  group('SettingsScreen – it/pt als App-Sprachen (Ticket #71)', () {
    testWidgets('Sprachwahl (FlagBox) und Chips zeigen it/pt', (tester) async {
      await _pumpSettings(tester,
          dictLanguages: const {'de', 'en', 'it', 'pt'},
          languageConfig: _configItPtUi);

      expect(tester.takeException(), isNull);
      // UI-Sprachwahl: it/pt erscheinen als FlagBox (languages.json ui:true).
      expect(find.widgetWithText(FlagBox, 'Italienisch'), findsOneWidget);
      expect(find.widgetWithText(FlagBox, 'Portugiesisch'), findsOneWidget);
      // Muttersprachen-Chips: lokalisierte Labels ueber l10n.italian/portuguese.
      expect(find.widgetWithText(ChoiceChip, 'Italienisch'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Portugiesisch'), findsOneWidget);
    });

    testWidgets('Muttersprache it ist als Chip vorausgewaehlt', (tester) async {
      await _pumpSettings(tester,
          dictLanguages: const {'de', 'it'},
          mLang: 'it',
          languageConfig: _configItPtUi);

      expect(tester.takeException(), isNull);
      final itChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Italienisch'));
      final deChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Deutsch'));
      expect(itChip.selected, isTrue);
      expect(deChip.selected, isFalse);
    });

    testWidgets('changeLanguage(italienisch) wechselt das Locale auf it',
        (tester) async {
      await _pumpSettings(tester, languageConfig: _configItPtUi);

      // Aliases aus der Config: "italienisch" -> Code "it" -> appLocale it.
      final dataState = tester
          .element(find.byType(SettingsScreen))
          .read<DataState>();
      await dataState.changeLanguage('italienisch');

      expect(dataState.appLocale, const Locale('it'));
    });
  });
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'managers/user_state.dart';
import 'managers/data_state.dart';
import 'managers/navigation_state.dart';
import 'managers/grammar_manager.dart';
import 'managers/vocab_manager.dart';
import 'managers/vocab_queries.dart';
import 'managers/user_manager.dart';
import 'services/file_service.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'screens/loading_screen.dart';
import 'screens/start_screen.dart';
import 'screens/learning_screen.dart';
import 'screens/category_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/word_screen.dart';
import 'screens/due_word_screen.dart';
import 'screens/game_choose_screen.dart';
import 'screens/turbo_lv_select_screen.dart';
import 'screens/game_screen.dart';
import 'screens/grammar_detail_screen.dart';
import 'screens/grammar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/progress_group_screen.dart';

/// Startet die App OHNE schweren Block vor dem ersten Frame.
///
/// [WidgetsFlutterBinding.ensureInitialized] ist synchron und läuft zwingend
/// vor allen Plugin-Aufrufen. Danach werden nur die kostengünstigen Manager
/// erzeugt und verdrahtet; `runApp` läuft sofort. Die aufwändigen Schritte
/// (FileSystem-/App-Daten-Initialisierung, Auto-Login inkl. genau eines
/// Vocab-Init- + Migrationslaufs) übernimmt der [LoadingScreen], der den
/// Fortschritt anzeigt und erst danach nach `/start` navigiert – so wächst
/// die Startzeit nicht mehr mit dem Wortschatz.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Best-Effort: immersiver Vollbildmodus (muss nicht auf den ersten Frame
  // warten).
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));

  final fileService = FileServiceImpl();
  final userManager = UserManagerImpl(fileService);
  final vocabManager = VocabManagerImpl(userManager, fileService);
  final vocabQueries = VocabQueriesImpl(userManager);
  final grammarManager = GrammarManagerImpl(fileService);

  final dataState = DataState(fileService);
  final navigationState = NavigationState();
  final userState =
      UserState(userManager: userManager, vocabManager: vocabManager);
  final audioService =
      AudioService(fileService: fileService, userManager: userManager);

  runApp(MultiProvider(
    providers: [
      Provider<FileService>.value(value: fileService),
      Provider<UserManager>.value(value: userManager),
      Provider<VocabQueries>.value(value: vocabQueries),
      Provider<GrammarManager>.value(value: grammarManager),
      Provider<AudioService>.value(value: audioService),
      ChangeNotifierProvider.value(value: dataState),
      ChangeNotifierProvider.value(value: navigationState),
      ChangeNotifierProvider.value(value: userState),
    ],
    child: const LearnALanguageApp(),
  ));
}

class LearnALanguageApp extends StatelessWidget {
  const LearnALanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dataState = context.watch<DataState>();
    return MaterialApp(
      title: AppTheme.appTitle,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      locale: dataState.appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [routeObserver],
      // Globaler, einmaliger Kanäle für Speicherwarnungen (SnackBar statt
      // Dialog), auch für Meldungen, die der LoadingScreen während des
      // Auto-Logins auslöst.
      builder: (context, child) =>
          StorageWarningListener(child: child ?? const SizedBox.shrink()),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/start': (context) => const StartScreen(),
        '/learning': (context) => const LearningScreen(),
        '/category': (context) => const CategoryScreen(),
        '/collection': (context) => const CollectionScreen(),
        '/word': (context) => const WordScreen(),
        '/dueword': (context) => const DueWordScreen(),
        '/gameselect': (context) => const TurboLevelSelectScreen(),
        '/gamechoose': (context) => const GameChooseScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/grammar': (context) => const GrammarScreen(),
        '/grammardetail': (context) => const GrammarDetailScreen(),
        '/progress': (context) => const ProgressScreen(),
        '/progress_group': (context) => const ProgressGroupScreen(),
      },
    );
  }
}

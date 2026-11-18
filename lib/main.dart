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
import 'theme/app_theme.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive Fullscreen – Statusleiste + Navigation ausblenden
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final fileService = FileServiceImpl();
  final userManager = UserManagerImpl(fileService);
  final vocabManager = VocabManagerImpl(userManager, fileService);
  final vocabQueries = VocabQueriesImpl(userManager);
  final grammarManager = GrammarManagerImpl(fileService);

  final dataState = DataState(fileService);
  await dataState.initialize();

  final navigationState = NavigationState();
  final userState = UserState(
      userManager: userManager, vocabManager: vocabManager);
  final uname = dataState.appData.loggedUName;
  if (uname.isNotEmpty) {
    await vocabManager.migrateVocabForUser(uname);
    await userState.login(uname);
    await dataState.loadAppData();
  }

  runApp(MultiProvider(
    providers: [
      Provider<FileService>.value(value: fileService),
      Provider<UserManager>.value(value: userManager),
      Provider<VocabQueries>.value(value: vocabQueries),
      Provider<GrammarManager>.value(value: grammarManager),
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

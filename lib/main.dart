import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'managers/user_state.dart';
import 'managers/data_state.dart';
import 'managers/navigation_state.dart';
import 'managers/vocab_manager.dart';
import 'managers/vocab_queries.dart';
import 'managers/user_manager.dart';
import 'services/file_service.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';
import 'screens/start_screen.dart';
import 'screens/learning_screen.dart';
import 'screens/word_screen.dart';
import 'screens/due_word_screen.dart';
import 'screens/game_select_screen.dart';
import 'screens/game_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive Fullscreen – Statusleiste + Navigation ausblenden
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final fileService = FileServiceImpl();
  final userManager = UserManagerImpl(fileService);
  final vocabManager = VocabManagerImpl(userManager, fileService);
  final vocabQueries = VocabQueriesImpl(userManager);

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
    return MaterialApp(
      title: AppTheme.appTitle,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/start': (context) => const StartScreen(),
        '/learning': (context) => const LearningScreen(),
        '/word': (context) => const WordScreen(),
        '/dueword': (context) => const DueWordScreen(),
        '/gameselect': (context) => const GameSelectScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

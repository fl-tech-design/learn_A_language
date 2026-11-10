import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'managers/app_state.dart';
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

  final appState = AppState();
  await appState.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const LearnALanguageApp(),
    ),
  );
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

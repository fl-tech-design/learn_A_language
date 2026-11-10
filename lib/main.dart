import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const LoadingScreen(),
        ),
        GoRoute(
          path: '/start',
          builder: (_, __) => const StartScreen(),
        ),
        GoRoute(
          path: '/learning',
          builder: (_, __) => const LearningScreen(),
        ),
        GoRoute(
          path: '/word',
          builder: (_, __) => const WordScreen(),
        ),
        GoRoute(
          path: '/dueword',
          builder: (_, __) => const DueWordScreen(),
        ),
        GoRoute(
          path: '/gameselect',
          builder: (_, __) => const GameSelectScreen(),
        ),
        GoRoute(
          path: '/game',
          builder: (_, __) => const GameScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: AppTheme.appTitle,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
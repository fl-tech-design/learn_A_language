// Zentrale Routendefinition (Ticket #50).
//
// Einzige Quelle der Wahrheit für alle Routen: jede Route hat eine Pfad-
// Konstante (AppRoutes.*) und ist in [appRoutes] registriert. main.dart
// referenziert nur noch diese Datei. Ein neuer Screen erfordert genau eine
// Änderung an einer Stelle: hier in [AppRoutes.appRoutes] (und optional eine
// Pfad-Konstante).
import 'package:flutter/material.dart';

import 'screens/category_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/crossword_lv_select_screen.dart';
import 'screens/crossword_screen.dart';
import 'screens/due_word_screen.dart';
import 'screens/fill_in_lv_select_screen.dart';
import 'screens/fill_in_screen.dart';
import 'screens/game_choose_screen.dart';
import 'screens/game_screen.dart';
import 'screens/grammar_detail_screen.dart';
import 'screens/grammar_screen.dart';
import 'screens/hangman_lv_select_screen.dart';
import 'screens/hangman_screen.dart';
import 'screens/learning_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/progress_group_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/start_screen.dart';
import 'screens/turbo_lv_select_screen.dart';
import 'screens/word_screen.dart';
import 'screens/word_search_screen.dart';

/// Pfad-Konstanten für alle Routen. Typsicher: ein Tippfehler wie
/// `AppRoutes.seetings` wird beim Kompilieren gefunden, nicht erst zur
/// Laufzeit.
abstract final class AppRoutes {
  static const String home = '/';
  static const String start = '/start';
  static const String learning = '/learning';
  static const String category = '/category';
  static const String collection = '/collection';
  static const String word = '/word';
  static const String dueword = '/dueword';
  static const String gameselect = '/gameselect';
  static const String gamechoose = '/gamechoose';
  static const String game = '/game';
  static const String wordsearch = '/wordsearch';
  static const String crossword = '/crossword';
  static const String crosswordselect = '/crosswordselect';
  static const String hangman = '/hangman';
  static const String hangmanselect = '/hangmanselect';
  static const String fillin = '/fillin';
  static const String fillinselect = '/fillinselect';
  static const String settings = '/settings';
  static const String grammar = '/grammar';
  static const String grammardetail = '/grammardetail';
  static const String progress = '/progress';
  static const String progressGroup = '/progress_group';
}

/// Routing-Tabelle für [MaterialApp]. Neue Screens hier registrieren.
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.home: (context) => const LoadingScreen(),
  AppRoutes.start: (context) => const StartScreen(),
  AppRoutes.learning: (context) => const LearningScreen(),
  AppRoutes.category: (context) => const CategoryScreen(),
  AppRoutes.collection: (context) => const CollectionScreen(),
  AppRoutes.word: (context) => const WordScreen(),
  AppRoutes.dueword: (context) => const DueWordScreen(),
  AppRoutes.gameselect: (context) => const TurboLevelSelectScreen(),
  AppRoutes.gamechoose: (context) => const GameChooseScreen(),
  AppRoutes.game: (context) => const GameScreen(),
  AppRoutes.wordsearch: (context) => const WordSearchScreen(),
  AppRoutes.crossword: (context) => const CrosswordScreen(),
  AppRoutes.crosswordselect: (context) => const CrosswordLvSelectScreen(),
  AppRoutes.hangman: (context) => const HangmanScreen(),
  AppRoutes.hangmanselect: (context) => const HangmanLvSelectScreen(),
  AppRoutes.fillin: (context) => const FillInScreen(),
  AppRoutes.fillinselect: (context) => const FillInLvSelectScreen(),
  AppRoutes.settings: (context) => const SettingsScreen(),
  AppRoutes.grammar: (context) => const GrammarScreen(),
  AppRoutes.grammardetail: (context) => const GrammarDetailScreen(),
  AppRoutes.progress: (context) => const ProgressScreen(),
  AppRoutes.progressGroup: (context) => const ProgressGroupScreen(),
};

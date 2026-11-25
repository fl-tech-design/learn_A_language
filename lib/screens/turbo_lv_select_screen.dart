import '../routes.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';
import 'game_screen.dart';

/// Turbo level select screen – 1:1 from gameselectpage.py/kv.
class TurboLevelSelectScreen extends StatelessWidget {
  const TurboLevelSelectScreen({super.key});

  void _startGame(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnGame),
        const AppNavBar(),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(children: [
                      SizedBox(
                          height: 80,
                          child: Center(
                              child: Text(l10n.selectDifficulty,
                                  style: const TextStyle(
                                      fontSize: AppTheme.lblFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'easy'),
                              child: Text(l10n.difficultyEasy,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'medium'),
                              child: Text(l10n.difficultyMedium,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'hard'),
                              child: Text(l10n.difficultyHard,
                                  style: const TextStyle(fontSize: 16)))),
                    ])))),
        BoxBottom(
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

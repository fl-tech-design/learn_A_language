import '../routes.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';
import 'hangman_screen.dart';

/// Hangman level select screen – 1:1 analog zum Turbo-/Kreuzwortraetsel-Select.
class HangmanLvSelectScreen extends StatelessWidget {
  const HangmanLvSelectScreen({super.key});

  void _startGame(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HangmanScreen(difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnHangman),
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
                              child: Text(l10n.hangmanEasy,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'medium'),
                              child: Text(l10n.hangmanMedium,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'hard'),
                              child: Text(l10n.hangmanHard,
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

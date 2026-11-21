import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';
import 'fill_in_screen.dart';

/// Fill In level select screen – 1:1 analog zum Turbo-/Kreuzwortraetsel-Select.
class FillInLvSelectScreen extends StatelessWidget {
  const FillInLvSelectScreen({super.key});

  void _startGame(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FillInScreen(difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnFillIn),
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
                              child: Text(l10n.fillInEasy,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'medium'),
                              child: Text(l10n.fillInMedium,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'hard'),
                              child: Text(l10n.fillInHard,
                                  style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.back,
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize,
                                      color: AppTheme.colorPrimary)))),
                    ])))),
        BoxBottom(
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../widgets/app_widgets.dart';
import 'game_screen.dart';

/// Game selection screen – 1:1 from gameselectpage.py/kv.
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  void _startGame(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: at['btn_game']?.toString() ?? 'Spiele'),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(children: [
                      const SizedBox(
                          height: 80,
                          child: Center(
                              child: Text('Wähle eine Schwierigkeit:',
                                  style: TextStyle(
                                      fontSize: AppTheme.lblFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'easy'),
                              child: const Text('Leicht (20s / +3s)',
                                  style: TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'medium'),
                              child: const Text('Mittel (15s / +2s)',
                                  style: TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () => _startGame(context, 'hard'),
                              child: const Text('Schwer (10s / +1s)',
                                  style: TextStyle(fontSize: 16)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(bt['back'] ?? 'zurück',
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize,
                                      color: AppTheme.colorPrimary)))),
                    ])))),
        BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

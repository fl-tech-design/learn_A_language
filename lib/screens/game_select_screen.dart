import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../widgets/app_widgets.dart';

/// Game selection screen – 1:1 from gameselectpage.py/kv.
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: at['btn_game']?.toString() ?? 'Spiele'),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(children: [
                  const SizedBox(
                      height: 100,
                      child: Center(
                          child: Text('Wähle ein Spiel:',
                              style:
                                  TextStyle(fontSize: AppTheme.lblFontSize)))),
                  SizedBox(
                      height: 70,
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/game'),
                          child: Text(at['btn_turbo'] ?? 'Turbo',
                              style: const TextStyle(fontSize: 16)))),
                  const Spacer(),
                  SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(bt['back'] ?? 'zurück',
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize,
                                  color: AppTheme.colorPrimary)))),
                ]))),
        BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

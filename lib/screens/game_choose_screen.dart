import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';

/// Game choose screen – intermediate "Spiel wählen" hub.
class GameChooseScreen extends StatefulWidget {
  const GameChooseScreen({super.key});

  @override
  State<GameChooseScreen> createState() => _GameChooseScreenState();
}

class _GameChooseScreenState extends State<GameChooseScreen> {
  Future<int>? _masteredCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _masteredCount ??= _loadMasteredCount();
  }

  Future<int> _loadMasteredCount() async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final words = await context.read<VocabQueries>().getReadWords(uname);
    return words.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.titChooseGame),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(children: [
                      FutureBuilder<int>(
                          future: _masteredCount,
                          builder: (context, snapshot) {
                            final enabled =
                                snapshot.hasData && snapshot.data! >= 3;
                            return Column(children: [
                              SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: enabled
                                          ? () => Navigator.of(context)
                                              .pushNamed('/gameselect')
                                          : null,
                                      child: Text(l10n.btnTurbo,
                                          style: const TextStyle(
                                              fontSize:
                                                  AppTheme.btnFontSize)))),
                              const SizedBox(
                                  height: AppTheme.contentSpacing),
                              SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: enabled
                                          ? () => Navigator.of(context)
                                              .pushNamed('/wordsearch')
                                          : null,
                                      child: Text(l10n.btnWordSearch,
                                          style: const TextStyle(
                                              fontSize:
                                                  AppTheme.btnFontSize)))),
                              const SizedBox(
                                  height: AppTheme.contentSpacing),
                              SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: enabled
                                          ? () => Navigator.of(context)
                                              .pushNamed('/crosswordselect')
                                          : null,
                                      child: Text(l10n.btnCrossword,
                                          style: const TextStyle(
                                              fontSize:
                                                  AppTheme.btnFontSize)))),
                              const SizedBox(
                                  height: AppTheme.contentSpacing),
                              SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: enabled
                                          ? () => Navigator.of(context)
                                              .pushNamed('/hangmanselect')
                                          : null,
                                      child: Text(l10n.btnHangman,
                                          style: const TextStyle(
                                              fontSize:
                                                  AppTheme.btnFontSize)))),
                              const SizedBox(
                                  height: AppTheme.contentSpacing),
                              SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: enabled
                                          ? () => Navigator.of(context)
                                              .pushNamed('/fillinselect')
                                          : null,
                                      child: Text(l10n.btnFillIn,
                                          style: const TextStyle(
                                              fontSize:
                                                  AppTheme.btnFontSize)))),
                            ]);
                          }),
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

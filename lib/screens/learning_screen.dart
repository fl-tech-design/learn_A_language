import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';

/// Learning category selection screen – 1:1 from learningpage.py/kv.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  int _dueCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDueCount();
  }

  Future<void> _refreshDueCount() async {
    final appState = context.read<AppState>();
    final uname = appState.loggedUName;
    if (uname.isNotEmpty) {
      final count = await VocabQueries.getWordsDueCount(uname);
      if (mounted) setState(() => _dueCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: at['tit_page_learning']?.toString() ?? 'Lernen',
            onInfo: () => showInfoDialog(context,
                at['inf_learning']?.toString() ?? '',
                bt['information']?.toString() ?? 'Information')),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(children: [
                  SizedBox(
                      height: 120,
                      child: Center(
                          child: Text(at['cat_select'] ?? 'Wähle eine Kategorie',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: AppTheme.lblFontSize)))),
                  const SizedBox(height: AppTheme.contentSpacing),
                  SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: () {
                            appState.setWordMode('new');
                            Navigator.of(context).pushNamed('/word');
                          },
                          child: Text(at['cat_new_words'] ?? 'Neue Wörter',
                              style: const TextStyle(fontSize: AppTheme.btnFontSize)))),
                  const SizedBox(height: AppTheme.contentSpacing),
                  SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: _dueCount == 0
                              ? null
                              : () => Navigator.of(context).pushNamed('/dueword'),
                          child: Text(
                              '${at['cat_due_words'] ?? 'Fällige Wörter'} ($_dueCount)',
                              style: const TextStyle(fontSize: AppTheme.btnFontSize)))),
                  const SizedBox(height: AppTheme.contentSpacing),
                  SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: () {
                            appState.setWordMode('learned');
                            Navigator.of(context).pushNamed('/word');
                          },
                          child: Text(at['cat_learned_words'] ?? 'Gelernte Wörter',
                              style: const TextStyle(fontSize: AppTheme.btnFontSize)))),
                  const Spacer(),
                  SizedBox(
                      height: 50, width: double.infinity,
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
            onSettings: () => Navigator.of(context).pushNamed('/settings')),
      ]),
    );
  }
}
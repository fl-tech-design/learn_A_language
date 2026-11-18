import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';
import 'progress_screen.dart' show wordCategoryTitle;

/// Learning category selection screen.
///
/// Zeigt die gleichen Verb-Kategorien wie der Lernfortschritt. Ein Tipp auf
/// eine Kategorie startet das Lernen dieser Gruppe. Darunter bleiben die
/// klassischen Modi (Neue/Faellige/Gelernte Woerter) fuer den ganzen Kurs.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with RouteAware {
  int _dueCount = 0;
  Map<String, CategoryCounts> _counts = {};
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDueCount();
    _refreshCounts();
    if (!_subscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _subscribed = true;
      }
    }
  }

  @override
  void didPopNext() {
    _refreshDueCount();
    _refreshCounts();
  }

  @override
  void dispose() {
    if (_subscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _refreshDueCount() async {
    final uname = context.read<DataState>().appData.loggedUName;
    if (uname.isNotEmpty) {
      final count = await context.read<VocabQueries>().getWordsDueCount(uname);
      if (mounted) setState(() => _dueCount = count);
    }
  }

  Future<void> _refreshCounts() async {
    final uname = context.read<DataState>().appData.loggedUName;
    if (uname.isEmpty) return;
    final counts = await context.read<VocabQueries>().getCategoryCounts(uname);
    if (mounted) setState(() => _counts = counts);
  }

  String _countLabel(AppLocalizations l10n, CategoryCounts? c) {
    if (c == null || !c.hasWords) return '';
    return '${c.newCount} ${l10n.labNewShort} · '
        '${c.dueCount} ${l10n.labDueShort}';
  }

  /// Startet das Lernen der neuen Woerter einer Kategorie.
  void _startLearning(WordCategory category) {
    final nav = context.read<NavigationState>();
    nav.setWordMode('new');
    nav.setSelectedCategoryId(category.id);
    Navigator.of(context).pushNamed('/word');
  }

  /// Startet das Lernen der neuen Woerter des ganzen Kurses.
  void _startAllNew() {
    final nav = context.read<NavigationState>();
    nav.setWordMode('new');
    nav.setSelectedCategoryId(null);
    Navigator.of(context).pushNamed('/word');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = courseWordCategories.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: l10n.titPageLearning,
            onInfo: () => showInfoDialog(
                context, l10n.infLearning, l10n.information)),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(children: [
                      const SizedBox(height: 8),
                      Text(l10n.catSelect,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: AppTheme.contentSpacing),
                      for (final cat in categories)
                        Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.contentSpacing),
                            child: SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: OutlinedButton(
                                    onPressed: () => _startLearning(cat),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                  wordCategoryTitle(l10n, cat),
                                                  textAlign:
                                                      TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: AppTheme
                                                          .btnFontSize)),
                                            ),
                                            Text(
                                              _countLabel(
                                                  l10n, _counts[cat.id]),
                                              style: const TextStyle(
                                                  fontSize:
                                                      AppTheme.smallFontSize,
                                                  color: AppTheme.grey4),
                                            ),
                                          ],
                                        ))))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: _startAllNew,
                              child: Text(l10n.btnNewWords,
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: _dueCount == 0
                                  ? null
                                  : () =>
                                      Navigator.of(context).pushNamed('/dueword'),
                              child: Text(
                                  '${l10n.catDueWords} ($_dueCount)',
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: () {
                                context.read<NavigationState>().setWordMode('learned');
                                Navigator.of(context).pushNamed('/word');
                              },
                              child: Text(l10n.catLearnedWords,
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
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

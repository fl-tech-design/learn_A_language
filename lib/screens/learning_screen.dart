import '../routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';
import 'progress_screen.dart'
    show categoryCountLabel, wordCollectionTitle, wordTopCategoryTitle;

/// Learning category selection screen.
///
/// Zeigt die Lern-Sammlungen ("Erste Verben" direkt lernbar, "Weitere Verben"
/// mit 5 Unterkategorien) sowie den Ordner "Gelernte Wörter" mit allen fertig
/// gelernten Wörtern (maxLevel). Ein Tipp öffnet den Kategorie- bzw.
/// Sammlungs-Screen. In jeder Kategorie gibt es die Modi Neue/Fällige/Gelesene
/// Wörter – jeweils nur mit den Daten dieser Kategorie.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with RouteAware {
  Map<String, CategoryCounts> _counts = {};
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _refreshCounts();
  }

  @override
  void dispose() {
    if (_subscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final uname = context.read<DataState>().appData.loggedUName;
    if (uname.isEmpty) return;
    final lang = context
        .read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    final counts = await context
        .read<VocabQueries>()
        .getCategoryCounts(uname, langCode: lang);
    if (mounted) setState(() => _counts = counts);
  }

  /// Aggregiert die Zähler aller Kategorien einer Sammlung.
  CategoryCounts _sumCounts(WordCollection collection) {
    var total = 0;
    var n = 0;
    var d = 0;
    var l = 0;
    for (final catId in collection.categoryIds) {
      final c = _counts[catId];
      if (c == null) continue;
      total += c.total;
      n += c.newCount;
      d += c.dueCount;
      l += c.learnedCount;
    }
    return CategoryCounts(
      total: total,
      newCount: n,
      dueCount: d,
      learnedCount: l,
    );
  }

  /// Öffnet eine Sammlung: "Erste Verben" direkt als Kategorie, "Weitere
  /// Verben" als Unterkategorien-Liste.
  void _openCollection(WordCollection collection) {
    if (collection.categories.length == 1) {
      Navigator.of(context).pushNamed(AppRoutes.category,
          arguments: collection.categoryIds.first);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.collection,
          arguments:
              CollectionScreenArgs(collectionId: collection.id, mode: 'learn'));
    }
  }

  /// Anzahl aller fertig gelernten Wörter (maxLevel) über alle Kategorien.
  int get _learnedAllCount {
    var l = 0;
    for (final c in _counts.values) {
      l += c.learnedCount;
    }
    return l;
  }

  /// Öffnet den Ordner „Gelernte Wörter": alle auf maxLevel gelernten Karten.
  void _openLearnedWords() {
    if (_learnedAllCount == 0) return;
    final nav = context.read<NavigationState>();
    nav.setWordMode('learned');
    nav.setSelectedCategoryId(null);
    Navigator.of(context).pushNamed(AppRoutes.word);
  }

  /// Ordner-Button für alle fertig gelernten Wörter (maxLevel).
  Widget _learnedWordsButton() {
    final l10n = AppLocalizations.of(context);
    final count = _learnedAllCount;
    return SizedBox(
        height: 50,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: count == 0 ? null : _openLearnedWords,
          child: Text('${l10n.catLearnedWords} ($count)',
              style: const TextStyle(fontSize: AppTheme.btnFontSize)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topCategories = courseTopCategories.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: l10n.titPageLearning,
            onInfo: () =>
                showInfoDialog(context, l10n.infLearning, l10n.information)),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(children: [
                      const SizedBox(height: 8),
                      Text(l10n.catSelect,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: AppTheme.contentSpacing),
                      for (final top in topCategories) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            wordTopCategoryTitle(l10n, top),
                            style: const TextStyle(
                                fontSize: AppTheme.lblFontSize,
                                color: AppTheme.colorPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (final collection in top.collections)
                          Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppTheme.contentSpacing),
                              child: SizedBox(
                                  height: 50,
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: () =>
                                          _openCollection(collection),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                    wordCollectionTitle(
                                                        l10n, collection),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: AppTheme
                                                            .btnFontSize)),
                                              ),
                                              Text(
                                                _sumCounts(collection).hasWords
                                                    ? categoryCountLabel(l10n,
                                                        _sumCounts(collection))
                                                    : '',
                                                style: const TextStyle(
                                                    fontSize:
                                                        AppTheme.smallFontSize,
                                                    color: AppTheme.grey4),
                                              ),
                                            ],
                                          ))))),
                      ],
                      const SizedBox(height: AppTheme.contentSpacing),
                      _learnedWordsButton(),
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
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

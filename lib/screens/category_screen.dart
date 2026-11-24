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
import 'progress_screen.dart' show wordCategoryTitle;

/// Unterkategorie-Screen.
///
/// Zeigt für eine [WordCategory] die drei Lern-Modi – Neue Wörter, Fällige
/// Wörter, Gelernte Wörter – jeweils nur mit den Daten dieser Kategorie.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> with RouteAware {
  WordCategory? _category;
  CategoryCounts? _counts;
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeId = ModalRoute.of(context)?.settings.arguments as String?;
    if (_category == null && routeId != null) {
      _category = wordCategoryById(routeId);
    }
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
    final cat = _category;
    if (uname.isEmpty || cat == null) return;
    final lang = context.read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    final counts = await context
        .read<VocabQueries>()
        .getGroupCounts(uname, cat, langCode: lang);
    if (mounted) setState(() => _counts = counts);
  }

  /// Startet einen Modus ('new' | 'due' | 'read') für diese Kategorie.
  void _start(String mode) {
    final nav = context.read<NavigationState>();
    final cat = _category;
    if (cat == null) return;
    if (mode == 'new') {
      nav.setWordMode('new');
    } else if (mode == 'read') {
      nav.setWordMode('read');
    }
    // 'due' übernimmt den wordMode unverändert (eigener Screen).
    nav.setSelectedCategoryId(cat.id);
    final route = mode == 'due' ? '/dueword' : '/word';
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = _counts ?? const CategoryCounts();
    final cat = _category;

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: cat != null ? wordCategoryTitle(l10n, cat) : '',
            onInfo: () => showInfoDialog(
                context, l10n.infLearning, l10n.information)),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.contentPadding),
              child: Column(children: [
                const SizedBox(height: AppTheme.contentSpacing),
                _modeButton(l10n.catNewWords, counts.newCount,
                    () => _start('new')),
                const SizedBox(height: AppTheme.contentSpacing),
                _modeButton(
                    l10n.catDueWords,
                    counts.dueCount,
                    counts.dueCount == 0 ? null : () => _start('due')),
                const SizedBox(height: AppTheme.contentSpacing),
                _modeButton(
                    l10n.catReadWords,
                    counts.readCount,
                    counts.readCount == 0 ? null : () => _start('read')),
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
                const SizedBox(height: AppTheme.contentSpacing),
                SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: (cat == null || counts.total == 0)
                            ? null
                            : () => Navigator.of(context).pushNamed(
                                '/progress_group', arguments: cat.id),
                        child: Text(l10n.btnProgress,
                            style: const TextStyle(
                                fontSize: AppTheme.btnFontSize)))),
              ]),
            ),
          ),
        ),
        BoxBottom(
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _modeButton(String label, int count, VoidCallback? onPressed) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text('$label ($count)',
            style: const TextStyle(fontSize: AppTheme.btnFontSize)),
      ),
    );
  }
}

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
    show categoryCountLabel, wordCollectionTitle, wordCategoryTitle;

/// Sammlungs-Screen.
///
/// Listet die Unterkategorien einer [WordCollection] auf (z. B. "Weitere
/// Verben"). Im Modus 'learn' öffnet eine Kategorie den [CategoryScreen], im
/// Modus 'progress' die read-only Fortschritts-Gruppe.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with RouteAware {
  WordCollection? _collection;
  String _mode = 'learn';
  Map<String, CategoryCounts> _counts = {};
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CollectionScreenArgs && _collection == null) {
      _collection = wordCollectionById(args.collectionId);
      _mode = args.mode;
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
    if (uname.isEmpty) return;
    final lang = context
        .read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    final counts = await context
        .read<VocabQueries>()
        .getCategoryCounts(uname, langCode: lang);
    if (mounted) setState(() => _counts = counts);
  }

  void _open(WordCategory cat) {
    if (_mode == 'progress') {
      Navigator.of(context)
          .pushNamed(AppRoutes.progressGroup, arguments: cat.id);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.category, arguments: cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collection = _collection;
    final categories = collection?.categories ?? const <WordCategory>[];

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title:
                collection != null ? wordCollectionTitle(l10n, collection) : '',
            onInfo: () =>
                showInfoDialog(context, l10n.infLearning, l10n.information)),
        const AppNavBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.contentPadding),
              child: Column(children: [
                const SizedBox(height: 8),
                Text(l10n.catSelectSubcategory,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: AppTheme.lblFontSize)),
                const SizedBox(height: AppTheme.contentSpacing),
                for (final cat in categories)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppTheme.contentSpacing),
                    child: SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _open(cat),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  wordCategoryTitle(l10n, cat),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize),
                                ),
                              ),
                              Text(
                                _counts[cat.id] != null &&
                                        _counts[cat.id]!.hasWords
                                    ? categoryCountLabel(l10n, _counts[cat.id]!)
                                    : '',
                                style: const TextStyle(
                                    fontSize: AppTheme.smallFontSize,
                                    color: AppTheme.grey4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        BoxBottom(
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

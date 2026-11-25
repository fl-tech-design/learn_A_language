import '../routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';
import '../models/language_registry.dart';

/// Liefert den lokalisierten Titel einer [WordCategory] anhand ihres l10n-Keys.
String wordCategoryTitle(AppLocalizations l10n, WordCategory category) {
  switch (category.titleKey) {
    case 'catFirstVerbs':
      return l10n.catFirstVerbs;
    case 'catGrpAlltag':
      return l10n.catGrpAlltag;
    case 'catGrpMovement':
      return l10n.catGrpMovement;
    case 'catGrpLearning':
      return l10n.catGrpLearning;
    case 'catGrpWork':
      return l10n.catGrpWork;
    case 'catGrpEnjoy':
      return l10n.catGrpEnjoy;
    default:
      return category.id;
  }
}

/// Liefert den lokalisierten Titel einer [WordCollection].
String wordCollectionTitle(AppLocalizations l10n, WordCollection collection) {
  switch (collection.titleKey) {
    case 'catFirstVerbs':
      return l10n.catFirstVerbs;
    case 'catMoreVerbs':
      return l10n.catMoreVerbs;
    default:
      return collection.id;
  }
}

/// Liefert den lokalisierten Titel einer Überkategorie (Dach-Ebene).
String wordTopCategoryTitle(AppLocalizations l10n, CourseTopCategory top) {
  switch (top.titleKey) {
    case 'catVerbs':
      return l10n.catVerbs;
    default:
      return top.id;
  }
}

/// Kurz-Label mit den Zählern einer Kategorie, z. B. "3 neu · 2 fällig ·
/// 1 gelernt".
String categoryCountLabel(AppLocalizations l10n, CategoryCounts c) {
  return '${c.newCount} ${l10n.labNewShort} · '
      '${c.dueCount} ${l10n.labDueShort} · '
      '${c.learnedCount} ${l10n.labLearnedShort}';
}

/// Lernfortschritt – Sammlungs-Übersicht.
///
/// Gleiches Layout wie der Lernen-Screen: Zeigt die Lern-Sammlungen ("Erste
/// Verben" direkt, "Weitere Verben" mit Unterkategorien). Ein Tipp öffnet die
/// read-only Fortschritts-Gruppe bzw. den Unterkategorie-Screen.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = context
        .watch<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    final topCategories = courseTopCategories.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: l10n.titPageProgress,
            onInfo: () =>
                showInfoDialog(context, l10n.infProgress, l10n.information),
          ),
          const AppNavBar(),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(courseFlagAsset(lang), width: 24, height: 16),
                  const SizedBox(width: 6),
                  Text(courseLanguageName(lang),
                      style: const TextStyle(
                          fontSize: AppTheme.smallFontSize,
                          color: AppTheme.grey4)),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                  children: [
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
                              onPressed: () {
                                if (collection.categories.length == 1) {
                                  Navigator.of(context).pushNamed(
                                      AppRoutes.progressGroup,
                                      arguments: collection.categoryIds.first);
                                } else {
                                  Navigator.of(context).pushNamed(
                                      AppRoutes.collection,
                                      arguments: CollectionScreenArgs(
                                          collectionId: collection.id,
                                          mode: 'progress'));
                                }
                              },
                              child: Text(
                                wordCollectionTitle(l10n, collection),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: AppTheme.btnFontSize),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

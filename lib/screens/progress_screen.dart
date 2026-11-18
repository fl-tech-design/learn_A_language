import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';

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
    final collections =
        courseWordCollections.toList()..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: l10n.titPageProgress,
            onInfo: () => showInfoDialog(
                context, l10n.infProgress, l10n.information),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Lernfortschritt',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: AppTheme.lblFontSize),
                        ),
                      ),
                    ),
                    for (final collection in collections)
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
                                    '/progress_group',
                                    arguments:
                                        collection.categoryIds.first);
                              } else {
                                Navigator.of(context).pushNamed(
                                    '/collection',
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
                    const SizedBox(height: AppTheme.contentSpacing),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.back,
                          style: const TextStyle(
                              fontSize: AppTheme.btnFontSize,
                              color: AppTheme.colorPrimary),
                        ),
                      ),
                    ),
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
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

/// Lernfortschritt – Kategorie-Übersicht.
///
/// Gleiches Layout wie der Lernen-Screen: Zeigt die Word-Kategorien eines
/// Kurses. Ein Tipp auf eine Kategorie öffnet die read-only Wortliste mit den
/// aktuellen Levels (siehe ProgressGroupScreen).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories =
        courseWordCategories.toList()..sort((a, b) => a.order.compareTo(b.order));

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
                    for (final cat in categories)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppTheme.contentSpacing),
                        child: SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pushNamed(
                                '/progress_group',
                                arguments: cat.id),
                            child: Text(
                              wordCategoryTitle(l10n, cat),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/grammar_models.dart';
import '../managers/grammar_manager.dart';
import '../managers/user_state.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';

/// Grammar topic list screen. Shows the grammar categories, each listing its
/// topics (blocks). Tapping a topic opens the detail screen.
///
/// Accepts an optional `String` level argument (e.g. `'B1'`) via the route
/// settings. When present, only grammar topics for that CEFR level are shown
/// (loaded from the level-specific asset).
class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = _nativeLang(context);

    // Optional route argument: the CEFR level of the opened course.
    final levelArg = ModalRoute.of(context)?.settings.arguments;
    final level = levelArg is String ? levelArg : null;

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: l10n.titPageGrammar,
            onInfo: () => showInfoDialog(
                context, l10n.infGrammar, l10n.information)),
        Expanded(
            child: FutureBuilder<GrammarDocument>(
          future: context.read<GrammarManager>().load(level: level),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.colorPrimary));
            }
            final doc = snapshot.data!;
            final categories = doc.sortedCategories;
            if (categories.isEmpty && doc.blocks.isEmpty) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(AppTheme.contentPadding),
                      child: Text(l10n.grammarNoTopics,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: AppTheme.infFontSize,
                              color: AppTheme.grey4))));
            }
            return ListView(
              padding: const EdgeInsets.all(AppTheme.contentPadding),
              children: [
                for (final category in categories) ...[
                  _CategoryHeader(
                    title: category.title.pick(lang) ?? category.id,
                    count: doc.blocksOfCategory(category.id).length,
                  ),
                  for (final block in doc.blocksOfCategory(category.id))
                    _TopicTile(
                      block: block,
                      lang: lang,
                      onTap: () => Navigator.of(context).pushNamed(
                          '/grammardetail',
                          arguments: block),
                    ),
                ],
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
              ],
            );
          },
        )),
        BoxBottom(
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

String _nativeLang(BuildContext context) {
  final mLang = context.read<UserState>().userData?.mLang;
  return (mLang == 'en') ? 'en' : 'de';
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final int count;

  const _CategoryHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text('$title  ($count)',
          style: const TextStyle(
              fontSize: AppTheme.lblFontSize,
              color: AppTheme.colorPrimary,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final GrammarBlock block;
  final String lang;
  final VoidCallback onTap;

  const _TopicTile({
    required this.block,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = block.title.pick(lang) ?? block.id;
    final summary = block.summary.pick(lang);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: AppTheme.grey3),
            borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: AppTheme.infFontSize, color: Colors.white)),
                if (summary != null && summary.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(summary,
                          style: const TextStyle(
                              fontSize: AppTheme.smallFontSize,
                              color: AppTheme.grey4))),
              ])),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.grey2,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(block.level,
                  style: const TextStyle(
                      fontSize: AppTheme.smallFontSize,
                      color: AppTheme.colorPrimary))),
        ]),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../l10n/app_localizations.dart';
import 'progress_screen.dart' show wordCategoryTitle;

/// Read-only Wortliste einer Word-Kategorie mit den aktuellen Levels.
///
/// Anzeige im Stil einer Exceltabelle: pro Verb ein Abschnitt, darunter die
/// 18 konjugierten Formen (3 Zeitformen x 6 Personen), je Zeile das Wort der
/// Lernsprache und rechts ein farbiger Level-Kreis:
/// grau = Level 0 (neu), farbig = Level 1-7 (in Arbeit), gruen = Level 8
/// (gelernt, abgehakt).
class ProgressGroupScreen extends StatefulWidget {
  const ProgressGroupScreen({super.key});

  @override
  State<ProgressGroupScreen> createState() => _ProgressGroupScreenState();
}

class _ProgressGroupScreenState extends State<ProgressGroupScreen> {
  WordCategory? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dataState = context.watch<DataState>();
    final uname = dataState.appData.loggedUName;

    final routeId = ModalRoute.of(context)?.settings.arguments as String?;
    if (_category == null && routeId != null) {
      _category = _categoryById(routeId);
    }
    final category = _category;

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: category != null ? wordCategoryTitle(l10n, category) : '',
            onInfo: () => showInfoDialog(context, l10n.infProgress, l10n.information),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: Text(l10n.back),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.colorPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          ),
          Expanded(
            child: uname.isEmpty || category == null
                ? const SizedBox.shrink()
                : FutureBuilder<List<VocabEntry>>(
                    future: context.read<VocabQueries>().getGroupWords(uname, category),
                    builder: (context, snapshot) {
                      final entries = snapshot.data;
                      if (entries == null) {
                        return const Center(child: Text('...'));
                      }
                      if (entries.isEmpty) {
                        return Center(child: Text(l10n.noWords));
                      }
                      return _buildList(l10n, category, entries);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  WordCategory? _categoryById(String id) {
    for (final c in courseWordCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Widget _buildList(
      AppLocalizations l10n, WordCategory category, List<VocabEntry> entries) {
    final learned = entries.where((e) => e.level >= 8).length;
    final inProgress = entries.where((e) => e.level >= 1 && e.level < 8).length;
    final newCount = entries.where((e) => e.level == 0).length;

    final byVerb = <String, Map<String, List<VocabEntry>>>{};
    for (final e in entries) {
      final verb = vocabVerbKey(e.key);
      final tense = vocabTenseKey(e.key);
      byVerb.putIfAbsent(verb, () => {});
      byVerb[verb]!.putIfAbsent(tense, () => []);
      byVerb[verb]![tense]!.add(e);
    }

    final tenses = ['past', 'present', 'future'];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.contentPadding),
      children: [
        _summaryRow(l10n, learned, inProgress, newCount),
        const SizedBox(height: AppTheme.contentSpacing),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.colWord,
                    style: const TextStyle(fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
              ),
              Text(l10n.colLevel,
                  style: const TextStyle(fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final verb in category.verbKeys) ...[
          if (byVerb.containsKey(verb)) ...[
            _verbHeader(verb),
            for (final tense in tenses)
              if (byVerb[verb]!.containsKey(tense)) ...[
                _tenseHeader(l10n, tense),
                for (final e in byVerb[verb]![tense]!) _wordRow(e),
              ],
          ],
        ],
        const SizedBox(height: AppTheme.contentSpacing),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.back,
                style: const TextStyle(fontSize: AppTheme.btnFontSize, color: AppTheme.colorPrimary)),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(AppLocalizations l10n, int learned, int inProgress, int newCount) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grey3)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItemApp(AppTheme.green2, '$learned', l10n.catLearnedWords),
          _summaryItemApp(AppTheme.orange1, '$inProgress', l10n.catDueWords),
          _summaryItemApp(AppTheme.grey4, '$newCount', l10n.catNewWords),
        ],
      ),
    );
  }

  Widget _summaryItemApp(Color color, String count, String label) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(fontSize: AppTheme.lblFontSize, color: color, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      ],
    );
  }

  Widget _verbHeader(String verb) {
    final name = _prettifyVerb(verb);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.grey2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(name,
          style: const TextStyle(fontSize: AppTheme.infFontSize, color: AppTheme.colorPrimary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tenseHeader(AppLocalizations l10n, String tense) {
    final label = switch (tense) {
      'past' => l10n.tensePast,
      'present' => l10n.tensePresent,
      _ => l10n.tenseFuture,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 2),
      child: Text(label,
          style: const TextStyle(fontSize: AppTheme.smallFontSize, color: AppTheme.grey5)),
    );
  }

  Widget _wordRow(VocabEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(e.word,
                style: const TextStyle(fontSize: AppTheme.infFontSize, color: Colors.white)),
          ),
          _LevelCircle(level: e.level),
        ],
      ),
    );
  }

  String _prettifyVerb(String verb) {
    var base = verb;
    if (base.startsWith('to_')) base = base.substring('to_'.length);
    final text = base.replaceAll('_', ' ');
    return text.isEmpty ? base : text[0].toUpperCase() + text.substring(1);
  }
}

/// Farbiger Level-Kreis. 8 = abgehakt (gruen, Haekchen), 0 = neu (grau).
class _LevelCircle extends StatelessWidget {
  final int level;

  const _LevelCircle({required this.level});

  @override
  Widget build(BuildContext context) {
    final mastered = level >= 8;
    final color = _levelColor(level);
    return Tooltip(
      message: 'Level $level',
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: mastered
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : Text('$level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: level == 0 ? Colors.white : Colors.black,
                )),
      ),
    );
  }
}

Color _levelColor(int level) {
  switch (level) {
    case 0:
      return AppTheme.grey4;
    case 1:
      return AppTheme.red2;
    case 2:
      return AppTheme.orange2;
    case 3:
      return AppTheme.orange1;
    case 4:
      return AppTheme.yellow1;
    case 5:
      return AppTheme.lightBlue2;
    case 6:
      return AppTheme.cyan3;
    case 7:
      return AppTheme.green3;
    case 8:
      return AppTheme.green2;
    default:
      return AppTheme.grey4;
  }
}

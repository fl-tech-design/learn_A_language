import '../routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/grammar_models.dart';
import '../managers/user_state.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';

/// Detail screen for a single grammar topic ([GrammarBlock]). All content is
/// rendered in the user's native language (mother tongue).
class GrammarDetailScreen extends StatelessWidget {
  const GrammarDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final block = ModalRoute.of(context)!.settings.arguments as GrammarBlock;
    final lang = _nativeLang(context);
    final title = block.title.pick(lang) ?? block.id;

    final body = <Widget>[
      _InfoChip(level: block.level, id: block.id),
      if (block.explanation.pick(lang)?.isNotEmpty ?? false)
        _Section(
            caption: l10n.grammarExplanation,
            child: _BodyText(block.explanation.pick(lang)!)),
      if (_text(block.contrast, lang) != null)
        _Section(
            caption: l10n.grammarContrast,
            child: _BodyText(_text(block.contrast, lang)!)),
      if (block.examples.isNotEmpty)
        _Section(
            caption: l10n.grammarExamples, child: _buildExamples(block, lang)),
      if (block.pitfall != null)
        _Section(
            caption: l10n.grammarPitfall,
            child: _buildPitfall(block.pitfall!, lang)),
      if (block.quickCheck != null)
        _Section(
            caption: l10n.grammarQuickCheck,
            child: _buildQuickCheck(block.quickCheck!, lang, l10n)),
      if (_text(block.examFocus, lang) != null)
        _Section(
            caption: l10n.grammarExamFocus,
            child: _BodyText(_text(block.examFocus, lang)!)),
    ];

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: title),
        const AppNavBar(),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body))),
        BoxBottom(
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  String? _text(LocalizedText? text, String lang) {
    final value = text?.pick(lang);
    return (value == null || value.isEmpty) ? null : value;
  }

  Widget _buildExamples(GrammarBlock block, String lang) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final example in block.examples)
        Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _BodyText(example.pick(lang) +
                (example.hint != null
                    ? '  (${example.hint!.pick(lang) ?? ''})'
                    : ''))),
    ]);
  }

  Widget _buildPitfall(GrammarPitfall pitfall, String lang) {
    final why = pitfall.why.pick(lang);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(pitfall.wrong,
          style: const TextStyle(
              fontSize: AppTheme.infFontSize, color: AppTheme.red2)),
      const SizedBox(height: 2),
      Text(pitfall.correct,
          style: const TextStyle(
              fontSize: AppTheme.infFontSize, color: AppTheme.green2)),
      if (why != null && why.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(why,
            style: const TextStyle(
                fontSize: AppTheme.infFontSize, color: Colors.white70)),
      ],
    ]);
  }

  Widget _buildQuickCheck(
      GrammarQuickCheck quickCheck, String lang, AppLocalizations l10n) {
    final task = quickCheck.task.pick(lang);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (task != null && task.isNotEmpty)
        Text(task,
            style: const TextStyle(
                fontSize: AppTheme.infFontSize, color: Colors.white)),
      const SizedBox(height: 6),
      Text('${l10n.grammarSolution}: ${quickCheck.solution}',
          style: const TextStyle(
              fontSize: AppTheme.infFontSize, color: AppTheme.colorPrimary)),
      if (quickCheck.accepted.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(quickCheck.accepted.join(' / '),
                style: const TextStyle(
                    fontSize: AppTheme.smallFontSize, color: AppTheme.grey4))),
    ]);
  }
}

String _nativeLang(BuildContext context) {
  final mLang = context.read<UserState>().userData?.mLang;
  return (mLang == 'en') ? 'en' : 'de';
}

class _InfoChip extends StatelessWidget {
  final String level;
  final String id;

  const _InfoChip({required this.level, required this.id});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppTheme.grey2, borderRadius: BorderRadius.circular(4)),
            child: Text(level,
                style: const TextStyle(
                    fontSize: AppTheme.smallFontSize,
                    color: AppTheme.colorPrimary))),
        const SizedBox(width: 8),
        Text(id,
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String caption;
  final Widget child;

  const _Section({required this.caption, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey3),
          borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(caption,
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize,
                color: AppTheme.colorPrimary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: AppTheme.infFontSize));
  }
}

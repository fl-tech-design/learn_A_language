import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../dialogs/limit_dialog.dart';

/// Word display screen – 1:1 from wordpage.py/kv.
class WordScreen extends StatefulWidget {
  const WordScreen({super.key});
  @override
  State<WordScreen> createState() => _WordScreenState();
}

class _WordScreenState extends State<WordScreen> {
  List<Map<String, dynamic>> _words = [];
  int _index = 0;
  bool _answerChecked = false;
  String _feedback = '';
  Color _feedbackColor = AppTheme.green2;
  Map<String, dynamic>? _streak;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final appState = context.read<AppState>();
    final uname = appState.loggedUName;
    if (uname.isEmpty) return;
    final mode = appState.wordMode;
    final limit = appState.appData.wordsPerSession;
    List<Map<String, dynamic>> words;
    if (mode == 'new') {
      words = await VocabQueries.getNewWords(uname, limit: limit);
      _streak = await VocabQueries.getDayStreak(uname);
    } else {
      words = await VocabQueries.getMasteredWords(uname);
    }
    if (mounted) {
      setState(() {
        _words = words;
        _index = 0;
        _answerChecked = false;
        _feedback = '';
      });
    }
  }

  void _onRead() {
    if (_words.isEmpty || _answerChecked) return;
    final appState = context.read<AppState>();
    final mode = appState.wordMode;
    final word = _words[_index];
    final uname = appState.loggedUName;

    VocabQueries.checkWordAnswer(
            uname, word['key'] as String, word['translation'] as String)
        .then((result) {
      if (!mounted) return;
      setState(() => _answerChecked = true);
      if (mode == 'new') {
        VocabQueries.updateDayStreak(uname);
        VocabQueries.getDayStreak(uname).then((s) {
          if (mounted) setState(() => _streak = s);
        });
        if (_index + 1 >= _words.length) {
          _showLimitDialog();
          return;
        }
        setState(() {
          _index++;
          _answerChecked = false;
          _feedback = '';
        });
      } else {
        setState(() {
          _feedback = result['message'] as String;
          _feedbackColor =
              (result['correct'] as bool) ? AppTheme.green2 : AppTheme.red2;
        });
      }
    });
  }

  void _showLimitDialog() async {
    final appState = context.read<AppState>();
    final at = appState.appTxt;
    final bt = appState.baseTxt;
    final result = await showLimitDialog(context,
        title: at['tit_page_learning'] ?? 'Lernen',
        message: at['limit_reached'] ?? 'Tageslimit erreicht!',
        continueText: at['btn_continue'] ?? 'Weiter',
        endText: bt['btn_end_session'] ?? 'Beenden');
    if (!mounted) return;
    if (result == true) {
      _continueLearning();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _continueLearning() async {
    final appState = context.read<AppState>();
    final uname = appState.loggedUName;
    final limit = appState.appData.wordsPerSession;
    final extra = await VocabQueries.getNewWords(uname,
        limit: limit, offset: _words.length);
    if (extra.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _words = extra;
      _index = 0;
      _answerChecked = false;
      _feedback = '';
    });
  }

  void _navigate(int delta) {
    if (_words.isEmpty) return;
    setState(() {
      _index = (_index + delta) % _words.length;
      _answerChecked = false;
      _feedback = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final mode = appState.wordMode;
    final isNew = mode == 'new';
    final isLearned = mode == 'learned';
    final word =
        (_words.isNotEmpty && _index < _words.length) ? _words[_index] : null;
    final examples = _parseList(word?['examples']);
    final examplesNative = _parseList(word?['examples_native']);

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: at['tit_page_learning'] ?? 'Lernen',
            onInfo: () => showInfoDialog(
                context,
                at['inf_word']?.toString() ?? '',
                bt['information']?.toString() ?? 'Information')),
        if (isNew && _streak != null)
          SizedBox(
              height: 20,
              child: Text(
                  'Tag ${_streak!['current']}  |  Rekord: ${_streak!['longest']}',
                  style: const TextStyle(
                      fontSize: AppTheme.infFontSize,
                      color: Color(0xFFFFB31A)))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: word == null
                    ? const Center(
                        child: Text('Keine Wörter verfügbar',
                            style: TextStyle(fontSize: AppTheme.lblFontSize)))
                    : _buildWordContent(word, examples, examplesNative, at, bt,
                        isNew, isLearned))),
        BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _buildWordContent(
      Map<String, dynamic> word,
      List<String> examples,
      List<String> examplesNative,
      Map<String, dynamic> at,
      Map<String, dynamic> bt,
      bool isNew,
      bool isLearned) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(word['word']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 36))),
          Text(word['translation']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppTheme.lblFontSize, color: Colors.white70)),
          const SizedBox(height: 8),
          if (examples.any((e) => e.isNotEmpty))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(at['examples_title'] ?? 'Beispiele:',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: AppTheme.infFontSize,
                        color: Colors.white60))),
          for (var i = 0; i < 3; i++)
            if (i < examples.length && examples[i].isNotEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '• ${examples[i]}${i < examplesNative.length && examplesNative[i].isNotEmpty ? "  (${examplesNative[i]})" : ""}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: AppTheme.infFontSize,
                          color: Colors.white60))),
          const SizedBox(height: 8),
          Text('Level: ${word['level'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTheme.infFontSize)),
          if (_feedback.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppTheme.lblFontSize,
                        color: _feedbackColor))),
          const SizedBox(height: 12),
          if (!isLearned)
            SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: _answerChecked ? null : _onRead,
                    child: Text(at['btn_read'] ?? 'Gelesen',
                        style: const TextStyle(
                            fontSize: AppTheme.btnFontSize)))),
          if (isLearned)
            SizedBox(
                height: 56,
                child: Row(children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => _navigate(-1),
                          child: Text(at['btn_prev'] ?? 'Vor',
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize)))),
                  Expanded(
                      child: TextButton(
                          onPressed: () => _navigate(1),
                          child: Text(at['btn_next_word'] ?? 'Nächstes',
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize)))),
                ])),
          const SizedBox(height: 8),
          SizedBox(
              height: 56,
              width: double.infinity,
              child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(bt['back'] ?? 'zurück',
                      style: const TextStyle(
                          fontSize: AppTheme.btnFontSize,
                          color: AppTheme.colorPrimary)))),
        ],
      ),
    );
  }

  List<String> _parseList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [''];
  }
}

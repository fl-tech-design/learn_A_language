import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';

/// Due word review screen – 1:1 from duewordpage.py/kv.
class DueWordScreen extends StatefulWidget {
  const DueWordScreen({super.key});
  @override
  State<DueWordScreen> createState() => _DueWordScreenState();
}

class _DueWordScreenState extends State<DueWordScreen> {
  List<Map<String, dynamic>> _words = [];
  int _index = 0;
  bool _checked = false;
  final _inputCtrl = TextEditingController();
  String _feedback = '';
  Color _feedbackColor = AppTheme.green2;
  String _correctDisplay = '';

  @override
  void dispose() { _inputCtrl.dispose(); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final uname = context.read<AppState>().loggedUName;
    if (uname.isEmpty) return;
    final words = await VocabQueries.getDueWords(uname);
    if (mounted) setState(() {
      _words = words; _index = 0; _checked = false;
      _feedback = ''; _correctDisplay = ''; _inputCtrl.clear();
    });
  }

  String _wordToDisplay(String word, [String userInput = '']) {
    final parts = word.split(' ');
    final displayParts = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final w = parts[i];
      if (userInput.isNotEmpty) {
        final inParts = userInput.split(' ');
        final inp = i < inParts.length ? inParts[i] : '';
        final chars = <String>[];
        for (var j = 0; j < w.length; j++) {
          chars.add(j < inp.length && inp[j].toLowerCase() == w[j].toLowerCase() ? w[j] : '_');
        }
        displayParts.add(chars.join(' '));
      } else {
        displayParts.add(List.filled(w.length, '_').join(' '));
      }
    }
    return displayParts.join('  ');
  }

  void _checkAnswer() {
    if (_words.isEmpty || _index >= _words.length || _checked) return;
    final userInput = _inputCtrl.text.trim();
    if (userInput.isEmpty) return;
    final word = _words[_index];
    final correctAnswer = word['word']?.toString() ?? word['key']?.toString() ?? '';
    final isCorrect = userInput.toLowerCase() == correctAnswer.toLowerCase();

    setState(() {
      _checked = true;
      if (isCorrect) {
        _feedback = 'Richtig!'; _feedbackColor = AppTheme.green2;
        _correctDisplay = correctAnswer;
      } else {
        _feedback = 'Falsch!'; _feedbackColor = AppTheme.red2;
        _correctDisplay = 'Richtig wäre: $correctAnswer';
      }
    });

    final uname = context.read<AppState>().loggedUName;
    if (isCorrect) {
      VocabQueries.checkWordAnswer(uname, word['key'] as String, word['translation'] as String);
    } else {
      VocabQueries.checkWordAnswer(uname, word['key'] as String, '');
    }
  }

  void _nextWord() {
    if (!_checked) return;
    setState(() {
      _index++;
      if (_index >= _words.length) {
        _feedback = ''; _correctDisplay = ''; _inputCtrl.clear();
      } else {
        _checked = false; _feedback = ''; _correctDisplay = ''; _inputCtrl.clear();
      }
    });
  }
@override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final allDone = _words.isEmpty || _index >= _words.length;
    final word = !allDone ? _words[_index] : null;
    final correctAnswer = word != null
        ? (word['word']?.toString() ?? word['key']?.toString() ?? '') : '';

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: at['tit_page_learning']?.toString() ?? 'Lernen'),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  SizedBox(height: 80,
                      child: Center(
                          child: Text(
                              allDone ? (at['no_due_words'] ?? 'Keine fälligen Wörter!')
                                  : (word?['translation']?.toString() ?? ''),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 32)))),
                  const SizedBox(height: 8),
                  const Text('Übersetzung:',
                      style: TextStyle(fontSize: AppTheme.infFontSize, color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(
                      allDone ? '' : _checked
                          ? _wordToDisplay(correctAnswer, _inputCtrl.text)
                          : _wordToDisplay(correctAnswer),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(_correctDisplay, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppTheme.lblFontSize, color: _feedbackColor)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _inputCtrl, enabled: !allDone,
                      decoration: InputDecoration(
                          hintText: at['input_hint_due'] ?? 'Tippe die Übersetzung',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 12),
                  SizedBox(height: 56, width: double.infinity,
                      child: OutlinedButton(
                          onPressed: _checked ? null : _checkAnswer,
                          child: Text(at['btn_check'] ?? 'Prüfen',
                              style: const TextStyle(fontSize: AppTheme.btnFontSize)))),
                  if (_checked)
                    SizedBox(height: 56, width: double.infinity,
                        child: OutlinedButton(
                            onPressed: _nextWord,
                            child: Text(at['btn_next'] ?? 'Weiter',
                                style: const TextStyle(fontSize: AppTheme.btnFontSize)))),
                  Text(_feedback, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: _feedbackColor)),
                  const Spacer(),
                  SizedBox(height: 50, width: double.infinity,
                      child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(bt['back'] ?? 'zurück',
                              style: const TextStyle(fontSize: AppTheme.btnFontSize, color: AppTheme.colorPrimary)))),
                ]))),
        BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings')),
      ]),
    );
  }
}
}
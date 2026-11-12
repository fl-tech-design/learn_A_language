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
  String _userInput = '';
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String _feedback = '';
  Color _feedbackColor = AppTheme.green2;
  String _correctDisplay = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final uname = context.read<AppState>().loggedUName;
    if (uname.isEmpty) return;
    final words = await VocabQueries.getDueWords(uname);
    if (mounted) {
      setState(() {
        _words = words;
        _index = 0;
        _checked = false;
        _userInput = '';
        _feedback = '';
        _correctDisplay = '';
        _inputCtrl.clear();
      });
    }
  }

  /// Builds the word display with underscores for each character.
  /// Characters already guessed correctly are shown, others are '_'.
  String _wordToDisplay(String word, String userInput) {
    final chars = <String>[];
    for (var i = 0; i < word.length; i++) {
      if (i < userInput.length) {
        chars.add(word[i]);
      } else if (word[i] == ' ') {
        chars.add(' ');
      } else {
        chars.add('_');
      }
    }
    return chars.join(' ');
  }

  void _onCharInput(String text) {
    if (text.isEmpty || _checked) return;
    final char = text[text.length - 1];
    if (_words.isEmpty || _index >= _words.length) return;

    final word = _words[_index];
    final correctAnswer =
        word['word']?.toString() ?? word['key']?.toString() ?? '';

    // Next unfilled position in the original word (including spaces)
    final nextPos = _userInput.length;
    if (nextPos >= correctAnswer.length) return;

    final expectedChar = correctAnswer[nextPos];

    if (expectedChar == ' ') {
      // Space expected at this position
      if (char == ' ') {
        setState(() => _userInput += ' ');
      } else {
        _failWord(correctAnswer, word);
      }
    } else if (char.toLowerCase() == expectedChar.toLowerCase()) {
      // Correct letter at this position
      final newInput = _userInput + expectedChar;
      if (newInput.length >= correctAnswer.length) {
        // All characters matched – word is correct!
        setState(() {
          _checked = true;
          _userInput = correctAnswer;
          _feedback = 'Richtig!';
          _feedbackColor = AppTheme.green2;
          _correctDisplay = correctAnswer;
        });
        final uname = context.read<AppState>().loggedUName;
        VocabQueries.checkWordAnswer(
            uname, word['key'] as String, word['translation'] as String);
      } else {
        setState(() => _userInput = newInput);
      }
    } else {
      // Wrong character – abort immediately
      _failWord(correctAnswer, word);
    }

    _inputCtrl.clear();
  }

  void _failWord(String correctAnswer, Map<String, dynamic> word) {
    setState(() {
      _checked = true;
      _feedback = 'Falsch!';
      _feedbackColor = AppTheme.red2;
      _correctDisplay = 'Richtig wäre: $correctAnswer';
      _userInput = correctAnswer; // Reveal full word
    });
    final uname = context.read<AppState>().loggedUName;
    VocabQueries.checkWordAnswer(uname, word['key'] as String, '');
  }

  void _nextWord() {
    if (!_checked) return;
    setState(() {
      _index++;
      if (_index >= _words.length) {
        _feedback = '';
        _correctDisplay = '';
        _inputCtrl.clear();
      } else {
        _checked = false;
        _userInput = '';
        _feedback = '';
        _correctDisplay = '';
        _inputCtrl.clear();
        // Re-focus the hidden input
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
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
        ? (word['word']?.toString() ?? word['key']?.toString() ?? '')
        : '';

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: at['tit_page_learning']?.toString() ?? 'Lernen'),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  SizedBox(
                      height: 80,
                      child: Center(
                          child: Text(
                              allDone
                                  ? (at['no_due_words'] ??
                                      'Keine fälligen Wörter!')
                                  : (word?['translation']?.toString() ?? ''),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 32)))),
                  const SizedBox(height: 8),
                  const Text('Übersetzung:',
                      style: TextStyle(
                          fontSize: AppTheme.infFontSize,
                          color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(
                      allDone
                          ? ''
                          : _wordToDisplay(correctAnswer, _userInput),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(_correctDisplay,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppTheme.lblFontSize,
                          color: _feedbackColor)),
                  const SizedBox(height: 8),
                    // Hidden single-character input field
                    if (!allDone && !_checked)
                      SizedBox(
                        width: 1,
                        height: 1,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _inputCtrl,
                            autofocus: true,
                            showCursor: false,
                            maxLength: 1,
                            buildCounter: (_, {int? currentLength, int? maxLength, bool? isFocused}) =>
                                const SizedBox.shrink(),
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            onChanged: _onCharInput,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  if (_checked)
                    SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton(
                            onPressed: _nextWord,
                            child: Text(at['btn_next'] ?? 'Weiter',
                                style: const TextStyle(
                                    fontSize: AppTheme.btnFontSize)))),
                  Text(_feedback,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: _feedbackColor)),
                  const SizedBox(height: AppTheme.contentSpacing),
                  SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: TextButton(
                          onPressed: () {
                            context.read<AppState>().notifyStatsChanged();
                            Navigator.of(context).pop();
                          },
                          child: Text(bt['back'] ?? 'zurück',
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize,
                                  color: AppTheme.colorPrimary)))),
                ]))),
        BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}

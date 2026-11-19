import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../l10n/app_localizations.dart';

/// Due word review screen – 1:1 from duewordpage.py/kv.
class DueWordScreen extends StatefulWidget {
  const DueWordScreen({super.key});
  @override
  State<DueWordScreen> createState() => _DueWordScreenState();
}

class _DueWordScreenState extends State<DueWordScreen> {
  List<VocabEntry> _words = [];
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
    final uname = context.read<DataState>().appData.loggedUName;
    if (uname.isEmpty) return;
    final vq = context.read<VocabQueries>();
    final navState = context.read<NavigationState>();
    final cat = wordCategoryById(navState.selectedCategoryId);
    final words = cat != null
        ? await vq.getGroupDueWords(uname, cat)
        : await vq.getDueWords(uname);
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

  /// Baut die Antwort-Anzeige als RichText auf.
  ///
  /// [word] ist während des Tippens die bereinigte Antwort (ohne Klammerzusatz
  /// wie „(pl)"), nach Abschluss das Original inkl. Klammerzusatz. Zeichen
  /// innerhalb eines Wortes werden mit geschütztem Leerzeichen (NBSP)
  /// verbunden, damit Zeilenumbrüche Wörter nicht auseinanderreißen; die
  /// nächste freie Position wird hervorgehoben.
  TextSpan _buildAnswerSpans(String word, String userInput,
      {required bool highlightNext}) {
    final spans = <InlineSpan>[];
    final nextPos = highlightNext ? _nextInputPos(word, userInput) : -1;

    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      final isTyped = i < userInput.length;
      final isActive = i == nextPos;

      String displayChar;
      Color color;
      if (ch == ' ') {
        if (isTyped || !highlightNext) {
          displayChar = ' ';
          color = Colors.white;
        } else {
          // Noch nicht getipptes Leerzeichen sichtbar machen.
          displayChar = '·';
          color = isActive ? AppTheme.colorPrimary : AppTheme.grey4;
        }
      } else if (isTyped || !highlightNext) {
        displayChar = ch;
        color = Colors.white;
      } else if (isActive) {
        displayChar = '_';
        color = AppTheme.colorPrimary;
      } else {
        displayChar = '_';
        color = AppTheme.grey4;
      }

      spans.add(TextSpan(text: displayChar, style: TextStyle(color: color)));

      // Innerhalb eines Wortes geschützte Leerzeichen (NBSP) statt normaler
      // Leerzeichen: Der Zeilenumbruch erfolgt nur zwischen echten Wörtern.
      if (i < word.length - 1) {
        final nextCh = word[i + 1];
        if (ch != ' ' && nextCh != ' ') {
          spans.add(const TextSpan(text: '\u00A0'));
        }
      }
    }
    return TextSpan(children: spans);
  }

  /// Liefert die nächste vom User einzugebende Position. Vom System
  /// automatisch ergänzte Separatoren („/") werden übersprungen.
  int _nextInputPos(String word, String userInput) {
    for (var i = userInput.length; i < word.length; i++) {
      if (word[i] != '/') return i;
    }
    return word.length;
  }

  /// Strips parenthetical notes like (pl), (sg) for comparison.
  String _stripParenthetical(String s) {
    return s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  Future<void> _onCharInput(String text) async {
    final l10n = AppLocalizations.of(context);
    if (text.isEmpty || _checked) return;
    final char = text[text.length - 1];
    if (_words.isEmpty || _index >= _words.length) return;

    final word = _words[_index];
    final rawAnswer = word.word;
    final correctAnswer = _stripParenthetical(rawAnswer);

    // Next unfilled position in the original word (including spaces)
    final nextPos = _userInput.length;
    if (nextPos >= correctAnswer.length) return;

    final expectedChar = correctAnswer[nextPos];

    if (expectedChar == ' ') {
      // Space expected at this position
      if (char == ' ') {
        setState(() => _userInput += ' ');
      } else {
        unawaited(_failWord(correctAnswer, word));
      }
      _inputCtrl.clear();
      return;
    }

    if (char.toLowerCase() != expectedChar.toLowerCase()) {
      // Wrong character – abort immediately
      unawaited(_failWord(correctAnswer, word));
      _inputCtrl.clear();
      return;
    }

    // Correct letter at this position. Separatoren wie "/" (z. B. in
    // "he/she/it") werden von der App automatisch ergänzt, damit sie auf dem
    // Handy nicht extra eingegeben werden müssen.
    var newInput = _userInput + expectedChar;
    while (newInput.length < correctAnswer.length &&
        correctAnswer[newInput.length] == '/') {
      newInput += '/';
    }

    if (newInput.length >= correctAnswer.length) {
      // All characters matched – word is correct!
      setState(() {
        _checked = true;
        _userInput = correctAnswer;
        _feedback = l10n.feedbackCorrect;
        _feedbackColor = AppTheme.green2;
        _correctDisplay = rawAnswer;
      });
      final uname = context.read<DataState>().appData.loggedUName;
      await context.read<VocabQueries>().checkWordAnswer(
          uname, word.key, word.translation);
    } else {
      setState(() => _userInput = newInput);
    }

    _inputCtrl.clear();
  }

  Future<void> _failWord(String correctAnswer, VocabEntry word) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _checked = true;
      _feedback = l10n.feedbackWrong;
      _feedbackColor = AppTheme.red2;
      final fb = l10n.feedbackCorrectWouldBe;
      _correctDisplay = '$fb ${word.word}';
      _userInput = correctAnswer; // Reveal full word
    });
    final uname = context.read<DataState>().appData.loggedUName;
    await context.read<VocabQueries>().checkWordAnswer(uname, word.key, '');
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
    final l10n = AppLocalizations.of(context);
    final allDone = _words.isEmpty || _index >= _words.length;
    final word = !allDone ? _words[_index] : null;
    final answerWord = word?.word ?? '';
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.titPageLearning),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  SizedBox(
                      height: 80,
                      child: Center(
                          child: Text(
                              allDone
                                  ? l10n.noDueWords
                                  : word!.translation,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 32)))),
                  const SizedBox(height: 4),
                  if (!allDone)
                    Text(l10n.labLevel(word!.level),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: AppTheme.infFontSize,
                            color: Colors.white60)),
                  const SizedBox(height: 8),
                  Text(l10n.translationLabel,
                      style: const TextStyle(
                          fontSize: AppTheme.infFontSize,
                          color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text.rich(
                      allDone
                          ? const TextSpan()
                          : _buildAnswerSpans(
                              _checked
                                  ? word!.word
                                  : _stripParenthetical(answerWord),
                              _userInput,
                              highlightNext: !_checked),
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
                            child: Text(l10n.btnNext,
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
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.back,
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize,
                                  color: AppTheme.colorPrimary)))),
                ]))),
        // Bodenleiste im Querformat ausblenden, solange die Bildschirmtastatur
        // sichtbar ist – so bleibt Platz für die Eingabe.
        if (!keyboardOpen)
          BoxBottom(
              settingsText: l10n.settings,
              exitText: l10n.exit,
              onSettings: () => Navigator.of(context).pushNamed('/settings'),
              onExit: AppTheme.closeApp),
      ]),
    );
  }
}

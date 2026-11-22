import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
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
  final _scrollCtrl = ScrollController();
  String _feedback = '';
  Color _feedbackColor = AppTheme.green2;
  String _correctDisplay = '';
  String _lang = 'de';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Die fälligen Wörter werden exakt EINMAL beim Öffnen des Screens
    // geladen. Ein erneutes Laden wäre gefährlich: Sobald sich MediaQuery
    // ändert (Bildschirmtastatur öffnen/schließen, Orientierungswechsel),
    // würde didChangeDependencies feuern und die Liste neu laden – das gerade
    // beantwortete Wort ist dann nicht mehr „fällig“ und das Feedback der
    // Lösung/des Fehlers sofort überschrieben (→ Screen springt weiter).
    _loadWords();
  }

  Future<void> _loadWords() async {
    final uname = context.read<DataState>().appData.loggedUName;
    if (uname.isEmpty) return;
    final vq = context.read<VocabQueries>();
    final navState = context.read<NavigationState>();
    final lang =
        navState.resolveActiveLang(context.read<UserState>().userData);
    _lang = lang;
    final cat = wordCategoryById(navState.selectedCategoryId);
    final words = cat != null
        ? await vq.getGroupDueWords(uname, cat, langCode: lang)
        : await vq.getDueWords(uname, langCode: lang);
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

      if (ch == ' ') {
        // Leerstellen sind kein Platzhalter: Sie werden als Wortabstand
        // dargestellt. Etwas letterSpacing macht den Abstand sauber sichtbar,
        // statt dass die nächste Unterline direkt am Buchstaben klebt.
        // Gilt für getippte und ungetippte Leerstellen gleichermaßen.
        spans.add(const TextSpan(
            text: ' ',
            style: TextStyle(color: Colors.white, letterSpacing: 4)));
        continue;
      }

      String displayChar;
      Color color;
      if (isTyped || !highlightNext) {
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
      if (i < word.length - 1 && word[i + 1] != ' ') {
        spans.add(const TextSpan(text: '\u00A0'));
      }
    }
    return TextSpan(children: spans);
  }

  /// Liefert die nächste vom User einzugebende Position. Vom System
  /// automatisch ergänzte Separatoren („/") werden übersprungen. Muss als
  /// Nächstes eine Leerstelle getippt werden, liefert die Methode -1: Dann
  /// leuchtet keine Position blau – die Orientierung kommt aus dem sichtbaren
  /// Wortabstand. Sobald die Leerstelle eingegeben wurde, wird der
  /// darauffolgende Buchstabe hervorgehoben.
  int _nextInputPos(String word, String userInput) {
    for (var i = userInput.length; i < word.length; i++) {
      final ch = word[i];
      if (ch == '/') continue;
      if (ch == ' ') return -1;
      return i;
    }
    return word.length;
  }

  /// Strips parenthetical notes like (pl), (sg) for comparison.
  String _stripParenthetical(String s) {
    return s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  /// Normalisiert Unicode-Leerzeichen auf ein normales Leerzeichen. Manche
  /// Tastaturen/IMEs senden statt U+0020 z. B. das geschützte Leerzeichen
  /// (U+00A0), schmales geschütztes Leerzeichen (U+202F), Leerzeichen mit
  /// Fixbreite (U+2007) oder ideografisches Leerzeichen (U+3000). Ohne
  /// Normalisierung würde die Space-Eingabe fälschlich als „Falsch!“ gewertet
  /// und keine Leerstelle ins Prüfwort eingefügt.
  static String _normalizeSpace(String c) {
    if (c == '\u00A0' || c == '\u202F' || c == '\u2007' || c == '\u3000') {
      return ' ';
    }
    return c;
  }

  Future<void> _onCharInput(String text) async {
    final l10n = AppLocalizations.of(context);
    if (text.isEmpty || _checked) return;
    final char = _normalizeSpace(text[text.length - 1]);
    if (_words.isEmpty || _index >= _words.length) return;

    final word = _words[_index];
    final rawAnswer = word.word;
    final correctAnswer = _stripParenthetical(rawAnswer);

    // Next unfilled position in the original word (including spaces)
    final nextPos = _userInput.length;
    if (nextPos >= correctAnswer.length) return;

    final expectedChar = correctAnswer[nextPos];

    if (expectedChar == ' ') {
      // An dieser Position ist eine Leerstelle erwartet.
      if (char == ' ') {
        setState(() => _userInput += ' ');
      } else if (nextPos + 1 < correctAnswer.length &&
          char.toLowerCase() ==
              correctAnswer[nextPos + 1].toLowerCase()) {
        // Der User tippt flüssig weiter, ohne die Space-Taste zu drücken:
        // Leerstelle + folgenden Buchstaben automatisch ergänzen (analog zur
        // "/"-Auto-Einfügung), damit das Prüfwort nie „an einem Stück“
        // geschrieben steht. Jedes andere Zeichen gilt weiterhin als Fehler.
        setState(() => _userInput += ' $char');
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
          uname, word.key, word.translation, langCode: _lang);
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
    await context.read<VocabQueries>().checkWordAnswer(
        uname, word.key, '', langCode: _lang);
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
        // Neues Wort: wieder ganz oben anzeigen und das versteckte Feld
        // fokussieren.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
          _focusNode.requestFocus();
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
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;

    // Handy im Querformat: sehr wenig vertikaler Platz, sobald die
    // Bildschirmtastatur offen ist. Dann die Abstände kompakter setzen,
    // damit Übersetzung (gesuchtes Wort) und Eingabe ohne Scrollen
    // gleichzeitig sichtbar sind. Portrait und große Screens bleiben gleich.
    final size = mq.size;
    final compact = size.width > size.height && size.height < 500;
    final outerPadding = compact ? 8.0 : 20.0;
    final translationHeight = compact ? 40.0 : 80.0;
    final translationFontSize = compact ? 22.0 : 32.0;
    final answerFontSize = compact ? 24.0 : 28.0;
    final gapSmall = compact ? 2.0 : 4.0;
    final gapMedium = compact ? 4.0 : 8.0;

    return Scaffold(
      body: Column(children: [
        // Verstecktes Einzelzeichen-Eingabefeld – bewusst AUSSERHALB des
        // ScrollViews platziert. Läge es im scrollbaren Bereich, würde
        // EditableText bei Fokus/Tippen automatisch dorthin scrollen
        // („Caret on screen") und die Anzeige im Querformat aus dem oberen
        // Bereich kippen – dann müsste man ständig wieder nach oben scrollen.
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
                  buildCounter:
                      (_, {int? currentLength, int? maxLength, bool? isFocused}) =>
                          const SizedBox.shrink(),
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onChanged: _onCharInput,
                ),
              )),
        BoxTitle(title: l10n.titPageLearning),
        Expanded(
            child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: EdgeInsets.all(outerPadding),
                child: Column(children: [
                  SizedBox(
                      height: translationHeight,
                      child: Center(
                          child: Text(
                              allDone
                                  ? l10n.noDueWords
                                  : word!.translation,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: translationFontSize)))),
                  SizedBox(height: gapSmall),
                  if (!allDone)
                    Text(l10n.labLevel(word!.level),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: AppTheme.infFontSize,
                            color: Colors.white60)),
                  SizedBox(height: gapMedium),
                  Text(l10n.translationLabel,
                      style: const TextStyle(
                          fontSize: AppTheme.infFontSize,
                          color: Colors.white60)),
                  SizedBox(height: gapSmall),
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
                      style: TextStyle(fontSize: answerFontSize)),
                  SizedBox(height: gapSmall),
                  if (_correctDisplay.isNotEmpty)
                    Text(_correctDisplay,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: AppTheme.lblFontSize,
                            color: _feedbackColor)),
                  if (_checked) ...[
                    SizedBox(height: gapMedium),
                    SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton(
                            onPressed: _nextWord,
                            child: Text(l10n.btnNext,
                                style: const TextStyle(
                                    fontSize: AppTheme.btnFontSize)))),
                  ],
                  if (_feedback.isNotEmpty)
                    Text(_feedback,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: _feedbackColor)),
                  SizedBox(height: compact ? 4.0 : AppTheme.contentSpacing),
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

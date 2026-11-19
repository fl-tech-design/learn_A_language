import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/user_manager.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/game_over_dialog.dart';
import '../l10n/app_localizations.dart';

/// Turbo Quiz game screen – 1:1 from gamepage.py/kv.
class GameScreen extends StatefulWidget {
  final String difficulty;
  const GameScreen({super.key, this.difficulty = 'medium'});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _lives = 3;
  int _score = 0;
  int _timer = 15;
  int _baseTimer = 15;
  int _timeBonusPerCorrect = 2;
  int _highscore = 0;
  List<VocabEntry> _questions = [];
  int _currentIndex = 0;
  VocabEntry? _currentQuestion;
  Timer? _timerEvent;
  bool _answered = false;
  bool _gameActive = false;
  List<String> _options = [];
  bool _allDone = false;

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    switch (widget.difficulty) {
      case 'easy':
        _baseTimer = 20;
        _timeBonusPerCorrect = 3;
        break;
      case 'hard':
        _baseTimer = 10;
        _timeBonusPerCorrect = 1;
        break;
      default: // medium
        _baseTimer = 15;
        _timeBonusPerCorrect = 2;
        break;
    }
    _timer = _baseTimer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gameActive) _startGame();
  }

  Future<void> _startGame() async {
    _stopTimer();
    final dataState = context.read<DataState>();
    final vq = context.read<VocabQueries>();
    final uname = dataState.appData.loggedUName;

    if (uname.isNotEmpty) {
      final ud = await context.read<UserManager>().loadUserdata(uname);
      _highscore = ud?.gameHighscore ?? 0;
    }

    final allWords = await vq.getReadWords(uname);
    if (allWords.isEmpty) {
      if (!mounted) return;
      setState(() {
        _gameActive = false;
        _allDone = true;
      });
      return;
    }
    allWords.shuffle(Random());

    if (!mounted) return;
    setState(() {
      _lives = 3;
      _score = 0;
      _timer = _baseTimer;
      _currentIndex = 0;
      _answered = false;
      _gameActive = true;
      _allDone = false;
      _questions = allWords;
      _showQuestion();
    });
  }

  void _showQuestion() {
    if (!_gameActive) return;
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      _allDone = true;
      _gameOver();
      return;
    }

    _answered = false;
    final word = _questions[_currentIndex];
    _currentQuestion = word;
    final correct = word.word;

    final pool = _questions.where((w) => w.word != correct).toList();
    pool.shuffle(Random());
    final distractors = pool.length >= 3
        ? pool.take(3).map((w) => w.word).toList()
        // Distraktor-Fallback: Wenn der Spiel-Pool weniger als 4 Wörter enthält,
        // fehlen echte falsche Antwortoptionen. Diese drei Platzhalter füllen die
        // Lücken auf, damit die UI immer 4 Optionen anzeigen kann.
        // TODO: Entfällt, sobald die Turbo-Guard (>4 gelernte Wörter) implementiert ist.
        : ['hello', 'goodbye', 'please'].take(3 - pool.length).toList();

    final options = [correct, ...distractors]..shuffle(Random());
    // Timer bewusst NICHT auf die Startzeit zurücksetzen: Die Restzeit läuft
    // kumulativ über das ganze Spiel weiter und behält den Zeitbonus, der bei
    // einer richtigen Antwort zu _timer addiert wird. Initialisiert wird die
    // Startzeit nur beim Spielstart in _startGame().
    setState(() {
      _options = options;
    });
    _startTimer();
  }

  void _startTimer() {
    _stopTimer();
    _timerEvent = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timerEvent?.cancel();
    _timerEvent = null;
  }

  void _tick() {
    if (!_gameActive || _answered) return;
    setState(() => _timer--);
    if (_timer <= 0) _timeUp();
  }

  void _timeUp() {
    if (!_gameActive) return;
    setState(() => _lives--);
    if (_lives <= 0) {
      _gameOver();
    } else {
      // Zeit aufgebraucht: Ein Leben geht verloren und das neue Wort startet
      // wieder bei der eingestellten Startzeit (_baseTimer). Nur der normale
      // Fragenwechsel behält die Restzeit inkl. Bonus bei.
      setState(() => _timer = _baseTimer);
      _advanceToNext();
    }
  }

  void onAnswer(int btnIndex) {
    if (_answered || !_gameActive) return;
    _stopTimer();
    final selected = _options[btnIndex];
    final correct = _currentQuestion?.word ?? _currentQuestion?.key ?? '';

    if (selected == correct) {
      setState(() {
        _answered = true;
        _score++;
        _timer += _timeBonusPerCorrect;
      });
      Future.delayed(const Duration(milliseconds: 300), _advanceToNext);
    } else {
      setState(() {
        _answered = true;
        _lives--;
      });
      if (_lives <= 0) {
        Future.delayed(const Duration(milliseconds: 300), _gameOver);
      } else {
        Future.delayed(const Duration(milliseconds: 300), _advanceToNext);
      }
    }
  }

  void _advanceToNext() {
    _currentIndex++;
    if (_currentIndex >= _questions.length || _lives <= 0) {
      _gameOver();
    } else {
      _showQuestion();
    }
  }

  Future<void> _gameOver() async {
    _gameActive = false;
    _stopTimer();

    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    var newRecord = false;
    if (uname.isNotEmpty && _score > _highscore) {
      _highscore = _score;
      final um = context.read<UserManager>();
      final ud = await um.loadUserdata(uname);
      if (ud != null) {
        await um.saveUserdata(uname, ud.copyWith(gameHighscore: _highscore));
      }
      newRecord = true;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final result = await showGameOverDialog(context,
        score: _score,
        highscore: _highscore,
        newRecord: newRecord,
        gameOverTitle: l10n.gameOver,
        ptsLabel: l10n.gameScore,
        restartText: l10n.gameRestart,
        backText: l10n.gameBack);
    if (!mounted) return;
    if (result == 'restart') {
      await _startGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final question = _currentQuestion?.translation ?? '';

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnGame),
        // Status bar
        Container(
            height: 48,
            decoration:
                BoxDecoration(border: Border.all(color: AppTheme.grey2)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Text(
                  widget.difficulty == 'easy'
                      ? l10n.difficultyEasyShort
                      : widget.difficulty == 'hard'
                          ? l10n.difficultyHardShort
                          : l10n.difficultyMediumShort,
                  style: const TextStyle(fontSize: 12, color: AppTheme.cyan2)),
              const Spacer(),
              Row(children: [
                Image.asset('assets/game_assets/clock.png',
                    width: 24, height: 24),
                const SizedBox(width: 4),
                Text('${_timer}s',
                    style:
                        const TextStyle(fontSize: 20, color: AppTheme.cyan2)),
              ]),
              const SizedBox(width: 12),
              Row(
                  children: List.generate(
                      3,
                      (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Image.asset(
                              i < _lives
                                  ? 'assets/game_assets/heart.png'
                                  : 'assets/game_assets/heart_empty.png',
                              width: 20,
                              height: 20)))),
              const Spacer(),
              Text('$_score ${l10n.gameScore}',
                  style:
                      const TextStyle(fontSize: 20, color: AppTheme.yellow1)),
              const SizedBox(width: 12),
              Text('${l10n.gameRecordPrefix}$_highscore ${l10n.gameScore}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ])),
        if (_allDone)
          Expanded(
              child: Center(
                  child: Text(l10n.noLearnedWords,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20)))),
        if (_gameActive || _questions.isNotEmpty)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(AppTheme.contentPadding),
                  child: Column(children: [
                    // Question
                    SizedBox(
                        height: 90,
                        child: Center(
                            child: Text(question,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 30)))),
                    // Answer grid 2x2 – gleichmäßig verteilt
                    Expanded(
                        flex: 3,
                        child: Row(children: [
                          Expanded(
                              child: Column(children: [
                            Expanded(child: _answerButton(0)),
                            const SizedBox(height: 8),
                            Expanded(child: _answerButton(2)),
                          ])),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(children: [
                            Expanded(child: _answerButton(1)),
                            const SizedBox(height: 8),
                            Expanded(child: _answerButton(3)),
                          ])),
                        ])),
                    const Spacer(),
                    SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: TextButton(
                            onPressed: () {
                              _stopTimer();
                              Navigator.of(context).pop();
                            },
                            child: Text(l10n.back,
                                style: const TextStyle(
                                    fontSize: AppTheme.btnFontSize,
                                    color: AppTheme.colorPrimary)))),
                  ]))),
        BoxBottom(
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _answerButton(int index) {
    if (index >= _options.length) return const SizedBox.shrink();
    return SizedBox.expand(
      child: OutlinedButton(
        onPressed: _answered ? null : () => onAnswer(index),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.colorPrimary),
            padding: const EdgeInsets.all(6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_options[index],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

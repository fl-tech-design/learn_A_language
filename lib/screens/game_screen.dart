import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/user_manager.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/game_over_dialog.dart';

/// Turbo Quiz game screen – 1:1 from gamepage.py/kv.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _lives = 3;
  int _score = 0;
  int _timer = 15;
  int _baseTimer = 15;
  int _correctStreak = 0;
  int _timeBonus = 0;
  int _highscore = 0;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  Map<String, dynamic>? _currentQuestion;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gameActive) _startGame();
  }

  Future<void> _startGame() async {
    _stopTimer();
    final appState = context.read<AppState>();
    final uname = appState.loggedUName;

    if (uname.isNotEmpty) {
      final userData = await UserManager.loadUserdata(uname);
      _highscore = userData['game_highscore'] as int? ?? 0;
    }

    final allWords = await VocabQueries.getMasteredWords(uname);
    if (allWords.isEmpty) {
      setState(() {
        _gameActive = false;
        _allDone = true;
      });
      return;
    }
    allWords.shuffle(Random());

    setState(() {
      _lives = 3;
      _score = 0;
      _timer = 15;
      _baseTimer = 15;
      _correctStreak = 0;
      _timeBonus = 0;
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
    final correct = word['word']?.toString() ?? word['key']?.toString() ?? '';

    final pool = _questions
        .where(
            (w) => (w['word']?.toString() ?? w['key']?.toString()) != correct)
        .toList();
    pool.shuffle(Random());
    final distractors = pool.length >= 3
        ? pool.take(3).map((w) => w['word']?.toString() ?? '').toList()
        : ['hello', 'goodbye', 'please'].take(3 - pool.length).toList();

    final options = [correct, ...distractors]..shuffle(Random());
    setState(() {
      _options = options;
      _timer = _baseTimer + _timeBonus;
      _timeBonus = 0;
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
    if (!_gameActive) return;
    setState(() => _timer--);
    if (_timer <= 0) _timeUp();
  }

  void _timeUp() {
    if (!_gameActive) return;
    setState(() => _lives--);
    if (_lives <= 0) {
      _gameOver();
    } else {
      _advanceToNext();
    }
  }

  void onAnswer(int btnIndex) {
    if (_answered || !_gameActive) return;
    _answered = true;
    _stopTimer();
    final selected = _options[btnIndex];
    final correct = _currentQuestion?['word']?.toString() ??
        _currentQuestion?['key']?.toString() ??
        '';

    if (selected == correct) {
      setState(() {
        _score++;
        _timeBonus += 2;
        _correctStreak++;
      });
      if (_correctStreak % 5 == 0 && _baseTimer > 5) _baseTimer--;
      Future.delayed(const Duration(milliseconds: 400), () => _advanceToNext());
    } else {
      setState(() => _lives--);
      if (_lives <= 0) {
        Future.delayed(const Duration(milliseconds: 400), () => _gameOver());
      } else {
        Future.delayed(
            const Duration(milliseconds: 400), () => _advanceToNext());
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

    final appState = context.read<AppState>();
    final uname = appState.loggedUName;
    var newRecord = false;
    if (uname.isNotEmpty && _score > _highscore) {
      _highscore = _score;
      final userData = await UserManager.loadUserdata(uname);
      userData['game_highscore'] = _highscore;
      await UserManager.saveUserdata(uname, userData);
      newRecord = true;
    }

    if (!mounted) return;
    final at = appState.appTxt;
    final result = await showGameOverDialog(context,
        score: _score,
        highscore: _highscore,
        newRecord: newRecord,
        gameOverTitle: at['game_over'] ?? 'Spiel vorbei!',
        ptsLabel: at['game_score'] ?? 'Pkt',
        restartText: at['game_restart'] ?? 'Neustart',
        backText: at['game_back'] ?? 'Zurück');
    if (!mounted) return;
    if (result == 'restart') {
      _startGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final question = _currentQuestion?['translation']?.toString() ?? '';

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: at['btn_game']?.toString() ?? 'Spiele'),
        // Status bar
        Container(
            height: 48,
            decoration:
                BoxDecoration(border: Border.all(color: AppTheme.grey2)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
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
              Text('$_score ${at['game_score'] ?? 'Pkt'}',
                  style:
                      const TextStyle(fontSize: 20, color: AppTheme.yellow1)),
              const SizedBox(width: 12),
              Text('R: $_highscore ${at['game_score'] ?? 'Pkt'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ])),
        if (_allDone)
          const Expanded(
              child: Center(
                  child: Text(
                      'Keine gelernten Wörter zum Spielen.\n'
                      'Lerne zuerst neue Wörter!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20)))),
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

  Widget _answerButton(int index) {
    if (index >= _options.length) return const SizedBox.shrink();
    return OutlinedButton(
        onPressed: _answered ? null : () => onAnswer(index),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.colorPrimary),
            padding: const EdgeInsets.all(4)),
        child: Text(_options[index],
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)));
  }
}

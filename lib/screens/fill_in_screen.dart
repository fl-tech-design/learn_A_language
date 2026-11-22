import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
import '../managers/user_manager.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/game_over_dialog.dart';
import '../l10n/app_localizations.dart';
import 'fill_in_engine.dart';

/// Fill-In-Spielscreen: Beispielsatz mit Luecke, die Verbform eintippen.
///
/// Analog zu Turbo/Wortsuche/Kreuzwortraetsel/Hangman nutzt er ausschliesslich
/// bestehende Patterns (BoxTitle/BoxBottom, VocabQueries.getReadWords,
/// showGameOverDialog). Er hat KEINEN Einfluss auf den Vokabel-Fortschritt –
/// geschrieben werden beim Abschluss nur `fillInBestTimes` (KLEINER-Besser,
/// nur bei >= 80 % geloesten Saetzen) und [VocabQueries.updateDayStreak].
/// Turbo-gameHighscore und crosswordBestTimes bleiben unberuehrt.
class FillInScreen extends StatefulWidget {
  final String difficulty;

  /// Kategorie-Id (z. B. 'grp_alltag'). Wenn gesetzt, wird der Wortpool auf
  /// diese Kategorie gefiltert; wenn null, kommen alle Kategorien.
  final String? category;

  const FillInScreen({super.key, this.difficulty = 'medium', this.category});

  @override
  State<FillInScreen> createState() => _FillInScreenState();
}

/// Feld-Feedback: neutral, gruen (richtig) oder rot (falsch).
enum _Feedback { none, correct, wrong }

class _FillInScreenState extends State<FillInScreen> {
  FillInRound? _round;
  bool _loading = true;
  String? _category;
  final TextEditingController _controller = TextEditingController();

  // Stoppuhr + Anzeige-Ticker (mm:ss).
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _clockTimer;

  int _bestTime = 0; // Bestzeit in Millisekunden fuer widget.difficulty
  _Feedback _feedback = _Feedback.none;
  bool _busy = false; // blockiert Eingabe waehrend des 600ms-Feedbacks

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_category == null) {
      // Kategorie wie bei den bestehenden Kategorie-Screens als
      // Route-Argument moeglich (z. B. pushNamed('/fillin', arguments: id)).
      final routeId = ModalRoute.of(context)?.settings.arguments as String?;
      _category = widget.category ?? routeId;
    }
    if (_loading && _round == null) _startGame();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _stopwatch.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    _clockTimer?.cancel();
    _stopwatch
      ..reset()
      ..stop();
    _busy = false;
    _feedback = _Feedback.none;
    _controller.clear();

    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final vq = context.read<VocabQueries>();

    _bestTime = 0;
    if (uname.isNotEmpty) {
      final ud = await context.read<UserManager>().loadUserdata(uname);
      _bestTime = ud?.fillInBestTimes[widget.difficulty] ?? 0;
    }

    final lang = context
        .read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    var words = await vq.getReadWords(uname, langCode: lang);

    // Optionaler Kategorie-Filter ueber die bestehende Kategorien-Info.
    final cat = wordCategoryById(_category);
    if (cat != null) {
      words = words.where((e) => cat.containsEntryKey(e.key)).toList();
    }
    // Zweiter Filter nach dem Laden (Runden-Garantie): nur level >= 1 und
    // status 'seen'. Kategorie-0-Woerter landen NIE in der Runde.
    words = words.where((e) => e.status == 'seen' && e.level >= 1).toList();

    final round = createRound(words, widget.difficulty);
    if (!mounted) return;
    setState(() {
      _round = round;
      _loading = false;
    });
    // Stoppuhr startet bei Rundenbeginn (nach dem ersten Runden-Build).
    if (round.items.isNotEmpty) {
      round.startTimeMs = DateTime.now().millisecondsSinceEpoch;
      _stopwatch
        ..reset()
        ..start();
      _startClock();
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  /// Formatiert Millisekunden als mm:ss.
  static String _fmtMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  FillInItem? _currentItem() {
    final round = _round;
    if (round == null) return null;
    if (round.index < 0 || round.index >= round.items.length) return null;
    return round.items[round.index];
  }

  /// Autopruefung: sobald die Eingabe so lang ist wie die Loesung.
  void _onTextChanged(String text) {
    final item = _currentItem();
    if (_busy || item == null) return;
    if (text.length >= item.solution.length) _submit();
  }

  void _submit() {
    final round = _round;
    final item = _currentItem();
    if (_busy || round == null || item == null) return;

    final correct = checkAnswer(item, _controller.text);
    setState(() {
      if (correct) {
        round.score++;
        _feedback = _Feedback.correct;
      } else {
        _feedback = _Feedback.wrong;
      }
    });

    if (correct) {
      // Richtig: Feld gruen, Satz bleibt 600ms sichtbar, dann weiter.
      _busy = true;
      Future.delayed(const Duration(milliseconds: 600), _advanceAfterCorrect);
    }
  }

  void _advanceAfterCorrect() {
    if (!mounted) return;
    final round = _round;
    if (round == null) return;
    setState(() {
      _busy = false;
      _feedback = _Feedback.none;
      _controller.clear();
      round.index++;
    });
    _checkRoundEnd();
  }

  void _onSkip() {
    final round = _round;
    if (_busy || round == null) return;
    setState(() {
      _feedback = _Feedback.none;
      _controller.clear();
      round.index++;
    });
    _checkRoundEnd();
  }

  void _checkRoundEnd() {
    final round = _round;
    if (round != null && isRoundOver(round)) _finishGame();
  }

  /// Spielende: Stoppuhr anhalten, Rekord (KLEINER-Besser, >= 80 % geloest)
  /// speichern wie Turbo, Tagesstreak wie die Wortsuche, GameOver-Dialog.
  ///
  /// score = Punkte, highscore = Bestzeit in Sekunden (wie im Screen).
  Future<void> _finishGame() async {
    final round = _round;
    if (round == null || _busy) return;
    _busy = true;
    _clockTimer?.cancel();
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;

    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    // Provider vor den awaits lesen (kein BuildContext ueber async gaps).
    final um = context.read<UserManager>();
    final vq = context.read<VocabQueries>();
    var newRecord = false;
    final solvedCount = round.items.where((i) => i.score).length;
    final total = round.items.length;

    if (uname.isNotEmpty && total > 0) {
      // Rekordversuch nur, wenn mindestens 80 % der Saetze geloest wurden.
      if (solvedCount * 10 >= total * 8) {
        final ud = await um.loadUserdata(uname);
        if (ud != null) {
          final recordMs = ud.fillInBestTimes[widget.difficulty] ?? 0;
          if (recordMs == 0 || elapsedMs < recordMs) {
            newRecord = true;
            final times = Map<String, int>.from(ud.fillInBestTimes);
            times[widget.difficulty] = elapsedMs;
            try {
              await um.saveUserdata(
                  uname, ud.copyWith(fillInBestTimes: times));
              _bestTime = elapsedMs;
            } on PersistenceException catch (e) {
              developer.log(
                  'fill_in_screen: Bestzeit für $uname nicht gespeichert ($e)');
              StorageErrorBus.instance
                  .report(StorageErrorKind.progressNotSaved);
            }
          } else {
            _bestTime = recordMs;
          }
        }
      }
      // Tagesstreak wie die Wortsuche (nur das – kein SRS-/Level-Einfluss).
      await vq.updateDayStreak(uname);
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final result = await showGameOverDialog(
      context,
      score: round.score,
      highscore: (_bestTime / 1000).round(),
      newRecord: newRecord,
      gameOverTitle: l10n.gameOver,
      ptsLabel: l10n.fillInPoints,
      restartText: l10n.gameRestart,
      backText: l10n.gameBack,
    );
    if (!mounted) return;
    if (result == 'restart') {
      setState(() {
        _round = null;
        _loading = true;
        _feedback = _Feedback.none;
        _busy = false;
      });
      await _startGame();
    } else {
      Navigator.of(context).pop();
    }
  }
  /// Farbe des Eingabe-Feedbacks (gruen = richtig, rot = falsch).
  Color _feedbackColor() => switch (_feedback) {
        _Feedback.correct => AppTheme.green3,
        _Feedback.wrong => AppTheme.red2,
        _Feedback.none => AppTheme.colorPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = _round;

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnFillIn),
        _statusBar(l10n),
        Expanded(
          child: _loading || round == null
              ? const Center(child: CircularProgressIndicator())
              : round.items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.contentPadding),
                        child: Text(
                          l10n.noLearnedWords,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    )
                  : _buildGameArea(l10n, round),
        ),
        BoxBottom(
          settingsText: l10n.settings,
          exitText: l10n.exit,
          onSettings: () => Navigator.of(context).pushNamed('/settings'),
          onExit: AppTheme.closeApp,
        ),
      ]),
    );
  }

  /// Statuszeile analog zum Turbo-Spiel: Schwierigkeits-Label, Stoppuhr
  /// (clock.png + mm:ss) und Bestzeit (trophy.png + mm:ss), Punkte.
  Widget _statusBar(AppLocalizations l10n) {
    final difficultyLabel = switch (widget.difficulty) {
      'easy' => l10n.fillInEasy,
      'hard' => l10n.fillInHard,
      _ => l10n.fillInMedium,
    };
    final round = _round;
    final score = round?.score ?? 0;
    final total = round?.items.length ?? 0;
    return Container(
      height: 48,
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grey2)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(difficultyLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.cyan2)),
          ),
        ),
        const Spacer(),
        Row(children: [
          Image.asset('assets/game_assets/clock.png', width: 24, height: 24),
          const SizedBox(width: 4),
          Text('${l10n.fillInTime} ${_fmtMs(_stopwatch.elapsedMilliseconds)}',
              style: const TextStyle(fontSize: 14, color: AppTheme.cyan2)),
        ]),
        const SizedBox(width: 12),
        Row(children: [
          Image.asset('assets/game_assets/trophy.png', width: 24, height: 24),
          const SizedBox(width: 4),
          Text('${l10n.fillInBestTime} ${_fmtMs(_bestTime)}',
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ]),
        const SizedBox(width: 12),
        Text('$score / $total ${l10n.fillInPoints}',
            style: const TextStyle(fontSize: 18, color: AppTheme.yellow1)),
      ]),
    );
  }


  /// Spielbereich: Luecken-Satz (ggf. mit aufgedecktem Tipp-Buchstaben),
  /// Native-Satz, Eingabefeld mit OK/Skip.
  Widget _buildGameArea(AppLocalizations l10n, FillInRound round) {
    final item = round.items[round.index];
    return Padding(
      padding: const EdgeInsets.all(AppTheme.contentPadding),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 24),
              Text(
                _displaySentence(item),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, color: Colors.white, height: 1.3),
              ),
              if (item.sentenceNative.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.sentenceNative,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
              ],
              if (item.tries > 0 && !item.score)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${l10n.feedbackWrong} ${l10n.feedbackCorrectWouldBe} '
                    '${_hintText(item)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppTheme.red2),
                  ),
                ),
            ]),
          ),
        ),
        TextField(
          controller: _controller,
          enabled: !_busy,
          onChanged: _onTextChanged,
          style: const TextStyle(fontSize: 22, color: Colors.white),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: l10n.inputHintDue,
            filled: true,
            fillColor: _feedbackColor().withValues(alpha: 0.10),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: _feedbackColor().withValues(alpha: 0.6), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: _feedbackColor(), width: 2),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.contentSpacing),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _busy ? null : _submit,
                child:
                    Text(l10n.btnCheck, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.contentSpacing),
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _busy ? null : _onSkip,
                child: Text(l10n.fillInSkip,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppTheme.contentSpacing),
      ]),
    );
  }

  /// Hinweistext nach Fehlversuchen: ab 2 Versuchen wird nur noch der erste
  /// Buchstabe als Tipp gezeigt (die echte Loesung erscheint im Satz).
  String _hintText(FillInItem item) {
    if (item.hintShown && item.solution.isNotEmpty) {
      return '${item.solution[0]}___';
    }
    return item.solution;
  }

  /// Satz-Darstellung: nach 2 Fehlversuchen wird der erste Buchstabe der
  /// Luecke als Tipp aufgedeckt (einmalig, zeigt die echte Loesung).
  String _displaySentence(FillInItem item) {
    if (!item.hintShown || item.solution.isEmpty) return item.sentence;
    final idx = item.sentence.indexOf('_');
    if (idx < 0) return item.sentence;
    return item.sentence.replaceRange(idx, idx + 1, item.solution[0]);
  }
}

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/user_manager.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/game_over_dialog.dart';
import '../l10n/app_localizations.dart';
import 'crossword_engine.dart';

/// Kreuzwortraetsel-Spielscreen.
///
/// Analog zu Turbo/Wortsuche nutzt er ausschliesslich bestehende Patterns
/// (BoxTitle/BoxBottom, VocabQueries.getReadWords, showGameOverDialog). Er hat
/// KEINEN Einfluss auf den Vokabel-Fortschritt – geschrieben werden beim
/// Abschluss nur das neue Feld `crosswordBestTimes` (kleinere Zeit = neuer
/// Rekord) und [VocabQueries.updateDayStreak].
class CrosswordScreen extends StatefulWidget {
  final String difficulty;

  /// Kategorie-Id (z. B. 'grp_alltag'). Wenn gesetzt, wird der Wortpool auf
  /// diese Kategorie gefiltert; wenn null, kommen alle Kategorien.
  final String? category;

  const CrosswordScreen({super.key, this.difficulty = 'medium', this.category});

  @override
  State<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends State<CrosswordScreen> {
  CrosswordPuzzle? _puzzle;
  bool _loading = true;
  bool _gameActive = false;
  String? _category;
  ActiveCell? _active;

  // Stoppuhr + Anzeige-Ticker (mm:ss).
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _clockTimer;

  int _bestTime = 0; // Bestzeit in Millisekunden fuer widget.difficulty

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_category == null) {
      // Kategorie wie bei den bestehenden Kategorie-Screens als
      // Route-Argument moeglich (z. B. pushNamed('/crossword', arguments: id)).
      final routeId = ModalRoute.of(context)?.settings.arguments as String?;
      _category = widget.category ?? routeId;
    }
    if (_loading && _puzzle == null) _startGame();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _startGame() async {
    _clockTimer?.cancel();
    _stopwatch
      ..reset()
      ..stop();

    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final vq = context.read<VocabQueries>();

    _bestTime = 0;
    if (uname.isNotEmpty) {
      final ud = await context.read<UserManager>().loadUserdata(uname);
      _bestTime = ud?.crosswordBestTimes[widget.difficulty] ?? 0;
    }

    var words = await vq.getReadWords(uname);

    // Optionaler Kategorie-Filter ueber die bestehende Kategorien-Info.
    final cat = wordCategoryById(_category);
    if (cat != null) {
      words = words.where((e) => cat.containsEntryKey(e.key)).toList();
    }
    // Zweiter Filter nach dem Laden (Puzzle-Garantie): nur level >= 1 und
    // status 'seen'. Kategorie-0-Woerter landen NIE im Raetsel.
    words = words.where((e) => e.status == 'seen' && e.level >= 1).toList();

    final puzzle = generatePuzzle(words, widget.difficulty);
    if (!mounted) return;
    setState(() {
      _puzzle = puzzle;
      _loading = false;
      _gameActive = puzzle.words.isNotEmpty;
      _active = _firstUnsolved(puzzle);
    });
    // Stoppuhr startet bei Spielbeginn (nach dem ersten Puzzle-Build).
    if (_gameActive) {
      _stopwatch
        ..reset()
        ..start();
      _startClock();
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_gameActive) return;
      setState(() {});
    });
  }

  /// Erste ungeloeste Zelle (fuer den Cursor-Start) oder null.
  ActiveCell? _firstUnsolved(CrosswordPuzzle puzzle) {
    for (final w in puzzle.words) {
      for (final p in w.cells) {
        final c = puzzle.cellAt(p);
        if (c != null && !c.solved) return ActiveCell(p, w.direction);
      }
    }
    return null;
  }
/// Klick auf eine Gitterzelle (Buchstaben- oder Leerfeld).
  ///
  /// Leerfelder dienen als Hinweis-Buttons: Sie aktivieren das naechste
  /// ungeloeste Wort. Auf Buchstaben-Zellen wird der Cursor gesetzt; ein
  /// erneuter Klick auf die aktive Zelle toggelt waagrecht/senkrecht.
  void _onCellTap(CrosswordPos pos) {
    final puzzle = _puzzle;
    if (puzzle == null || !_gameActive) return;
    final cell = puzzle.cellAt(pos);
    if (cell == null) return;

    if (cell.isEmpty) {
      _activateNextUnsolved();
      return;
    }

    final current = _active;
    if (current != null && current.pos == pos) {
      // Gleiche Zelle erneut: Richtung toggeln (nur wenn moeglich).
      final toggled = current.direction == 'h' ? 'v' : 'h';
      if (wordAt(puzzle, pos, toggled) != null) {
        setState(() => _active = ActiveCell(pos, toggled));
      }
      return;
    }

    final hasH = wordAt(puzzle, pos, 'h') != null;
    final hasV = wordAt(puzzle, pos, 'v') != null;
    if (hasH || hasV) {
      setState(() => _active = ActiveCell(pos, hasH ? 'h' : 'v'));
    }
  }

  /// Aktiviert das naechste ungeloeste Wort (von der aktuellen Position aus
  /// zirkulierend) und zeigt dessen Uebersetzung als Hinweis an.
  void _activateNextUnsolved() {
    final puzzle = _puzzle;
    if (puzzle == null || !_gameActive) return;
    final words = puzzle.words;
    if (words.isEmpty) return;

    var start = 0;
    final current = _active;
    if (current != null) {
      final index =
          words.indexWhere((w) => w.cells.contains(current.pos));
      start = index < 0 ? 0 : (index + 1) % words.length;
    }
    for (var i = 0; i < words.length; i++) {
      final w = words[(start + i) % words.length];
      if (w.solved) continue;
      for (final p in w.cells) {
        final c = puzzle.cellAt(p);
        if (c != null && !c.solved) {
          setState(() => _active = ActiveCell(p, w.direction));
          return;
        }
      }
    }
  }

  /// Eingabe ueber die On-Screen-Tastatur.
  void _onKeyPress(String letter) {
    final puzzle = _puzzle;
    final active = _active;
    if (puzzle == null || active == null || !_gameActive) return;

    final result = checkLetter(puzzle, active, letter);
    if (!result.correct) {
      // Falscher Buchstabe: nichts passiert, Zelle bleibt leer.
      // TODO (optional): kurzer Fail-Piepton. AudioService kann bisher nur
      // Verb-Sprachaussprache abspielen (kein generischer Effekt-Ton), daher
      // bewusst weggelassen.
      return;
    }
    setState(() => _active = result.nextActive);
    if (isPuzzleSolved(puzzle)) _finishGame();
  }

  /// Spielende: Stoppuhr anhalten, Rekord (KLEINER-Besser) speichern wie Turbo,
  /// Tagesstreak wie die Wortsuche, danach GameOver-Dialog.
  ///
  /// Parameter fuer den Zeit-Modus semantisch: score = Loesungszeit (Sekunden),
  /// highscore = Rekordzeit (Sekunden).
  Future<void> _finishGame() async {
    if (!_gameActive) return;
    _gameActive = false;
    _clockTimer?.cancel();
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;

    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    // Provider vor den awaits lesen (kein BuildContext ueber async gaps).
    final um = context.read<UserManager>();
    final vq = context.read<VocabQueries>();
    var newRecord = false;

    if (uname.isNotEmpty) {
      final ud = await um.loadUserdata(uname);
      if (ud != null) {
        final recordMs = ud.crosswordBestTimes[widget.difficulty] ?? 0;
        if (recordMs == 0 || elapsedMs < recordMs) {
          newRecord = true;
          final times = Map<String, int>.from(ud.crosswordBestTimes);
          times[widget.difficulty] = elapsedMs;
          try {
            await um.saveUserdata(
                uname, ud.copyWith(crosswordBestTimes: times));
            _bestTime = elapsedMs;
          } on PersistenceException catch (e) {
            developer.log(
                'crossword_screen: Bestzeit fuer $uname nicht gespeichert ($e)');
            StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
          }
        } else {
          _bestTime = recordMs;
        }
      }
      // Tagesstreak wie die Wortsuche (nur das – kein SRS-/Level-Einfluss).
      await vq.updateDayStreak(uname);
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final result = await showGameOverDialog(
      context,
      score: (elapsedMs / 1000).round(),
      highscore: (_bestTime / 1000).round(),
      newRecord: newRecord,
      gameOverTitle: l10n.gameOver,
      ptsLabel: l10n.crosswordTime,
      restartText: l10n.gameRestart,
      backText: l10n.gameBack,
    );
    if (!mounted) return;
    if (result == 'restart') {
      await _startGame();
    } else {
      Navigator.of(context).pop();
    }
  }
/// Formatiert Millisekunden als mm:ss.
  static String _fmtMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final puzzle = _puzzle;
    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnCrossword),
        _statusBar(l10n),
        Expanded(
          child: _loading || puzzle == null
              ? const Center(child: CircularProgressIndicator())
              : puzzle.words.isEmpty
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
                  : _buildGameArea(l10n, puzzle),
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
  /// (clock.png + mm:ss) und Bestzeit (trophy.png + mm:ss).
  Widget _statusBar(AppLocalizations l10n) {
    final difficultyLabel = widget.difficulty == 'easy'
        ? l10n.crosswordEasy
        : widget.difficulty == 'hard'
            ? l10n.crosswordHard
            : l10n.crosswordMedium;
    return Container(
      height: 48,
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grey2)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Text(difficultyLabel,
            style: const TextStyle(fontSize: 12, color: AppTheme.cyan2)),
        const Spacer(),
        Row(children: [
          Image.asset('assets/game_assets/clock.png', width: 24, height: 24),
          const SizedBox(width: 4),
          Text(_fmtMs(_stopwatch.elapsedMilliseconds),
              style: const TextStyle(fontSize: 20, color: AppTheme.cyan2)),
        ]),
        const SizedBox(width: 12),
        Row(children: [
          Image.asset('assets/game_assets/trophy.png', width: 24, height: 24),
          const SizedBox(width: 4),
          Text('${l10n.crosswordBestTime} ${_fmtMs(_bestTime)}',
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ]),
      ]),
    );
  }

  /// Spielbereich: Gitter in der minimalen Begrenzungsbox, darunter die
  /// Hinweisanzeige (Uebersetzung des aktiven Wortes + Richtungspfeil) und
  /// die On-Screen-Buchstabentastatur.
  Widget _buildGameArea(AppLocalizations l10n, CrosswordPuzzle puzzle) {
    final active = _active;
    final activeWord =
        active == null ? null : wordAt(puzzle, active.pos, active.direction);
    final activeCells = <CrosswordPos>{
      if (activeWord != null) ...activeWord.cells,
    };

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.contentPadding),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cell = math.min(
                  constraints.maxWidth / puzzle.cols,
                  constraints.maxHeight / puzzle.rows,
                );
                return SizedBox(
                  width: cell * puzzle.cols,
                  height: cell * puzzle.rows,
                  child: _buildGrid(cell, active, activeCells),
                );
              },
            ),
          ),
        ),
      ),
      // Hinweisanzeige: Uebersetzung des aktiven Wortes (+ Richtungspfeil).
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.grey2,
          border: Border.all(color: AppTheme.grey3),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (active != null)
            Icon(
              active.direction == 'h'
                  ? Icons.arrow_forward
                  : Icons.arrow_downward,
              size: 18,
              color: AppTheme.colorPrimary,
            ),
          if (active != null) const SizedBox(width: 6),
          Expanded(
            child: Text(
              activeWord?.translation ?? l10n.noContentYet,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppTheme.lblFontSize, color: Colors.white),
            ),
          ),
        ]),
      ),
      _buildKeyboard(),
    ]);
  }

  Widget _buildGrid(
      double cellSize, ActiveCell? active, Set<CrosswordPos> activeCells) {
    final puzzle = _puzzle!;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: puzzle.cols,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: puzzle.rows * puzzle.cols,
      itemBuilder: (context, index) {
        final row = index ~/ puzzle.cols;
        final col = index % puzzle.cols;
        final cell = puzzle.grid[row][col];
        return _buildCell(
            puzzle, CrosswordPos(row, col), cell, cellSize, active, activeCells);
      },
    );
  }
/// Eine Gitterzelle mit deutlichem Feedback:
  /// - Leerfeld: Hinweis-Button (Oeffnen des naechsten ungeloesten Wortes).
  /// - Aktive Zelle: App-Primaerfarbe; Zellen des aktiven Wortes dezent
  ///   hervorgehoben (Richtungs-Highlight von Zeile/Spalte).
  /// - Geloeste Zellen: dauerhaft gruen markiert.
  Widget _buildCell(CrosswordPuzzle puzzle, CrosswordPos pos, Cell cell,
      double cellSize, ActiveCell? active, Set<CrosswordPos> activeCells) {
    if (cell.isEmpty) {
      return GestureDetector(
        onTap: _activateNextUnsolved,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.grey2,
            border: Border.all(color: AppTheme.colorPrimary, width: 0.8),
          ),
          alignment: Alignment.center,
          child: const Text('+',
              style: TextStyle(fontSize: 14, color: AppTheme.colorPrimary)),
        ),
      );
    }

    final isActive = active?.pos == pos;
    final inActiveWord = activeCells.contains(pos);

    final Color background;
    final Color foreground;
    final Color borderColor;
    if (isActive) {
      background = AppTheme.colorPrimary;
      foreground = Colors.white;
      borderColor = Colors.white;
    } else if (cell.solved) {
      background = AppTheme.green3.withValues(alpha: 0.3);
      foreground = Colors.white;
      borderColor = AppTheme.green3;
    } else if (inActiveWord) {
      background = AppTheme.lightBlue3.withValues(alpha: 0.18);
      foreground = Colors.white70;
      borderColor = AppTheme.colorPrimary;
    } else {
      background = AppTheme.grey1;
      foreground = Colors.white70;
      borderColor = AppTheme.grey3;
    }

    return GestureDetector(
      onTap: () => _onCellTap(pos),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 0.5),
        ),
        alignment: Alignment.center,
        child: cell.solved
            ? Text(
                cell.letter,
                style: TextStyle(
                  fontSize: math.min(20.0, cellSize * 0.55),
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              )
            : null,
      ),
    );
  }

  /// On-Screen-Buchstabentastatur (A-Z, nur Grossbuchstaben).
  Widget _buildKeyboard() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final ch in letters.split(''))
            SizedBox(
              width: 32,
              height: 38,
              child: OutlinedButton(
                onPressed: () => _onKeyPress(ch),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppTheme.colorPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(ch,
                    style: const TextStyle(
                        fontSize: 16, color: AppTheme.colorPrimary)),
              ),
            ),
        ],
      ),
    );
  }
}
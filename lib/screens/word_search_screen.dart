import '../routes.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/game_over_dialog.dart';
import '../l10n/app_localizations.dart';
import 'word_search_engine.dart';

/// Wortsuche-Spielscreen.
///
/// Analog zum Turbo-Spiel nutzt er ausschließlich bestehende Patterns
/// (BoxTitle/BoxBottom, VocabQueries.getReadWords, GameOverDialog). Er hat
/// KEINEN Einfluss auf den Vokabel-Fortschritt – nur [VocabQueries.updateDayStreak]
/// wird beim Abschluss aktualisiert.
class WordSearchScreen extends StatefulWidget {
  final String difficulty;

  /// Kategorie-Id (z. B. 'erste_verben'). Wenn gesetzt, wird der Wortpool auf
  /// diese Kategorie gefiltert; wenn null, kommen alle Kategorien (globaler Hub).
  final String? category;

  const WordSearchScreen(
      {super.key, this.difficulty = 'medium', this.category});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final GlobalKey _gridKey = GlobalKey();
  WordSearchPuzzle? _puzzle;
  bool _loading = true;
  String? _category;
  Point? _dragStart;
  Point? _dragEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_category == null) {
      // Kategorie wie bei den bestehenden Kategorie-Screens als
      // Route-Argument möglich (z. B. pushNamed(AppRoutes.wordsearch, arguments: id)).
      final routeId = ModalRoute.of(context)?.settings.arguments as String?;
      _category = widget.category ?? routeId;
    }
    if (_loading && _puzzle == null) _startGame();
  }

  Future<void> _startGame() async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final vq = context.read<VocabQueries>();
    final lang = context
        .read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    var words = await vq.getReadWords(uname, langCode: lang);

    // Optionaler Kategorie-Filter über die bestehende Kategorien-Info.
    final cat = wordCategoryById(_category);
    if (cat != null) {
      words = words.where((e) => cat.containsEntryKey(e.key)).toList();
    }

    final puzzle = generatePuzzle(words, widget.difficulty);
    if (!mounted) return;
    setState(() {
      _puzzle = puzzle;
      _loading = false;
      _dragStart = null;
      _dragEnd = null;
    });
  }

  // ── Zellen-/Pfadberechnung ────────────────────────────────────────

  Point? _cellForPosition(Offset local, double side, WordSearchPuzzle puzzle) {
    final cellSize = side / puzzle.size;
    final row = (local.dy / cellSize).floor();
    final col = (local.dx / cellSize).floor();
    if (row < 0 || row >= puzzle.size || col < 0 || col >= puzzle.size) {
      return null;
    }
    return Point(row, col);
  }

  /// Quantisiert den aktuellen Finger zu einer Zelle auf der Geraden vom
  /// Startpunkt in eine der 8 Richtungen.
  Point _snapToLine(Point start, Point current) {
    final dr = current.row - start.row;
    final dc = current.col - start.col;
    if (dr == 0 && dc == 0) return start;

    final directions = [
      const Point(1, 0),
      const Point(-1, 0),
      const Point(0, 1),
      const Point(0, -1),
      const Point(1, 1),
      const Point(1, -1),
      const Point(-1, 1),
      const Point(-1, -1),
    ];
    Point? bestDir;
    var bestErr = 1 << 29;
    var bestT = 0;
    for (final dir in directions) {
      final t = dr * dir.row + dc * dir.col;
      if (t < 0.5) continue; // nur vorwärts vom Start protokollieren
      final rounded = t.round();
      final snappedRow = start.row + rounded * dir.row;
      final snappedCol = start.col + rounded * dir.col;
      final err =
          (current.row - snappedRow).abs() + (current.col - snappedCol).abs();
      if (err < bestErr || (err == bestErr && rounded > bestT)) {
        bestErr = err;
        bestT = rounded;
        bestDir = dir;
      }
    }
    if (bestDir == null) return start;
    return Point(
        start.row + bestT * bestDir.row, start.col + bestT * bestDir.col);
  }

  /// Alle Zellen der Geraden von [a] bis [b] (inklusive).
  static List<Point> _cellsBetween(Point a, Point b) {
    final dr = (b.row - a.row).sign;
    final dc = (b.col - a.col).sign;
    final steps = math.max((b.row - a.row).abs(), (b.col - a.col).abs());
    return [
      for (var i = 0; i <= steps; i++) Point(a.row + dr * i, a.col + dc * i),
    ];
  }

  // ── Gesten ────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    final puzzle = _puzzle;
    final box = _gridKey.currentContext?.findRenderObject();
    if (puzzle == null || box is! RenderBox) return;
    final local = box.globalToLocal(details.globalPosition);
    final cell = _cellForPosition(local, box.size.width, puzzle);
    setState(() {
      _dragStart = cell;
      _dragEnd = cell;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final puzzle = _puzzle;
    final start = _dragStart;
    final box = _gridKey.currentContext?.findRenderObject();
    if (puzzle == null || start == null || box is! RenderBox) return;
    final local = box.globalToLocal(details.globalPosition);
    final cell = _cellForPosition(local, box.size.width, puzzle);
    if (cell == null) return;
    final end = _snapToLine(start, cell);
    if (end == _dragEnd) return;
    setState(() => _dragEnd = end);
  }

  void _onPanEnd(DragEndDetails details) {
    final puzzle = _puzzle;
    final start = _dragStart;
    final end = _dragEnd;
    setState(() {
      _dragStart = null;
      _dragEnd = null;
    });
    if (puzzle == null || start == null || end == null) return;

    final hit = validatePath(_cellsBetween(start, end), puzzle);
    if (hit == null) return;
    setState(() {
      hit.found = true;
    });
    final allFound = puzzle.words.every((w) => w.found);
    if (allFound) {
      _finishGame(puzzle, score: puzzle.words.length);
    }
  }

  void _showSolution() {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    final score = puzzle.words.where((w) => w.found).length;
    setState(() {
      for (final w in puzzle.words) {
        w.found = true;
      }
    });
    _finishGame(puzzle, score: score);
  }

  /// Spielende: GameOverDialog + Tagesstreak-Update (NUR das – kein SRS-/
  /// Level-Einfluss auf die Vokabeln).
  Future<void> _finishGame(WordSearchPuzzle puzzle,
      {required int score}) async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    if (uname.isNotEmpty) {
      await context.read<VocabQueries>().updateDayStreak(uname);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final result = await showGameOverDialog(
      context,
      score: score,
      highscore: 0,
      newRecord: false,
      gameOverTitle: l10n.wsAllFound,
      ptsLabel: l10n.gameScore,
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

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final puzzle = _puzzle;
    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnWordSearch),
        const AppNavBar(),
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
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _buildGameArea(AppLocalizations l10n, WordSearchPuzzle puzzle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.contentPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(constraints.maxWidth,
                    MediaQuery.sizeOf(context).height * 0.6);
                return SizedBox(
                  width: side,
                  height: side,
                  child: _buildGrid(puzzle, side),
                );
              },
            ),
            const SizedBox(height: AppTheme.contentSpacing),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.wsHint,
                style: const TextStyle(
                    fontSize: AppTheme.lblFontSize, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 6),
            _buildHints(puzzle),
            const SizedBox(height: AppTheme.contentSpacing),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showSolution,
                child:
                    Text(l10n.wsSolution, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildGrid(WordSearchPuzzle puzzle, double side) {
    final size = puzzle.size;
    final highlight = <Point>{};
    final start = _dragStart;
    final end = _dragEnd;
    if (start != null && end != null) {
      highlight.addAll(_cellsBetween(start, end));
    }
    final foundCells = <Point>{
      for (final w in puzzle.words.where((w) => w.found)) ...w.cells,
    };
    final fontSize = math.min(22.0, (side / size) * 0.55);

    return GestureDetector(
      key: _gridKey,
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: size,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: size * size,
        itemBuilder: (context, index) {
          final point = Point(index ~/ size, index % size);
          final inDrag = highlight.contains(point);
          final inFound = foundCells.contains(point);
          return Container(
            decoration: BoxDecoration(
              color: inDrag
                  ? AppTheme.colorPrimary
                  : inFound
                      ? AppTheme.green3.withValues(alpha: 0.3)
                      : AppTheme.grey1,
              border: Border.all(color: AppTheme.grey3, width: 0.5),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                puzzle.letterAt(point),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: inDrag || inFound ? Colors.white : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHints(WordSearchPuzzle puzzle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in puzzle.words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: w.found ? AppTheme.grey2 : AppTheme.grey1,
              border: Border.all(color: AppTheme.grey3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              w.translation.isEmpty ? w.word : w.translation,
              style: TextStyle(
                fontSize: 14,
                color: w.found ? Colors.white38 : Colors.white,
                decoration: w.found ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white60,
              ),
            ),
          ),
      ],
    );
  }
}

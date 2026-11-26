import '../routes.dart';
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
import 'hangman_engine.dart';

/// Hangman-Spielscreen.
///
/// Analog zu Turbo/Wortsuche/Kreuzwortraetsel nutzt er ausschliesslich
/// bestehende Patterns (BoxTitle/BoxBottom, VocabQueries.getReadWords,
/// showGameOverDialog). Er hat KEINEN Einfluss auf den Vokabel-Fortschritt –
/// geschrieben wird beim Abschluss NUR [VocabQueries.updateDayStreak]
/// (kein SRS-/Level-/Rekord-Einfluss).
class HangmanScreen extends StatefulWidget {
  final String difficulty;

  /// Kategorie-Id (z. B. 'grp_alltag'). Wenn gesetzt, wird der Wortpool auf
  /// diese Kategorie gefiltert; wenn null, kommen alle Kategorien.
  final String? category;

  const HangmanScreen({super.key, this.difficulty = 'medium', this.category});

  @override
  State<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends State<HangmanScreen> {
  HangmanRound? _round;
  bool _loading = true;
  String? _category;
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_category == null) {
      // Kategorie wie bei den bestehenden Kategorie-Screens als
      // Route-Argument moeglich (z. B. pushNamed(AppRoutes.hangman, arguments: id)).
      final routeId = ModalRoute.of(context)?.settings.arguments as String?;
      _category = widget.category ?? routeId;
    }
    if (_loading && _round == null) _initRound();
  }

  Future<void> _initRound() async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final vq = context.read<VocabQueries>();

    final lang = context
        .read<NavigationState>()
        .resolveActiveLang(context.read<UserState>().userData);
    var words = await vq.getReadWords(uname, langCode: lang);

    // Optionaler Kategorie-Filter ueber die bestehende Kategorien-Info.
    final cat = wordCategoryById(_category);
    if (cat != null) {
      words = words.where((e) => cat.containsEntryKey(e.key)).toList();
    }

    final round = createRound(words, widget.difficulty);
    if (!mounted) return;
    setState(() {
      _round = round;
      _currentIndex = 0;
      _loading = false;
    });
  }

  void _onLetterPressed(String letter) {
    final round = _round;
    if (round == null || isRoundOver(round)) return;
    final word = round.entries[_currentIndex];

    final correct = guessLetter(word, letter);
    if (correct) {
      if (isWordSolved(word)) {
        final newSolved = round.solvedCount + 1;
        if (newSolved >= round.targetWordCount) {
          round.solvedCount = newSolved;
          _endRound(win: true);
        } else {
          setState(() {
            round.solvedCount = newSolved;
            _currentIndex++;
          });
        }
      } else {
        setState(() {}); // Buchstabe aufdecken
      }
    } else {
      round.wrongGuesses.add(letter);
      if (round.lost) {
        _endRound(win: false);
      } else {
        setState(() {}); // Leben abziehen + Fortschritt anzeigen
      }
    }
  }

  /// Spielende: Tagesstreak-Update (NUR das), dann GameOverDialog.
  ///
  /// - Niederlage: score = Anzahl vollstaendig geloester Woerter.
  /// - Sieg:       score = 5 (alle Woerter), bonus = verbleibende Leben
  ///               (ueber das highscore-Feld des Dialogs angezeigt).
  Future<void> _endRound({required bool win}) async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    if (uname.isNotEmpty) {
      await context.read<VocabQueries>().updateDayStreak(uname);
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final round = _round;
    if (round == null) return;
    final result = await showGameOverDialog(
      context,
      score: win ? round.targetWordCount : round.solvedCount,
      highscore: win ? round.remainingLives : 0,
      newRecord: false,
      gameOverTitle: win ? l10n.hangmanRoundWon : l10n.hangmanRoundLost,
      ptsLabel: win ? l10n.hangmanLives : l10n.gameScore,
      restartText: l10n.gameRestart,
      backText: l10n.gameBack,
    );
    if (!mounted) return;
    if (result == 'restart') {
      setState(() {
        _round = null;
        _currentIndex = 0;
        _loading = true;
      });
      await _initRound();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = _round;
    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.btnHangman),
        const AppNavBar(),
        Expanded(
          child: _loading || round == null
              ? const Center(child: CircularProgressIndicator())
              : round.entries.isEmpty
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
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _buildGameArea(AppLocalizations l10n, HangmanRound round) {
    final word = round.entries[_currentIndex];
    return Column(children: [
      _buildStatusRow(round),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.contentPadding, vertical: 4),
          child: Column(children: [
            SizedBox(
              width: 160,
              height: 200,
              child: CustomPaint(
                  painter: _HangmanPainter(round.wrongGuesses.length)),
            ),
            _buildHintCard(l10n, word.hint),
            const SizedBox(height: AppTheme.contentSpacing),
            _buildWordTiles(word),
            const SizedBox(height: AppTheme.contentSpacing),
            _buildWrongRow(l10n, round.wrongGuesses),
          ]),
        ),
      ),
      _buildKeyboard(round),
    ]);
  }

  /// Statuszeile: Herzleiste (Leben) links, Fortschrittspunkte rechts.
  Widget _buildStatusRow(HangmanRound round) {
    return Container(
      height: 44,
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grey2)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Row(children: [
          for (var i = 0; i < round.lives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Image.asset(
                i < round.remainingLives
                    ? 'assets/game_assets/heart.png'
                    : 'assets/game_assets/heart_empty.png',
                width: 18,
                height: 18,
              ),
            ),
        ]),
        const Spacer(),
        _buildProgressDots(round),
      ]),
    );
  }

  /// Sprachneutrale Fortschrittspunkte fuer die Woerter der Runde.
  Widget _buildProgressDots(HangmanRound round) {
    return Row(children: [
      for (var i = 0; i < round.targetWordCount; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: i < round.solvedCount
                  ? AppTheme.green3
                  : i == _currentIndex
                      ? AppTheme.colorPrimary
                      : AppTheme.grey3,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ]);
  }

  Widget _buildHintCard(AppLocalizations l10n, String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.grey2,
        border: Border.all(color: AppTheme.grey3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: AppTheme.lblFontSize, color: Colors.white),
      ),
    );
  }

  Widget _buildWordTiles(HangmanWord word) {
    final revealed = revealedWord(word);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final ch in revealed.split(''))
          Container(
            width: 34,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ch == '_'
                  ? AppTheme.grey1
                  : AppTheme.lightBlue3.withValues(alpha: 0.25),
              border: Border.all(color: AppTheme.grey3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ch == '_' ? '' : ch,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildWrongRow(AppLocalizations l10n, List<String> wrong) {
    final text = wrong.isEmpty
        ? l10n.hangmanWrongLetters
        : '${l10n.hangmanWrongLetters} ${wrong.join(' ')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppTheme.grey1, border: Border.all(color: AppTheme.grey3)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }

  /// On-Screen-Buchstabentastatur (A-Z). Bereits getippte Buchstaben
  /// (richtig ODER falsch) sind markiert und nicht mehr waehlbar.
  Widget _buildKeyboard(HangmanRound round) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final current = round.entries[_currentIndex];
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final ch in letters.split('')) _buildKey(ch, current),
        ],
      ),
    );
  }

  Widget _buildKey(String ch, HangmanWord word) {
    final used = word.guessed.contains(ch);
    final correct = used && word.target.contains(ch);
    final wrong = used && !correct;
    final bg = correct
        ? AppTheme.green3.withValues(alpha: 0.5)
        : wrong
            ? AppTheme.red2.withValues(alpha: 0.4)
            : AppTheme.grey2;
    return SizedBox(
      width: 32,
      height: 38,
      child: OutlinedButton(
        onPressed: used ? null : () => _onLetterPressed(ch),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: AppTheme.colorPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          ch,
          style: TextStyle(
              fontSize: 16,
              color: used ? Colors.white38 : AppTheme.colorPrimary),
        ),
      ),
    );
  }
}

/// Zeichnet das Hangman-Strichmaennchen samt Galgen (10 Stufen) per
/// CustomPaint – keine Assets, keine svg-Pakete.
///
/// Je falschem Buchstaben ([wrongCount]) kommt ein weiterer Teil hinzu:
/// Boden, Pfosten, Balken, Seil, Kopf, Koerper, linker Arm, rechter Arm,
/// linkes Bein, rechtes Bein. Farb-/Strichwerte aus dem AppTheme-Stil.
class _HangmanPainter extends CustomPainter {
  final int wrongCount;

  _HangmanPainter(this.wrongCount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final steps = wrongCount.clamp(0, 10);

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1 * w, y1 * h), Offset(x2 * w, y2 * h), paint);

    // 0: Boden
    if (steps > 0) line(0.15, 0.9, 0.9, 0.9);
    // 1: Pfosten
    if (steps > 1) line(0.25, 0.9, 0.25, 0.12);
    // 2: Balken
    if (steps > 2) line(0.25, 0.12, 0.62, 0.12);
    // 3: Seil
    if (steps > 3) line(0.62, 0.12, 0.62, 0.18);
    // 4: Kopf
    if (steps > 4) {
      canvas.drawCircle(Offset(0.62 * w, 0.26 * h), 0.06 * w, paint);
    }
    // 5: Koerper
    if (steps > 5) line(0.62, 0.33, 0.62, 0.62);
    // 6: linker Arm
    if (steps > 6) line(0.62, 0.39, 0.44, 0.51);
    // 7: rechter Arm
    if (steps > 7) line(0.62, 0.39, 0.8, 0.51);
    // 8: linkes Bein
    if (steps > 8) line(0.62, 0.62, 0.44, 0.82);
    // 9: rechtes Bein
    if (steps > 9) line(0.62, 0.62, 0.8, 0.82);
  }

  @override
  bool shouldRepaint(_HangmanPainter oldDelegate) =>
      oldDelegate.wrongCount != wrongCount;
}

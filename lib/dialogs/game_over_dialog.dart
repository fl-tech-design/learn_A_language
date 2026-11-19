import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Game-over dialog – replaces Pop_GameOver.
Future<String?> showGameOverDialog(
  BuildContext context, {
  required int score,
  required int highscore,
  required bool newRecord,
  required String gameOverTitle,
  required String ptsLabel,
  required String restartText,
  required String backText,
}) async {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.dialogBackground,
      shape: AppTheme.dialogShape(),
      title: Text(gameOverTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ptsLabel,
              style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          Text('$score',
              style: const TextStyle(
                  fontSize: 40, color: AppTheme.yellow1, fontFamily: 'Jura')),
          const SizedBox(height: 8),
          Text(l10n.recordWithHighscore(highscore, ptsLabel),
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          if (newRecord)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/game_assets/trophy.png',
                    width: 24, height: 24),
                const SizedBox(width: 6),
                Text(l10n.newRecord,
                    style:
                        const TextStyle(fontSize: 16, color: AppTheme.yellow1)),
              ],
            ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('restart'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.colorPrimary),
                  foregroundColor: AppTheme.colorPrimary,
                ),
                child: Text(restartText),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('back'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.colorPrimary),
                  foregroundColor: AppTheme.colorPrimary,
                ),
                child: Text(backText),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

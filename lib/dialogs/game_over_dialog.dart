import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.colorPrimary,
      title: Text(gameOverTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ptsLabel,
              style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('$score',
              style: const TextStyle(
                  fontSize: 40, color: AppTheme.yellow1, fontFamily: 'Jura')),
          const SizedBox(height: 8),
          Text('Rekord: $highscore $ptsLabel',
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          if (newRecord)
            const Text('Neuer Rekord! 🏆',
                style: TextStyle(fontSize: 16, color: AppTheme.yellow1)),
        ],
      ),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('restart'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              foregroundColor: Colors.black,
            ),
            child: Text(restartText),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('back'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              foregroundColor: Colors.black,
            ),
            child: Text(backText),
          ),
        ),
      ],
    ),
  );
}
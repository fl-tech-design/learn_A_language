import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Session-limit dialog – replaces Pop_Limit.
Future<bool?> showLimitDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String continueText,
  required String endText,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.colorPrimary,
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black)),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  foregroundColor: Colors.black,
                ),
                child: Text(continueText),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  foregroundColor: Colors.black,
                ),
                child: Text(endText),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result;
}

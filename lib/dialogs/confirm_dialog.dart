import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generic confirm dialog – replaces Pop_Warn.
/// Returns `true` when confirmed, `false`/`null` on cancel.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  required String cancelText,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.colorPrimary,
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: Colors.black)),
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText, style: const TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmText, style: const TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Info-Popup → AlertDialog with scrollable text.
void showInfoDialog(BuildContext context, String message, String title) {
  final l10n = AppLocalizations.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.dialogBackground,
      shape: AppTheme.dialogShape(),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.close,
              style: const TextStyle(color: AppTheme.colorPrimary, fontSize: 18)),
        ),
      ],
    ),
  );
}

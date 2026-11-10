import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Info-Popup → AlertDialog with scrollable text.
void showInfoDialog(BuildContext context, String message, String title) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.colorPrimary,
      title: Text(title,
          style: const TextStyle(fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.black)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Schliessen',
              style: TextStyle(color: Colors.black, fontSize: 18)),
        ),
      ],
    ),
  );
}
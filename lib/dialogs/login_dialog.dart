import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Login-Popup → shows list of registered users.
Future<String?> showLoginDialog(
  BuildContext context,
  List<String> users,
  String loginTitle,
  String addUserText,
  String cancelText,
) async {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.dialogBackground,
      shape: AppTheme.dialogShape(),
      title: Text(loginTitle,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noUReg,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (_, i) => SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(users[i]),
                      child: Text(users[i],
                          style: const TextStyle(
                              color: AppTheme.colorPrimary, fontSize: 20)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('__add__'),
              child: Text(addUserText,
                  style: const TextStyle(fontSize: 14, color: AppTheme.colorPrimary)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelText,
              style: const TextStyle(fontSize: 18, color: AppTheme.colorPrimary)),
        ),
      ],
    ),
  );
}

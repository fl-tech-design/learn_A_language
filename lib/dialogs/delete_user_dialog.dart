import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Delete-user dialog – replaces Pop_Delete_User.
Future<String?> showDeleteUserDialog(
  BuildContext context,
  String title,
  String hintText,
  String confirmText,
  String cancelText,
) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.dialogBackground,
      shape: AppTheme.dialogShape(),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hintText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppTheme.dialogInputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: AppTheme.colorPrimary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelText,
              style: const TextStyle(color: AppTheme.colorPrimary)),
        ),
        TextButton(
          onPressed: () {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.of(ctx).pop(name);
          },
          child: Text(confirmText,
              style: const TextStyle(color: AppTheme.colorPrimary)),
        ),
      ],
    ),
  );
}

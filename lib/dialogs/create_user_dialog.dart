import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import '../theme/app_theme.dart';

/// Create-user dialog – replaces Pop_Create_User.
Future<Map<String, String>?> showCreateUserDialog(
  BuildContext context,
  String title,
  String hintText,
  String nativeLangLabel,
  String deLabel,
  String enLabel,
  String frLabel,
  String confirmText,
  String cancelText,
) async {
  final nameCtrl = TextEditingController();
  String mLang = 'de';

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppTheme.dialogBackground,
        shape: AppTheme.dialogShape(),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cmunobx', color: AppTheme.colorPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hintText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
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
              const SizedBox(height: 12),
              Text(nativeLangLabel,
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(toBeginningOfSentenceCase(deLabel)),
                      selected: mLang == 'de',
                      onSelected: (_) => setState(() => mLang = 'de'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(toBeginningOfSentenceCase(enLabel)),
                      selected: mLang == 'en',
                      onSelected: (_) => setState(() => mLang = 'en'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(toBeginningOfSentenceCase(frLabel)),
                      selected: mLang == 'fr',
                      onSelected: (_) => setState(() => mLang = 'fr'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelText,
                style: const TextStyle(fontSize: 16, color: AppTheme.colorPrimary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop({'username': name, 'm_lang': mLang});
            },
            child: Text(confirmText,
                style: const TextStyle(fontSize: 16, color: AppTheme.colorPrimary)),
          ),
        ],
      ),
    ),
  );
}

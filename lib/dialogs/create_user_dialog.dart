import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../managers/language_manager.dart';

/// Create-user dialog – replaces Pop_Create_User.
Future<Map<String, String>?> showCreateUserDialog(
  BuildContext context,
  String title,
  String hintText,
  String nativeLangLabel,
  String deLabel,
  String enLabel,
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
        backgroundColor: AppTheme.colorPrimary,
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cmunobx', color: Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hintText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 12),
              Text(nativeLangLabel,
                  style: const TextStyle(fontSize: 16, color: Colors.black)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(letUppercaseFirst(deLabel)),
                      selected: mLang == 'de',
                      onSelected: (_) => setState(() => mLang = 'de'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(letUppercaseFirst(enLabel)),
                      selected: mLang == 'en',
                      onSelected: (_) => setState(() => mLang = 'en'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(cancelText,
                style: const TextStyle(fontSize: 16, color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop({'username': name, 'm_lang': mLang});
            },
            child: Text(confirmText,
                style: const TextStyle(fontSize: 16, color: Colors.black)),
          ),
        ],
      ),
    ),
  );
}

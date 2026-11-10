import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../managers/language_manager.dart';

/// Title bar widget – replaces BoxTitle from Kivy.
class BoxTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onInfo;

  const BoxTitle({super.key, required this.title, this.onInfo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * AppTheme.boxTitleHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey2, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.2,
              child: Image.asset('assets/images/logo_main.png'),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.grey2,
                  fontFamily: 'Jura',
                  fontWeight: FontWeight.w700,
                  fontSize: AppTheme.titleFontSize,
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.2,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onInfo,
                  child: const Text(
                    '?',
                    style: TextStyle(
                      color: AppTheme.colorPrimary,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar widget – replaces BoxBottom.
class BoxBottom extends StatelessWidget {
  final VoidCallback? onSettings;
  final VoidCallback? onExit;
  final String settingsText;
  final String exitText;

  const BoxBottom({
    super.key,
    this.onSettings,
    this.onExit,
    required this.settingsText,
    required this.exitText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * AppTheme.boxBottomHeight,
      color: const Color(0xFF1F1F1F),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorPrimary,
                side: const BorderSide(color: AppTheme.colorPrimary),
              ),
              child: Text(settingsText),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: onExit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorPrimary,
                side: const BorderSide(color: AppTheme.colorPrimary),
              ),
              child: Text(exitText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flag-box widget for language selection – replaces BoxFlag.
class FlagBox extends StatelessWidget {
  final String flagAsset;
  final String label;
  final VoidCallback? onTap;

  const FlagBox({
    super.key,
    required this.flagAsset,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey3, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(flagAsset, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: onTap,
              child: Text(
                letUppercaseFirst(label),
                style: const TextStyle(
                  color: AppTheme.colorPrimary,
                  fontFamily: 'Jura',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
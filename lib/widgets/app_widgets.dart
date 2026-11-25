import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import '../l10n/app_localizations.dart';
import '../services/audio_service.dart';
import '../services/storage_error_bus.dart';
import '../theme/app_theme.dart';

/// Zeigt Speicher-/Persistenzwarnungen EINMALIG als SnackBar an (kein
/// Dialog, kein Spam): Der globale [StorageErrorBus] hält je Ablauf nur eine
/// Meldung, die hier mit [StorageErrorBus.takeLast] konsumiert wird.
///
/// Der Listener wird im Widget-Baum der `MaterialApp` (builder) eingebettet,
/// damit auch Meldungen aus der Zeit VOR `runApp` (fehlgeschlagener
/// Auto-Login in main.dart) beim App-Start sichtbar werden.
class StorageWarningListener extends StatefulWidget {
  final Widget child;

  const StorageWarningListener({super.key, required this.child});

  @override
  State<StorageWarningListener> createState() => _StorageWarningListenerState();
}

class _StorageWarningListenerState extends State<StorageWarningListener> {
  @override
  void initState() {
    super.initState();
    StorageErrorBus.instance.addListener(_onStorageError);
    final pending = StorageErrorBus.instance.takeLast();
    if (pending != null) _showFor(pending);
  }

  @override
  void dispose() {
    StorageErrorBus.instance.removeListener(_onStorageError);
    super.dispose();
  }

  void _onStorageError() {
    final kind = StorageErrorBus.instance.takeLast();
    if (kind == null) return;
    _showFor(kind);
  }

  void _showFor(StorageErrorKind kind) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = switch (kind) {
        StorageErrorKind.saveFailed ||
        StorageErrorKind.progressNotSaved =>
          l10n.msgSaveFailed,
        StorageErrorKind.userDataRecovered => l10n.msgUserDataRecovered,
        StorageErrorKind.userDataUnloadable => l10n.msgUserDataUnloadable,
        StorageErrorKind.appDataRecovered => l10n.msgAppDataRecovered,
        StorageErrorKind.assetsCopyFailed => l10n.msgAssetsCopyFailed,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Title bar widget – replaces BoxTitle from Kivy.
class BoxTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onInfo;

  const BoxTitle({super.key, required this.title, this.onInfo});

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      AppTheme.titleBarMinHeight,
      MediaQuery.of(context).size.height * AppTheme.boxTitleHeight,
    );
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey2),
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = math.max(
      AppTheme.bottomBarMinHeight,
      MediaQuery.of(context).size.height * AppTheme.boxBottomHeight,
    );
    return Container(
      height: height + bottomPadding,
      color: const Color(0xFF1F1F1F),
      padding: EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8 + bottomPadding),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorPrimary,
                side: const BorderSide(color: AppTheme.colorPrimary),
              ),
              child: Text(settingsText, style: const TextStyle(color: AppTheme.colorPrimary)),
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
              child: Text(exitText, style: const TextStyle(color: AppTheme.colorPrimary)),
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
        border: Border.all(color: AppTheme.grey3),
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
                toBeginningOfSentenceCase(label),
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

/// Aussprache-Buttons (Replay + Slow) für Wort-Screens.
///
/// Beide Buttons nutzen das gleiche Speaker-Icon; der Slow-Button trägt
/// zusätzlich das Tempo-Label (z. B. „0.65×“) inline im Icon, damit
/// langsameres Anhören für Anfänger direkt erkennbar ist (Ticket #32).
class PlaybackButtons extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onSlow;

  const PlaybackButtons({
    super.key,
    required this.onPlay,
    required this.onSlow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _speakerButton(onPressed: onPlay),
        const SizedBox(width: 18),
        _speakerButton(
          onPressed: onSlow,
          label: '${AudioService.slowTempo.toStringAsFixed(2)}×',
        ),
      ],
    );
  }

  Widget _speakerButton({required VoidCallback onPressed, String? label}) {
    return IconButton(
      iconSize: 38,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      color: AppTheme.colorPrimary,
      icon: label == null
          ? const Icon(Icons.volume_up)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up,
                    size: 30, color: AppTheme.colorPrimary),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorPrimary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

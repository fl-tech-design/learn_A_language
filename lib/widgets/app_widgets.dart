import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import '../l10n/app_localizations.dart';
import '../services/audio_service.dart';
import '../services/storage_error_bus.dart';
import '../theme/app_theme.dart';
import 'version_label.dart';

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

/// Fixe Navigationsleiste unter der Titelbox (Ticket #63, AppNavBar).
///
/// Ersetzt die bisher uneinheitlichen „Zurück“-Buttons: sichtbar auf allen
/// Screens ausser dem Start-Screen, immer an derselben Stelle, unabhängig vom
/// Scroll-Zustand. Zwei Buttons:
///  - „Zurück“  → zum letzten Screen (Navigator.pop),
///  - „Start“   → zurück zur Startseite (popUntil zur untersten Route).
class AppNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onHome;

  const AppNavBar({super.key, this.onBack, this.onHome});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.back,
              icon: const Icon(Icons.arrow_back, color: AppTheme.colorPrimary),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.btnHome,
              icon:
                  const Icon(Icons.home_outlined, color: AppTheme.colorPrimary),
              onPressed: onHome ??
                  () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schlanke Bottom bar – kompakte Icon-Standardfunktionen (Ticket #63).
/// Links ⚙️ (Settings), rechts ⏻ (App beenden); die freie Mitte zeigt per
/// Default die App-Version ([VersionLabel]), kann aber über [center] ersetzt
/// werden. Die Höhe ist bewusst halbiert (AppTheme.boxBottomHeight).
class BoxBottom extends StatelessWidget {
  final VoidCallback? onSettings;
  final VoidCallback? onExit;
  final Widget? center;

  const BoxBottom({
    super.key,
    this.onSettings,
    this.onExit,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = math.max(
      AppTheme.bottomBarMinHeight,
      MediaQuery.of(context).size.height * AppTheme.boxBottomHeight,
    );
    return Container(
      height: height + bottomPadding,
      color: const Color(0xFF1F1F1F),
      padding:
          EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 4 + bottomPadding),
      child: Row(
        children: [
          if (onSettings != null)
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings, color: AppTheme.colorPrimary),
              onPressed: onSettings,
            ),
          Expanded(
            child: Center(
              child: center ??
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: VersionLabel(),
                  ),
            ),
          ),
          if (onExit != null)
            IconButton(
              tooltip: l10n.exit,
              icon: const Icon(Icons.power_settings_new,
                  color: AppTheme.colorPrimary),
              onPressed: onExit,
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

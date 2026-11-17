import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';

/// Dezente App-Versionsanzeige (Quelle: pubspec.yaml via package_info_plus),
/// verwendet im Loading- und im Settings-Screen.
/// Es wird nur die semantische Version angezeigt (z. B. v1.4.1),
/// nicht die Build-Nummer (+8), die nur intern fur Update-Erkennung dient.
class VersionLabel extends StatefulWidget {
  const VersionLabel({super.key});

  @override
  State<VersionLabel> createState() => _VersionLabelState();
}

class _VersionLabelState extends State<VersionLabel> {
  String _versionText = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    String text;
    try {
      final info = await PackageInfo.fromPlatform();
      text = 'v${info.version}';
    } catch (_) {
      // Kein nativer Plugin-Kanal (z. B. Widget-Tests) -> neutraler Fallback.
      text = 'vdev';
    }
    if (mounted) {
      setState(() => _versionText = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _versionText,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AppTheme.smallFontSize,
        color: Colors.white54,
        fontFamily: 'Jura',
      ),
    );
  }
}

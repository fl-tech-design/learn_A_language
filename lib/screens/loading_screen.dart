import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Splash/loading screen – 1:1 from loadingpage.py.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progress += 10;
      });
      if (_progress >= 100) {
        timer.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/start');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loadingText = l10n.loading;
    final loadingComplete = l10n.loadingComplete;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/spl_start.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18,
            left: 0,
            right: 0,
            child: Text(
              _progress >= 100
                  ? '${toBeginningOfSentenceCase(loadingComplete)}!'
                  : '${toBeginningOfSentenceCase(loadingText)}...  ${_progress.toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                color: Colors.white,
                fontFamily: 'Jura',
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.06,
            left: MediaQuery.of(context).size.width * 0.125,
            right: MediaQuery.of(context).size.width * 0.125,
            child: LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: AppTheme.grey3,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.colorPrimary),
              minHeight: 20,
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.02,
            left: 0,
            right: 0,
            child: const Text(
              'v${AppTheme.versionNr}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontFamily: 'Jura',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

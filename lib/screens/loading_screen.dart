import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/language_manager.dart';

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
    final appState = context.watch<AppState>();
    final loadingText = appState.baseTxt['loading']?.toString() ?? 'Loading';
    final loadingComplete =
        appState.baseTxt['loading_complete']?.toString() ?? 'Loading complete';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/spl_start.png', fit: BoxFit.fill),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.12,
            left: 0,
            right: 0,
            child: Text(
              _progress >= 100
                  ? '${letUppercaseFirst(loadingComplete)}!'
                  : '${letUppercaseFirst(loadingText)}...  ${_progress.toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                color: Colors.white,
                fontFamily: 'Jura',
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.01,
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
        ],
      ),
    );
  }
}
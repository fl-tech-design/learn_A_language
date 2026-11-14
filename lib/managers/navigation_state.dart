import 'package:flutter/material.dart';

/// Navigation & word-mode state – extracted from AppState (Commit B).
/// Manages wordMode, statsVersion, and rebuild triggers for screens.
class NavigationState extends ChangeNotifier {
  String _wordMode = 'new';
  int _statsVersion = 0;

  int get statsVersion => _statsVersion;
  String get wordMode => _wordMode;

  void notifyStatsChanged() {
    _statsVersion++;
    notifyListeners();
  }

  void setWordMode(String mode) {
    _wordMode = mode;
    notifyListeners();
  }
}
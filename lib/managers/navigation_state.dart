import 'package:flutter/material.dart';

/// Global route observer – notifies subscribed RouteAware screens when a
/// pushed route on top is popped (e.g. start screen refreshes the stats).
/// Declared here (not in main.dart) so screens can subscribe without a
/// main.dart import cycle.
final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();

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
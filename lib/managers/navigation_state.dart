import 'package:flutter/material.dart';

import '../models/app_models.dart';

/// Global route observer – notifies subscribed RouteAware screens when a
/// pushed route on top is popped (e.g. start screen refreshes the stats).
/// Declared here (not in main.dart) so screens can subscribe without a
/// main.dart import cycle.
final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Navigation & word-mode state – extracted from AppState (Commit B).
/// Manages wordMode, statsVersion, and rebuild triggers for screens.
///
/// Zusätzlich führt er den **aktiven Kurs-Kontext** ([activeLangCode]):
/// Der aktuell geöffnete Kurs bestimmt, welche Sprachdaten (Wörter/Audio)
/// geladen werden – unabhängig von der Muttersprache des Nutzers.
class NavigationState extends ChangeNotifier {
  String _wordMode = 'new';
  int _statsVersion = 0;
  String? _selectedCategoryId;

  String? _activeCourseId;
  String? _activeLangCode;

  int get statsVersion => _statsVersion;
  String get wordMode => _wordMode;
  /// Id der aktuell gewählten Word-Kategorie (null = ganzer Kurs).
  String? get selectedCategoryId => _selectedCategoryId;

  /// Id des zuletzt geöffneten Kurses (z. B. `'de_verben_a1'`) oder `null`.
  String? get activeCourseId => _activeCourseId;

  /// Sprach-Code des zuletzt geöffneten Kurses (z. B. `'de'`) oder `null`.
  String? get activeLangCode => _activeLangCode;

  void notifyStatsChanged() {
    _statsVersion++;
    notifyListeners();
  }

  void setWordMode(String mode) {
    _wordMode = mode;
    notifyListeners();
  }

  void setSelectedCategoryId(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  /// Setzt den aktiven Kurs-Kontext, bevor Lern-/Spiel-/Grammatik-Screens
  /// geöffnet werden. Liefert den Kurs-Sprach-Code zurück.
  String setActiveCourse(LanguageCourse course) {
    _activeCourseId = course.id;
    _activeLangCode = course.languageCode;
    notifyListeners();
    return course.languageCode;
  }

  void clearActiveCourse() {
    _activeCourseId = null;
    _activeLangCode = null;
    notifyListeners();
  }

  /// Entscheidet die effektive Kurssprache: erst der aktive Kurs-Kontext,
  /// dann (deterministisch statt Einfügereihenfolge) die erste vom Nutzer
  /// gewählte Kurssprache, dann der erste vorhandene Sprach-Bucket, zuletzt
  /// `'de'` als Default.
  ///
  /// Deterministische Kurswahl (Ticket #74): Ohne gesetzten aktiven Kurs
  /// (App-Neustart ohne Session-Restore, Navigation ohne erneuten Kurs-Klick)
  /// bestimmte früher die Einfügereihenfolge von `vocabByLang` (z. B. immer
  /// `'de'` zuerst) die Sprache – für Griechisch/Russisch-Nutzer luden die
  /// Spiele dadurch in der falschen Sprache („Keine gelesenen Wörter").
  String resolveActiveLang(UserData? userData) {
    final l = _activeLangCode;
    if (l != null && l.isNotEmpty) return l;
    if (userData != null && userData.selectedCourses.isNotEmpty) {
      for (final id in userData.selectedCourses) {
        final c = availableCourses[id];
        if (c != null) return c.languageCode;
      }
    }
    if (userData != null && userData.vocabByLang.isNotEmpty) {
      return userData.vocabByLang.keys.first;
    }
    return 'de';
  }
}
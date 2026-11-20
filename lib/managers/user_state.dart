import 'dart:developer' show log;

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
import 'user_manager.dart';
import 'vocab_manager.dart';

/// User state – manages login, registration, courses, and user data.
/// Extracted from the former God Object AppState (Commit C).
/// DataState (data/locale/colors) and NavigationState (wordMode/stats)
/// were extracted in Commits A and B.
class UserState extends ChangeNotifier {
  final UserManager _userManager;
  final VocabManager _vocabManager;

  UserState({required UserManager userManager, required VocabManager vocabManager})
      : _userManager = userManager,
        _vocabManager = vocabManager;
  // User data
  UserData? _userData;

  // ── Getters ────────────────────────────────────────────────────
  UserData? get userData => _userData;

  // ── Login / User management ───────────────────────────────────
  //
  // REIHENFOLGE: Erst werden die Benutzerdaten geladen und validiert, DANN
  // (und nur bei Erfolg) wird der Login-State persistiert. Scheitert das
  // Laden, bleibt kein Halblogin in app_data zurück. Die Rückgabe ist
  // `null` bei Erfolg bzw. ein Fehlertext, den die UI anzeigen kann.
  Future<String?> login(String username) async {
    final UserData? loaded;
    try {
      loaded = await _userManager.loadUserdata(username);
    } on PersistenceException catch (e) {
      log('login: Userdaten für $username unlesbar ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.userDataUnloadable);
      return 'Benutzerdaten konnten nicht geladen werden.';
    }
    if (loaded == null) {
      return 'Benutzer ist nicht registriert.';
    }

    try {
      await _userManager.changeLoginState(newState: true);
      await _userManager.setLoggedUname(username);
    } catch (e) {
      log('login: Login-State konnte nicht persistiert werden ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
      return 'Login konnte nicht gespeichert werden.';
    }

    _userData = loaded;
    // Wörterbuch-Quelle sind IMMER die aktuellen Asset-Dicts: Das eventuell
    // eingebettete language-Feld leert initVocabForUser statt es als Quelle
    // zu nutzen. Genau ein Init- + Migrationslauf pro Login/Auto-Login.
    await _vocabManager.initVocabForUser(username, const {});
    await _vocabManager.migrateVocabForUser(username);
    log('login: einmaliger Vocab-Init + Migrationslauf für $username');

    await _loadUserData(username);
    await _autoSelectCourses(username);
    notifyListeners();
    return null;
  }

  /// Creates a brand new user and logs them in.
  Future<String?> registerUser(String username, String mLang) async {
    final String result;
    try {
      result = await _userManager.createUserFile(username, mLang, {});
    } on PersistenceException catch (e) {
      log('registerUser: Anlegen von $username fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
      return 'Benutzer konnte nicht erstellt werden (Speicherfehler).';
    }
    if (!result.contains('erfolgreich')) {
      return result;
    }

    await _userManager.addNewUserToList(username);
    await _userManager.changeLoginState(newState: true);
    await _userManager.setLoggedUname(username);

    final targetLang = mLang == 'de' ? 'en' : 'de';
    final langDict = await _vocabManager.loadLanguageDictFromDir(targetLang);
    await _vocabManager.initVocabForUser(username, langDict);
    await _vocabManager.migrateVocabForUser(username);

    await _loadUserData(username);
    notifyListeners();
    return null;
  }

  /// Lädt UserData geschützt: Eine korrupte Datei crasht nicht mehr, sondern
  /// wird geloggt und einmalig über den [StorageErrorBus] gemeldet (Rückgabe
  /// `null` wie bei fehlender Datei).
  Future<UserData?> _loadSafe(String username) async {
    try {
      return await _userManager.loadUserdata(username);
    } on PersistenceException catch (e) {
      log('user_state: Userdaten für $username unlesbar ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.userDataUnloadable);
      return null;
    }
  }

  Future<void> _loadUserData(String username) async {
    try {
      _userData = await _userManager.loadUserdata(username);
    } on PersistenceException catch (e) {
      // Wird z. B. nach initVocab/migrate erneut geladen; schlägt das fehl,
      // bleibt der bereits geladene Stand erhalten und es gibt keinen Crash.
      log('_loadUserData: $username unlesbar ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.userDataUnloadable);
    }
  }

  /// Speichert UserData, ohne den UI-Aufrufer zu crashen: Fehler werden
  /// geloggt und einmalig über den [StorageErrorBus] gemeldet.
  Future<void> _saveSafe(String username, UserData data) async {
    try {
      await _userManager.saveUserdata(username, data);
    } on PersistenceException catch (e) {
      log('user_state: Speichern für $username fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.progressNotSaved);
    }
  }

  /// Auto-selects courses for existing users who have vocab but no courses.
  Future<void> _autoSelectCourses(String username) async {
    if (_userData == null) return;
    if (_userData!.selectedCourses.isNotEmpty) return;
    if (_userData!.vocab.isEmpty) return;

    final targetLang = _userData!.mLang == 'de' ? 'en' : 'de';
    final derived = availableCourses.entries
        .where((e) => e.value.languageCode == targetLang)
        .map((e) => e.key)
        .toList();
    if (derived.isEmpty) return;

    final userData = await _loadSafe(username);
    if (userData == null) return;
    final updated = userData.copyWith(selectedCourses: derived);
    await _saveSafe(username, updated);
    await _loadUserData(username);
    notifyListeners();
  }
  // ── Course management ─────────────────────────────────────────

  /// Returns the user's selected course IDs, or auto-derives from target lang.
  List<String> get selectedCourseIds {
    final fromUser = _userData?.selectedCourses ?? [];
    if (fromUser.isNotEmpty) return fromUser;
    if (_userData?.vocab.isNotEmpty ?? false) {
      final targetLang = _userData!.mLang == 'de' ? 'en' : 'de';
      final derived = availableCourses.entries
          .where((e) => e.value.languageCode == targetLang)
          .map((e) => e.key)
          .toList();
      if (derived.isNotEmpty) return derived;
    }
    return [];
  }

  /// Courses NOT yet selected by the user.
  List<LanguageCourse> get availableNewCourses {
    final selected = selectedCourseIds.toSet();
    return availableCourses.entries
        .where((e) => !selected.contains(e.key))
        .map((e) => e.value)
        .toList()
      ..sort((a, b) {
        final nameCmp = a.languageName.compareTo(b.languageName);
        if (nameCmp != 0) return nameCmp;
        return a.level.compareTo(b.level);
      });
  }

  /// Selected courses as LanguageCourse objects, sorted alphabetically.
  List<LanguageCourse> get selectedCourses {
    return selectedCourseIds
        .where((id) => availableCourses.containsKey(id))
        .map((id) => availableCourses[id]!)
        .toList()
      ..sort((a, b) {
        final nameCmp = a.languageName.compareTo(b.languageName);
        if (nameCmp != 0) return nameCmp;
        return a.level.compareTo(b.level);
      });
  }

  Future<void> addCourse(String courseId) async {
    if (!availableCourses.containsKey(courseId)) return;
    if (_userData == null) return;
    final current = List<String>.from(selectedCourseIds);
    if (current.contains(courseId)) return;
    current.add(courseId);

    final uname = _userData!.uName;
    if (uname.isNotEmpty) {
      final userData = await _loadSafe(uname);
      if (userData == null) return;
      final updated = userData.copyWith(selectedCourses: current);
      await _saveSafe(uname, updated);
      await _loadUserData(uname);
      notifyListeners();
    }
  }

  /// Entfernt einen Kurs aus den gewählten Kursen inkl. zugehörigem
  /// Lernfortschritt.
  ///
  /// Der Wortschatz wird sprachweit verwaltet (A1–C2 teilen sich dieselben
  /// Wörter). Deshalb wird der Vokabel-Fortschritt einer Sprache nur gelöscht,
  /// wenn dies der letzte gewählte Kurs dieser Sprache ist; sonst bliebe der
  /// Fortschritt der verbleibenden Kurse unbrauchbar. Das Level-Progress des
  /// entfernten Kurses wird in jedem Fall zurückgesetzt.
  Future<void> removeCourse(String courseId) async {
    final course = availableCourses[courseId];
    if (course == null) return;
    if (_userData == null) return;
    final current = List<String>.from(selectedCourseIds);
    if (!current.contains(courseId)) return;

    current.remove(courseId);

    final uname = _userData!.uName;
    if (uname.isEmpty) return;

    final userData = await _loadSafe(uname);
    if (userData == null) return;

    // Level-Fortschritt des entfernten Kurses zurücksetzen.
    final progress = Map<String, int>.from(userData.progress);
    progress[course.level] = 0;

    // Vokabeln nur löschen, wenn kein weiterer Kurs derselben Sprache bleibt.
    final hasSameLangRemaining = current.any((id) =>
        availableCourses[id]?.languageCode == course.languageCode);
    final targetLang = userData.mLang == 'de' ? 'en' : 'de';
    final clearVocab = !hasSameLangRemaining &&
        course.languageCode == targetLang;

    final updated = userData.copyWith(
      selectedCourses: current,
      progress: progress,
      vocab: clearVocab ? const {} : userData.vocab,
    );
    await _saveSafe(uname, updated);
    await _loadUserData(uname);
    notifyListeners();
  }

  /// Prüft, ob für [course] Kurs-Inhalte (Wörter/Grammatik) verfügbar sind.
  /// Momentan nur A1; wird aktiv für alle Levels, sobald die Daten sortiert sind.
  bool courseHasContent(LanguageCourse course) {
    return activeCourseLevels.contains(course.level);
  }
}
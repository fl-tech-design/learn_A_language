import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/file_service.dart';
import 'user_manager.dart';
import 'vocab_manager.dart';

/// User state – manages login, registration, courses, and user data.
/// Extracted from the former God Object AppState (Commit C).
/// DataState (data/locale/colors) and NavigationState (wordMode/stats)
/// were extracted in Commits A and B.
class UserState extends ChangeNotifier {
  // User data
  UserData? _userData;

  // ── Getters ────────────────────────────────────────────────────
  UserData? get userData => _userData;

  // ── Login / User management ───────────────────────────────────
  Future<void> login(String username) async {
    await UserManager.changeLoginState(true);
    await UserManager.setLoggedUname(username);
    await _loadUserData(username);

    final langDict = _userData?.language ?? {};
    await VocabManager.initVocabForUser(username, langDict);
    await VocabManager.migrateVocabForUser(username);

    await _loadUserData(username);
    await _autoSelectCourses(username);
    notifyListeners();
  }

  /// Creates a brand new user and logs them in.
  Future<String?> registerUser(String username, String mLang) async {
    final result = await UserManager.createUserFile(username, mLang, {});
    if (!result.contains('erfolgreich')) {
      return result;
    }

    await UserManager.addNewUserToList(username);
    await UserManager.changeLoginState(true);
    await UserManager.setLoggedUname(username);

    final targetLang = mLang == 'de' ? 'en' : 'de';
    final langDict = await VocabManager.loadLanguageDictFromDir(targetLang);
    await VocabManager.initVocabForUser(username, langDict);
    await VocabManager.migrateVocabForUser(username);

    await _loadUserData(username);
    notifyListeners();
    return null;
  }

  Future<void> _loadUserData(String username) async {
    final raw =
        await FileService.loadJson('data_app/files_user/data_$username.json');
    if (raw.isNotEmpty) {
      _userData = UserData.fromJson(raw);
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

    final userData = await UserManager.loadUserdata(username);
    userData['selected_courses'] = derived;
    await UserManager.saveUserdata(username, userData);
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
      final userData = await UserManager.loadUserdata(uname);
      userData['selected_courses'] = current;
      await UserManager.saveUserdata(uname, userData);
      await _loadUserData(uname);
      notifyListeners();
    }
  }
}
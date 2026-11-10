import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/file_service.dart';
import 'user_manager.dart';
import 'vocab_manager.dart';
import 'vocab_queries.dart';

/// Central app state – single ChangeNotifier for the entire application.
/// Replaces MainApp attributes and ScrManager.
class AppState extends ChangeNotifier {
  // ── Data loaded from JSON ──────────────────────────────────────
  Map<String, dynamic> _baseData = {};
  Map<String, dynamic> _baseTxtRaw = {};
  Map<String, dynamic> _appDataRaw = {};
  Map<String, dynamic> _appTxtRaw = {};

  String _currLang = 'de';
  Map<String, dynamic> _baseTxt = {};
  Map<String, dynamic> _appTxt = {};
  AppData _appData = AppData();

  // Colors from base_data.json (fallback)
  List<double> _color1 = [12 / 255, 12 / 255, 12 / 255, 1];
  List<double> _color2 = [12 / 255, 12 / 255, 200 / 255, 1];
  List<double> _color3 = [75 / 255, 75 / 255, 75 / 255, 1];

  // User data
  UserData? _userData;

  // Navigation & lifecycle
  bool _loginChecked = false;
  String _wordMode = 'new';
  final List<String> _screenHistory = [];

  // ── Getters ────────────────────────────────────────────────────
  String get currLang => _currLang;
  Map<String, dynamic> get baseTxt => _baseTxt;
  Map<String, dynamic> get appTxt => _appTxt;
  AppData get appData => _appData;
  UserData? get userData => _userData;
  bool get loginChecked => _loginChecked;
  String get wordMode => _wordMode;
  String get loggedUName => _appData.loggedUName;
  List<double> get color1 => _color1;
  List<double> get color2 => _color2;
  List<double> get color3 => _color3;

  // ── Initialization ─────────────────────────────────────────────
  Future<void> initialize() async {
    await FileService.initialize();
    await loadAppData();
  }

  Future<void> loadAppData() async {
    _baseData = await FileService.loadJson('data_base/base_data.json');
    _baseTxtRaw = await FileService.loadJson('data_base/base_txt.json');
    _appDataRaw = await FileService.loadJson('data_app/app_data.json');
    _appTxtRaw = await FileService.loadJson('data_app/app_txt.json');

    _currLang = _baseData['curr_lang']?.toString() ?? 'de';
    _baseTxt = (_baseTxtRaw[_currLang] as Map<String, dynamic>?) ??
        (_baseTxtRaw['de'] as Map<String, dynamic>?) ??
        {};
    _appTxt = (_appTxtRaw[_currLang] as Map<String, dynamic>?) ??
        (_appTxtRaw['de'] as Map<String, dynamic>?) ??
        {};
    _appData = AppData.fromJson(_appDataRaw);

    final colors = _baseData['colors'] as Map<String, dynamic>?;
    if (colors != null) {
      _color1 = _parseColor(colors['color1']);
      _color2 = _parseColor(colors['color2']);
      _color3 = _parseColor(colors['color3']);
    }

    notifyListeners();
  }

  List<double> _parseColor(dynamic raw) {
    if (raw is List) {
      return raw.map<double>((c) => (c as num).toDouble() / 255.0).toList();
    }
    return [1, 1, 1, 1];
  }

  // ── Language ──────────────────────────────────────────────────
  Future<void> changeLanguage(String newLanguage) async {
    final norm = newLanguage.trim().toLowerCase();
    const mapping = {
      'deutsch': 'de', 'englisch': 'en',
      'german': 'de', 'english': 'en',
    };
    final langCode = mapping[norm];
    if (langCode == null) return;

    await FileService.updateJsonKey(
        'data_base/base_data.json', 'curr_lang', langCode);
    await loadAppData();
  }

  // ── Login / User management ───────────────────────────────────
  bool get needsUserCheck => !_loginChecked;

  bool shouldShowLogin() {
    _loginChecked = true;
    final users = _appData.registeredUser;
    if (users.isEmpty) return false; // → create user
    if (!_appData.stayLoggedIn) return true; // → login
    return false;
  }

  bool get hasUsers => _appData.registeredUser.isNotEmpty;

  Future<void> login(String username) async {
    await UserManager.changeLoginState(true);
    await UserManager.setLoggedUname(username);
    await _loadUserData(username);

    final langDict = _userData?.language ?? {};
    await VocabManager.initVocabForUser(username, langDict);
    await VocabManager.migrateVocabForUser(username);

    await loadAppData();
    await _loadUserData(username);
    notifyListeners();
  }

  Future<void> _loadUserData(String username) async {
    final raw = await FileService.loadJson(
        'data_app/files_user/data_$username.json');
    if (raw.isNotEmpty) {
      _userData = UserData.fromJson(raw);
    }
  }

  Future<void> refreshUserData() async {
    if (_appData.loggedUName.isNotEmpty) {
      await _loadUserData(_appData.loggedUName);
      notifyListeners();
    }
  }

  void setWordMode(String mode) {
    _wordMode = mode;
    notifyListeners();
  }

  // ── Screen History (replaces scr_manager navigation) ──────────
  void pushScreen(String screenName) {
    _screenHistory.add(screenName);
  }

  String? popScreen() {
    if (_screenHistory.isNotEmpty) _screenHistory.removeLast();
    return _screenHistory.isNotEmpty ? _screenHistory.last : null;
  }

  void clearHistoryToStart() => _screenHistory.clear();
}
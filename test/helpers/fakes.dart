import 'package:learn_a_language/managers/user_manager.dart';
import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/services/file_service.dart';

/// In-Memory [FileService]-Fake.
///
/// Konfigurierbar über:
/// - [store]: JSON-Daten pro relativem Pfad (wird von saveJson befüllt)
/// - [languageDicts]: Rückgaben für [loadLanguageDictFromDir]
/// - [bundled]: Rückgabe für [loadBundledJson]
/// - [appDirValue] / [appDirThrows]: Verhalten von [appDir]
class FakeFileService implements FileService {
  final Map<String, Map<String, dynamic>> store;
  final Map<String, Map<String, dynamic>> languageDicts;
  final String appDirValue;
  final bool appDirThrows;

  /// Pfade, bei denen [loadJson] eine [PersistenceException] wirft (simuliert
  /// korrupte/unlesbare Dateien) – additiv, Default = kein Fehlerverhalten.
  final Set<String> corruptPaths;

  /// Pfade, bei denen [saveJson] eine [PersistenceException] wirft
  /// (simulierter Schreibfehler) – additiv, Default = kein Fehlerverhalten.
  final Set<String> failSavePaths;

  /// Zuletzt per [loadBundledJson] ausgelieferte Daten.
  Map<String, dynamic> bundled;

  int initializeCount = 0;
  int bundledLoadCount = 0;

  FakeFileService({
    Map<String, Map<String, dynamic>>? store,
    Map<String, Map<String, dynamic>>? languageDicts,
    this.bundled = const {},
    this.appDirValue = '',
    this.appDirThrows = false,
    this.corruptPaths = const {},
    this.failSavePaths = const {},
  })  : store = store ?? {},
        languageDicts = languageDicts ?? {};

  @override
  Future<String> get appDir async {
    if (appDirThrows) throw StateError('appDir nicht verfügbar');
    return appDirValue;
  }

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<Map<String, dynamic>> loadJson(String relativePath) async {
    if (corruptPaths.contains(relativePath)) {
      throw PersistenceException(
          relativePath, StateError('simulierter Korruptions-Fehler'));
    }
    return store[relativePath] ?? {};
  }

  @override
  Future<void> saveJson(
      String relativePath, Map<String, dynamic> data) async {
    if (failSavePaths.contains(relativePath)) {
      throw PersistenceException(
          relativePath, StateError('simulierter Schreibfehler'));
    }
    store[relativePath] = data;
  }

  @override
  Future<void> updateJsonKey(
      String relativePath, String key, Object? value) async {
    final data = Map<String, dynamic>.of(store[relativePath] ?? {});
    data[key] = value;
    store[relativePath] = data;
  }

  @override
  Future<Map<String, dynamic>> loadBundledJson(String assetPath) async {
    bundledLoadCount++;
    return bundled;
  }

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(
      String langCode) async {
    return languageDicts[langCode] ?? {};
  }
}

/// In-Memory [UserManager]-Fake: speichert UserData im Speicher und zählt
/// saveUserdata-Aufrufe.
class FakeUserManager implements UserManager {
  final Map<String, UserData> _users = {};
  final List<String> _registeredUsers = [];

  /// Benutzernamen, für die [loadUserdata] eine [PersistenceException] wirft
  /// (simuliert korrupte User-Datei) – additiv, Default = kein Fehlerverhalten.
  final Set<String> unreadableUsers;

  /// Benutzernamen, für die [saveUserdata] eine [PersistenceException] wirft
  /// (simulierter Schreibfehler) – additiv, Default = kein Fehlerverhalten.
  final Set<String> failSaveUsers;

  int saveCount = 0;
  bool userLoggedIn = false;
  String loggedUName = '';

  UserData? _lastSaved;

  FakeUserManager(
      {this.unreadableUsers = const {}, this.failSaveUsers = const {}});

  UserData? get lastSaved => _lastSaved;

  /// Seedet einen Benutzer, ohne `saveCount` zu erhöhen.
  void seed(String username, UserData data) {
    _users[username] = data;
    _lastSaved = data;
    if (!_registeredUsers.contains(username)) {
      _registeredUsers.add(username);
    }
  }

  UserData? getUser(String username) => _users[username];

  @override
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict) async {
    if (_users.containsKey(username)) {
      return 'Benutzer $username existiert bereits.';
    }
    final userData = UserData(
      uName: username,
      mLang: mLang,
      progress: const {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
      learnedLanguages: const [],
      language: languageDict,
      vocab: const {},
    );
    _users[username] = userData;
    _lastSaved = userData;
    return 'Benutzer $username wurde erfolgreich erstellt.';
  }

  @override
  Future<UserData?> loadUserdata(String username) async {
    if (unreadableUsers.contains(username)) {
      throw PersistenceException(
          'data_app/files_user/data_$username.json',
          StateError('simulierte korrupte User-Datei'));
    }
    return _users[username];
  }

  @override
  Future<void> saveUserdata(String username, UserData data) async {
    saveCount++;
    if (failSaveUsers.contains(username)) {
      throw PersistenceException(
          'data_app/files_user/data_$username.json',
          StateError('simulierter Schreibfehler'));
    }
    _users[username] = data;
    _lastSaved = data;
  }

  @override
  Future<void> addNewUserToList(String username) async {
    if (!_registeredUsers.contains(username)) {
      _registeredUsers.add(username);
    }
  }

  @override
  Future<String> deleteUser(String username) async {
    _users.remove(username);
    _registeredUsers.remove(username);
    if (loggedUName == username) {
      loggedUName = '';
      userLoggedIn = false;
    }
    return "Benutzer '$username' wurde gelöscht.";
  }

  @override
  Future<void> changeLoginState({required bool newState}) async {
    userLoggedIn = newState;
  }

  @override
  Future<void> setLoggedUname(String value) async {
    loggedUName = value;
  }
}

/// In-Memory [VocabManager]-Fake, der Aufrufe zählt.
class FakeVocabManager implements VocabManager {
  final Map<String, Map<String, dynamic>> languageDicts;
  final List<LangDictWord> extractedWords;

  int initCount = 0;
  int migrateCount = 0;
  int loadDictCount = 0;

  FakeVocabManager({
    this.languageDicts = const {},
    this.extractedWords = const [],
  });

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(String langCode) async {
    loadDictCount++;
    return languageDicts[langCode] ?? {};
  }

  @override
  List<LangDictWord> extractAllWordsFromLanguageDict(
          Map<String, dynamic> languageDict) =>
      extractedWords;

  @override
  Future<void> initVocabForUser(
      String username, Map<String, dynamic> languageDict) async {
    initCount++;
  }

  @override
  Future<void> migrateVocabForUser(String username) async {
    migrateCount++;
  }
}

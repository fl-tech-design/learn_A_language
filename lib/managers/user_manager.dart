import 'dart:convert' show jsonDecode;
import 'dart:developer' show log;
import 'dart:io';

import '../models/app_models.dart';
import '../services/file_service.dart';
import '../services/storage_error_bus.dart';

/// Pure user management logic — interface extracted from the former static
/// UserManager class (point2, Commit A).
abstract class UserManager {
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict);
  Future<UserData?> loadUserdata(String username);
  Future<void> saveUserdata(String username, UserData data);
  Future<void> addNewUserToList(String username);
  Future<String> deleteUser(String username);
  Future<void> changeLoginState({required bool newState});
  Future<void> setLoggedUname(String loggedUname);
}

/// Concrete implementation backed by [FileService].
class UserManagerImpl implements UserManager {
  final FileService _fileService;

  UserManagerImpl(this._fileService);

  static const _appDataPath = 'data_app/app_data.json';

  /// Erlaubte Zeichen für Benutzernamen: Buchstaben, Ziffern, `_`, `-`.
  /// Benutzernamen gehen direkt in Dateipfade ein – deshalb die Whitelist.
  static final RegExp _userNamePattern = RegExp(r'^[A-Za-z0-9_-]+$');

  static const _invalidNameMessage =
      'Ungültiger Benutzername. Erlaubt sind Buchstaben, Ziffern, '
      'Unterstrich (_) und Bindestrich (-).';

  /// ZENTRALE Username-Validierung: Alle Pfad-relevanten Operationen laufen
  /// über diese eine Stelle. Geliefert wird der getrimmte Name, wenn er der
  /// Whitelist entspricht, sonst `null`. Damit kann ein Benutzername niemals
  /// `..`, `/`, `\`, Laufwerksbuchstaben oder andere Pfadprimitive enthalten.
  String? _safeUsername(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty || !_userNamePattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  @override
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict) async {
    final normalized = _safeUsername(username);
    if (normalized == null) {
      return _invalidNameMessage;
    }

    final filePath = 'data_app/files_user/data_$normalized.json';
    Map<String, dynamic> existing;
    try {
      existing = await _fileService.loadJson(filePath);
    } on PersistenceException catch (e) {
      log('createUserFile: Bestandsdaten für $normalized korrupt ($e)');
      return 'Benutzerdaten für $normalized sind beschädigt und konnten '
          'nicht gelesen werden.';
    }
    if (existing.isNotEmpty) {
      return 'Benutzer $normalized existiert bereits.';
    }

    final userData = UserData(
      uName: normalized,
      mLang: mLang,
      progress: const {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
      learnedLanguages: const [],
      language: languageDict,
      vocab: const {},
    );

    await _fileService.saveJson(filePath, userData.toJson());
    return 'Benutzer $normalized wurde erfolgreich erstellt.';
  }

  @override
  Future<UserData?> loadUserdata(String username) async {
    final name = _safeUsername(username);
    if (name == null) {
      log('loadUserdata: ungültiger Benutzername "$username" – kein Dateizugriff');
      return null;
    }
    final raw =
        await _fileService.loadJson('data_app/files_user/data_$name.json');
    if (raw.isEmpty) return null;
    return UserData.fromJson(raw);
  }

  @override
  Future<void> saveUserdata(String username, UserData data) async {
    final name = _safeUsername(username);
    if (name == null) {
      throw PathRejectedException('data_app/files_user/data_$username.json',
          StateError('Ungültiger Benutzername "$username"'));
    }
    await _fileService.saveJson(
        'data_app/files_user/data_$name.json', data.toJson());
  }

  @override
  Future<void> addNewUserToList(String username) async {
    final name = _safeUsername(username);
    if (name == null) {
      throw PathRejectedException('data_app/app_data.json',
          StateError('Ungültiger Benutzername "$username"'));
    }
    final appData = await _readAppData();
    final users = List<String>.from(appData.registeredUser);
    if (!users.contains(name)) {
      users.add(name);
    }
    await _saveAppDataSilently(
        appData.copyWith(registeredUser: users).toJson(), 'addNewUserToList');
  }

  @override
  Future<String> deleteUser(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return 'Kein Benutzername angegeben.';
    }

    final appData = await _readAppData();
    final users = List<String>.from(appData.registeredUser);

    if (!users.contains(trimmed)) {
      return "Benutzer '$trimmed' ist nicht registriert.";
    }

    users.remove(trimmed);

    var loggedUName = appData.loggedUName;
    var userLoggedIn = appData.userLoggedIn;
    if (loggedUName == trimmed) {
      loggedUName = '';
      userLoggedIn = false;
    }

    final saveFailed = await _saveAppDataSilently(
        appData
            .copyWith(
                registeredUser: users,
                loggedUName: loggedUName,
                userLoggedIn: userLoggedIn)
            .toJson(),
        'deleteUser');
    if (saveFailed) {
      return 'Benutzer konnte nicht gelöscht werden (Speichern fehlgeschlagen).';
    }

    // Datei(en) über den FileService löschen: Die zentrale Containment-Prüfung
    // gilt auch fürs Löschen. So bleiben Legacy-Profile (Namen ausserhalb der
    // Whitelist, z. B. Umlaute/Leerzeichen) sicher entfernbar, während
    // manipulierte Namen (Traversal) NIE Dateien ausserhalb des files_user-
    // Ordners löschen können. Ablehnungen werden gemeldet, nie verschwiegen.
    String? fileHint;
    for (final suffix in const ['.json', '.json.bak']) {
      final rel = 'data_app/files_user/data_$trimmed$suffix';
      try {
        await _fileService.deleteFile(rel);
      } on PathRejectedException catch (e) {
        log('deleteUser: $rel sicher nicht löschbar ($e)');
        fileHint ??=
            'Datei konnte nicht gelöscht werden ($rel – Pfad-Sicherheitsprüfung).';
      } on PersistenceException catch (e) {
        log('deleteUser: $rel konnte nicht gelöscht werden ($e)');
        fileHint ??= 'Datei konnte nicht gelöscht werden ($rel).';
      }
    }
    if (fileHint != null) {
      return 'Benutzer aus der Liste entfernt, $fileHint';
    }
    return "Benutzer '$trimmed' wurde gelöscht.";
  }

  @override
  Future<void> changeLoginState({required bool newState}) async {
    final appData = await _readAppData();
    await _saveAppDataSilently(
        appData.copyWith(userLoggedIn: newState).toJson(), 'changeLoginState');
  }

  @override
  Future<void> setLoggedUname(String loggedUname) async {
    final name = _safeUsername(loggedUname);
    if (name == null) {
      throw PathRejectedException('data_app/app_data.json',
          StateError('Ungültiger Benutzername "$loggedUname"'));
    }
    final appData = await _readAppData();
    await _saveAppDataSilently(
        appData.copyWith(loggedUName: name).toJson(), 'setLoggedUname');
  }

  /// Liest `app_data.json` robust: Ist die Datei beschädigt (auch `.bak`),
  /// wird die Benutzerliste aus den vorhandenen `data_*.json`-Dateien
  /// rekonstruiert – es wird NIE ein Default-`AppData` zurückgegeben, das
  /// beim nächsten Write registrierte Profile verschwinden ließe.
  Future<AppData> _readAppData() async {
    try {
      final raw = await _fileService.loadJson(_appDataPath);
      return AppData.fromJson(raw);
    } on PersistenceException catch (e) {
      log('user_manager: app_data unlesbar – rekonstruiere Benutzerliste ($e)');
      try {
        final recovered = await recoverAppData(_fileService);
        StorageErrorBus.instance.report(StorageErrorKind.appDataRecovered);
        return recovered;
      } catch (e2) {
        // Extremfall: auch das Verzeichnis ist nicht lesbar. Dann schlagen
        // Writes ohnehin fehl – eine Default-AppData wird nicht geschrieben.
        log('user_manager: Rekonstruktion fehlgeschlagen ($e2)');
        StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
        return AppData();
      }
    }
  }

  /// Speichert `app_data` und schluckt Fehler NICHT: sie werden geloggt und
  /// über den [StorageErrorBus] sichtbar gemacht; zurückgegeben wird, ob der
  /// Write fehlschlug (Aufrufer können dann abbrechen statt blind weiterzumachen).
  Future<bool> _saveAppDataSilently(Map<String, dynamic> json, String from) async {
    try {
      await _fileService.saveJson(_appDataPath, json);
      return false;
    } on PersistenceException catch (e) {
      log('user_manager: app_data-Save aus $from fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
      return true;
    }
  }
}

/// Rekonstruiert die registrierte Benutzerliste aus den vorhandenen
/// User-Dateien (`data_app/files_user/data_*.json`).
///
/// Es werden nur echte User-Dateien berücksichtigt – `.bak`/`.tmp`-Artefakte
/// und Dateien ohne gültiges `u_name`-Feld werden ignoriert.
Future<AppData> recoverAppData(FileService fs) async {
  final dir = await fs.appDir;
  final filesDir = Directory('$dir/data_app/files_user');
  final users = <String>[];
  if (await filesDir.exists()) {
    await for (final entity in filesDir.list()) {
      if (entity is! File) continue;
      final fname = entity.uri.pathSegments.last;
      if (!fname.startsWith('data_') || !fname.endsWith('.json')) continue;
      if (fname.endsWith('.json.bak') || fname.endsWith('.tmp')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map<String, dynamic>) {
          final uname = decoded['u_name']?.toString().trim() ?? '';
          if (uname.isNotEmpty && !users.contains(uname)) {
            users.add(uname);
          }
        }
      } catch (e) {
        log('recoverAppData: $fname übersprungen ($e)');
      }
    }
  }
  users.sort();
  return AppData(registeredUser: users);
}
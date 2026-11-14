import 'dart:io';

import '../models/app_models.dart';
import '../services/file_service.dart';

/// Pure user management logic — interface extracted from the former static
/// UserManager class (point2, Commit A).
abstract class UserManager {
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict);
  Future<UserData?> loadUserdata(String username);
  Future<void> saveUserdata(String username, UserData data);
  Future<void> addNewUserToList(String username);
  Future<String> deleteUser(String username);
  Future<void> changeLoginState(bool newState);
  Future<void> setLoggedUname(String loggedUname);
}

/// Concrete implementation backed by [FileService].
class UserManagerImpl implements UserManager {
  final FileService _fileService;

  UserManagerImpl(this._fileService);

  static const _appDataPath = 'data_app/app_data.json';

  @override
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict) async {
    final filePath = 'data_app/files_user/data_$username.json';
    final existing = await _fileService.loadJson(filePath);
    if (existing.isNotEmpty) {
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

    await _fileService.saveJson(filePath, userData.toJson());
    return 'Benutzer $username wurde erfolgreich erstellt.';
  }

  @override
  Future<UserData?> loadUserdata(String username) async {
    final raw = await _fileService.loadJson(
        'data_app/files_user/data_$username.json');
    if (raw.isEmpty) return null;
    return UserData.fromJson(raw);
  }

  @override
  Future<void> saveUserdata(String username, UserData data) async {
    await _fileService.saveJson(
        'data_app/files_user/data_$username.json', data.toJson());
  }

  @override
  Future<void> addNewUserToList(String username) async {
    final data = await _fileService.loadJson(_appDataPath);
    final appData = AppData.fromJson(data);
    final users = List<String>.from(appData.registeredUser);
    if (!users.contains(username)) {
      users.add(username);
    }
    await _fileService.saveJson(
        _appDataPath, appData.copyWith(registeredUser: users).toJson());
  }

  @override
  Future<String> deleteUser(String username) async {
    username = (username).trim();
    if (username.isEmpty) {
      return 'Kein Benutzername angegeben.';
    }

    final data = await _fileService.loadJson(_appDataPath);
    final appData = AppData.fromJson(data);
    final users = List<String>.from(appData.registeredUser);

    if (!users.contains(username)) {
      return "Benutzer '$username' ist nicht registriert.";
    }

    users.remove(username);

    var loggedUName = appData.loggedUName;
    var userLoggedIn = appData.userLoggedIn;
    if (loggedUName == username) {
      loggedUName = '';
      userLoggedIn = false;
    }

    await _fileService.saveJson(
        _appDataPath,
        appData
            .copyWith(
                registeredUser: users,
                loggedUName: loggedUName,
                userLoggedIn: userLoggedIn)
            .toJson());

    try {
      final dir = await _fileService.appDir;
      final file = File('$dir/data_app/files_user/data_$username.json');
      if (await file.exists()) {
        await file.delete();
      }
      return "Benutzer '$username' wurde gelöscht.";
    } catch (_) {
      return 'Benutzer aus der Liste entfernt, Datei konnte nicht gelöscht werden.';
    }
  }

  @override
  Future<void> changeLoginState(bool newState) async {
    final data = await _fileService.loadJson(_appDataPath);
    final appData = AppData.fromJson(data);
    await _fileService.saveJson(
        _appDataPath, appData.copyWith(userLoggedIn: newState).toJson());
  }

  @override
  Future<void> setLoggedUname(String loggedUname) async {
    final data = await _fileService.loadJson(_appDataPath);
    final appData = AppData.fromJson(data);
    await _fileService.saveJson(
        _appDataPath, appData.copyWith(loggedUName: loggedUname).toJson());
  }
}
import 'dart:io';

import '../services/file_service.dart';

/// Pure user management logic — interface extracted from the former static
/// UserManager class (point2, Commit A).
abstract class UserManager {
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict);
  Future<Map<String, dynamic>> loadUserdata(String username);
  Future<void> saveUserdata(String username, Map<String, dynamic> data);
  Future<void> addNewUserToList(String username);
  Future<String> deleteUser(String username);
  Future<void> changeLoginState(bool newState);
  Future<void> setLoggedUname(String loggedUname);
}

/// Concrete implementation backed by [FileService].
class UserManagerImpl implements UserManager {
  final FileService _fileService;

  UserManagerImpl(this._fileService);

  @override
  Future<String> createUserFile(
      String username, String mLang, Map<String, dynamic> languageDict) async {
    final filePath = 'data_app/files_user/data_$username.json';
    final existing = await _fileService.loadJson(filePath);
    if (existing.isNotEmpty) {
      return 'Benutzer $username existiert bereits.';
    }

    final userData = {
      'u_name': username,
      'm_lang': mLang,
      'progress': {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
      'learned_languages': <String>[],
      'language': languageDict,
      'vocab': <String, dynamic>{},
    };

    await _fileService.saveJson(filePath, userData);
    return 'Benutzer $username wurde erfolgreich erstellt.';
  }

  @override
  Future<Map<String, dynamic>> loadUserdata(String username) async {
    return _fileService.loadJson('data_app/files_user/data_$username.json');
  }

  @override
  Future<void> saveUserdata(
      String username, Map<String, dynamic> data) async {
    await _fileService.saveJson(
        'data_app/files_user/data_$username.json', data);
  }

  @override
  Future<void> addNewUserToList(String username) async {
    final data = await _fileService.loadJson('data_app/app_data.json');
    final users = List<String>.from(data['registered_user'] ?? []);
    if (!users.contains(username)) {
      users.add(username);
      data['registered_user'] = users;
      await _fileService.saveJson('data_app/app_data.json', data);
    }
  }

  @override
  Future<String> deleteUser(String username) async {
    username = (username).trim();
    if (username.isEmpty) {
      return 'Kein Benutzername angegeben.';
    }

    final data = await _fileService.loadJson('data_app/app_data.json');
    final users = List<String>.from(data['registered_user'] ?? []);

    if (!users.contains(username)) {
      return "Benutzer '$username' ist nicht registriert.";
    }

    users.remove(username);
    data['registered_user'] = users;

    if (data['logged_u_name'] == username) {
      data['logged_u_name'] = '';
      data['user_logged_in'] = false;
    }
    await _fileService.saveJson('data_app/app_data.json', data);

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
    await _fileService.updateJsonKey(
        'data_app/app_data.json', 'user_logged_in', newState);
  }

  @override
  Future<void> setLoggedUname(String loggedUname) async {
    await _fileService.updateJsonKey(
        'data_app/app_data.json', 'logged_u_name', loggedUname);
  }
}
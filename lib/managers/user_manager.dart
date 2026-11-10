import 'dart:io';

import '../services/file_service.dart';

/// Pure static user management logic – 1:1 from user_manager.py.
class UserManager {
  UserManager._();

  /// Creates a new user file with initialized structure.
  static Future<String> createUserFile(
    String username,
    String mLang,
    Map<String, dynamic> languageDict,
  ) async {
    final filePath = 'data_app/files_user/data_$username.json';
    final existing = await FileService.loadJson(filePath);
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

    await FileService.saveJson(filePath, userData);
    return 'Benutzer $username wurde erfolgreich erstellt.';
  }

  /// Loads user data from JSON.
  static Future<Map<String, dynamic>> loadUserdata(String username) async {
    return FileService.loadJson('data_app/files_user/data_$username.json');
  }

  /// Saves complete user data back.
  static Future<void> saveUserdata(
    String username,
    Map<String, dynamic> data,
  ) async {
    await FileService.saveJson(
      'data_app/files_user/data_$username.json',
      data,
    );
  }

  /// Adds a username to the registered_user list in app_data.json.
  static Future<void> addNewUserToList(String username) async {
    final data = await FileService.loadJson('data_app/app_data.json');
    final users = List<String>.from(data['registered_user'] ?? []);
    if (!users.contains(username)) {
      users.add(username);
      data['registered_user'] = users;
      await FileService.saveJson('data_app/app_data.json', data);
    }
  }

  /// Deletes a user completely.
  static Future<String> deleteUser(String username) async {
    username = (username).trim();
    if (username.isEmpty) {
      return 'Kein Benutzername angegeben.';
    }

    final data = await FileService.loadJson('data_app/app_data.json');
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
    await FileService.saveJson('data_app/app_data.json', data);

    // Delete user file
    try {
      final dir = await FileService.appDir;
      final file = File('$dir/data_app/files_user/data_$username.json');
      if (await file.exists()) {
        await file.delete();
      }
      return "Benutzer '$username' wurde gelöscht.";
    } catch (_) {
      return 'Benutzer aus der Liste entfernt, Datei konnte nicht gelöscht werden.';
    }
  }

  /// Changes login state in app_data.json.
  static Future<void> changeLoginState(bool newState) async {
    await FileService.updateJsonKey(
        'data_app/app_data.json', 'user_logged_in', newState);
  }

  /// Sets the currently logged-in username.
  static Future<void> setLoggedUname(String loggedUname) async {
    await FileService.updateJsonKey(
        'data_app/app_data.json', 'logged_u_name', loggedUname);
  }
}

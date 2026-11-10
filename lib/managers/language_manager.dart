import '../services/file_service.dart';

/// Simple language file loader – 1:1 from language_manager.py.
class LanguageManager {
  LanguageManager._();

  /// Loads a language JSON file.
  /// In Flutter, language texts come from base_txt.json / app_txt.json
  /// loaded by AppState, so this manager is kept minimal.
  static Future<Map<String, dynamic>> loadLanguageFile(
    String currLanguage,
  ) async {
    return FileService.loadJson('data_$currLanguage.json');
  }
}

/// Small helper – 1:1 from contr_str.py.
String letUppercaseFirst(String str) {
  if (str.isEmpty) return str;
  return str[0].toUpperCase() + str.substring(1);
}
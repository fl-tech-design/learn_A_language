import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Provides JSON file read/write with automatic first-launch asset copy.
/// Mirrors data_manager.py behavior.
class FileService {
  static String? _appDir;

  /// Returns the writable app documents directory (lazy init).
  static Future<String> get appDir async {
    if (_appDir != null) return _appDir!;
    final dir = await getApplicationDocumentsDirectory();
    _appDir = dir.path;
    return _appDir!;
  }

  /// Copies all bundled assets to the app documents dir on first launch.
  static Future<void> initialize() async {
    final dir = await appDir;
    final flagFile = File('$dir/.initialized');
    if (await flagFile.exists()) return;

    await _copyAssetDir('assets/data_base', '$dir/data_base');
    await _copyAssetDir('assets/data_app', '$dir/data_app');
    await _copyAssetDir('assets/language_dict/de', '$dir/language_dict/de');
    await _copyAssetDir('assets/language_dict/en', '$dir/language_dict/en');
    await _copyAssetDir('assets/game_assets', '$dir/assets');

    // Ensure files_user directory exists
    final userDir = Directory('$dir/data_app/files_user');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
      // Copy existing user files from bundle
      await _copyAssetDir(
        'assets/data_app/files_user',
        '$dir/data_app/files_user',
      );
    }

    await flagFile.create();
  }

  static Future<void> _copyAssetDir(String assetPath, String targetPath) async {
    final dir = Directory(targetPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      final manifest =
          await rootBundle.loadString('AssetManifest.json');
      final manifestJson = json.decode(manifest) as Map<String, dynamic>;
      for (final key in manifestJson.keys) {
        if (key.startsWith(assetPath) && key != assetPath) {
          final relative = key.substring(assetPath.length + 1);
          if (relative.isEmpty) continue;
          final targetFile = File('$targetPath/$relative');
          if (!await targetFile.exists()) {
            final bytes = await rootBundle.load(key);
            await targetFile.writeAsBytes(bytes.buffer.asUint8List());
          }
        }
      }
    } catch (_) {
      // AssetManifest not available in debug; skip
    }
  }

  /// Loads a JSON file from the app documents directory.
  static Future<Map<String, dynamic>> loadJson(String relativePath) async {
    try {
      final dir = await appDir;
      final file = File('$dir/$relativePath');
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Saves data as JSON to the app documents directory.
  static Future<void> saveJson(
    String relativePath,
    Map<String, dynamic> data,
  ) async {
    try {
      final dir = await appDir;
      final file = File('$dir/$relativePath');
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(data));
    } catch (_) {
      // silently fail, original also just logs
    }
  }

  /// Updates a single key in a JSON file.
  static Future<void> updateJsonKey(
    String relativePath,
    String key,
    dynamic value,
  ) async {
    final data = await loadJson(relativePath);
    data[key] = value;
    await saveJson(relativePath, data);
  }

  /// Loads a bundled JSON asset (read-only, from assets).
  static Future<Map<String, dynamic>> loadBundledJson(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Merges all single files from language_dict/{langCode}/ into one dict.
  /// Reads from the app documents directory.
  static Future<Map<String, dynamic>> loadLanguageDictFromDir(
    String langCode,
  ) async {
    final dir = await appDir;
    final langDir = Directory('$dir/language_dict/$langCode');
    if (!await langDir.exists()) return {};

    final result = <String, dynamic>{};
    final prefix = '${langCode}_';
    await for (final entity in langDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final fname = entity.uri.pathSegments.last;
        if (fname.startsWith(prefix)) {
          final key = fname.substring(prefix.length, fname.length - 5);
          try {
            final content = await entity.readAsString();
            result[key] = json.decode(content);
          } catch (_) {}
        }
      }
    }
    return result;
  }
}
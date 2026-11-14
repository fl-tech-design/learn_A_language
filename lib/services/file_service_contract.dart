import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Provides JSON file read/write with automatic first-launch asset copy.
/// Interface extracted from the former static FileService class as part of
/// the static-manager decoupling (point2, Commit A).
abstract class FileService {
  Future<String> get appDir;
  Future<void> initialize();
  Future<Map<String, dynamic>> loadJson(String relativePath);
  Future<void> saveJson(String relativePath, Map<String, dynamic> data);
  Future<void> updateJsonKey(
      String relativePath, String key, dynamic value);
  Future<Map<String, dynamic>> loadBundledJson(String assetPath);
  Future<Map<String, dynamic>> loadLanguageDictFromDir(String langCode);
}

/// Concrete implementation backed by the app documents directory.
class FileServiceImpl implements FileService {
  String? _appDir;

  @override
  Future<String> get appDir async {
    if (_appDir != null) return _appDir!;
    final dir = await getApplicationDocumentsDirectory();
    _appDir = dir.path;
    return _appDir!;
  }

  @override
  Future<void> initialize() async {
    final dir = await appDir;
    final flagFile = File('$dir/.initialized');
    if (await flagFile.exists()) return;

    final files = <String>[
      'data_base/base_data.json',
      'data_base/base_txt.json',
      'data_app/app_data.json',
      'data_app/app_txt.json',
      'language_dict/de/de_to_be.json',
      'language_dict/de/de_to_be_allowed_to.json',
      'language_dict/de/de_to_begin.json',
      'language_dict/de/de_to_buy.json',
      'language_dict/de/de_to_can.json',
      'language_dict/de/de_to_close.json',
      'language_dict/de/de_to_come.json',
      'language_dict/de/de_to_drink.json',
      'language_dict/de/de_to_eat.json',
      'language_dict/de/de_to_end.json',
      'language_dict/de/de_to_find.json',
      'language_dict/de/de_to_go.json',
      'language_dict/de/de_to_have.json',
      'language_dict/de/de_to_help.json',
      'language_dict/de/de_to_learn.json',
      'language_dict/de/de_to_like.json',
      'language_dict/de/de_to_live.json',
      'language_dict/de/de_to_make.json',
      'language_dict/de/de_to_must.json',
      'language_dict/de/de_to_need.json',
      'language_dict/de/de_to_open.json',
      'language_dict/de/de_to_read.json',
      'language_dict/de/de_to_see.json',
      'language_dict/de/de_to_sell.json',
      'language_dict/de/de_to_should.json',
      'language_dict/de/de_to_speak.json',
      'language_dict/de/de_to_understand.json',
      'language_dict/de/de_to_want.json',
      'language_dict/de/de_to_write.json',
      'language_dict/de/de_to_work.json',
      'language_dict/en/en_to_be.json',
      'language_dict/en/en_to_be_allowed_to.json',
      'language_dict/en/en_to_begin.json',
      'language_dict/en/en_to_buy.json',
      'language_dict/en/en_to_can.json',
      'language_dict/en/en_to_close.json',
      'language_dict/en/en_to_come.json',
      'language_dict/en/en_to_drink.json',
      'language_dict/en/en_to_eat.json',
      'language_dict/en/en_to_end.json',
      'language_dict/en/en_to_find.json',
      'language_dict/en/en_to_go.json',
      'language_dict/en/en_to_have.json',
      'language_dict/en/en_to_help.json',
      'language_dict/en/en_to_learn.json',
      'language_dict/en/en_to_like.json',
      'language_dict/en/en_to_live.json',
      'language_dict/en/en_to_make.json',
      'language_dict/en/en_to_must.json',
      'language_dict/en/en_to_need.json',
      'language_dict/en/en_to_open.json',
      'language_dict/en/en_to_read.json',
      'language_dict/en/en_to_see.json',
      'language_dict/en/en_to_sell.json',
      'language_dict/en/en_to_should.json',
      'language_dict/en/en_to_speak.json',
      'language_dict/en/en_to_understand.json',
      'language_dict/en/en_to_want.json',
      'language_dict/en/en_to_write.json',
      'language_dict/en/en_to_work.json',
    ];

    for (final rel in files) {
      final assetPath = 'assets/$rel';
      final targetFile = File('$dir/$rel');
      if (await targetFile.exists()) continue;
      try {
        final bytes = await rootBundle.load(assetPath);
        final parent = targetFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        await targetFile.writeAsBytes(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    await flagFile.create();
  }

  @override
  Future<Map<String, dynamic>> loadJson(String relativePath) async {
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

  @override
  Future<void> saveJson(
      String relativePath, Map<String, dynamic> data) async {
    try {
      final dir = await appDir;
      final file = File('$dir/$relativePath');
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(data));
    } catch (_) {}
  }

  @override
  Future<void> updateJsonKey(
      String relativePath, String key, dynamic value) async {
    final data = await loadJson(relativePath);
    data[key] = value;
    await saveJson(relativePath, data);
  }

  @override
  Future<Map<String, dynamic>> loadBundledJson(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(
      String langCode) async {
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

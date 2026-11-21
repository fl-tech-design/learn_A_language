import 'dart:developer' show log;

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/file_service.dart';
import '../services/storage_error_bus.dart';
import 'user_manager.dart' show recoverAppData;

/// Central data & locale state – base/app JSON data and colors.
/// Extracted from AppState to eliminate the God Object anti-pattern.
class DataState extends ChangeNotifier {
  final FileService _fileService;

  DataState(this._fileService);
  // ── Data loaded from JSON ──────────────────────────────────────
  Map<String, dynamic> _baseData = {};
  Map<String, dynamic> _appDataRaw = {};

  String _currLang = 'de';
  AppData _appData = AppData();

  // Colors from base_data.json (fallback)
  List<double> _color1 = [12 / 255, 12 / 255, 12 / 255, 1];
  List<double> _color2 = [12 / 255, 12 / 255, 200 / 255, 1];
  List<double> _color3 = [75 / 255, 75 / 255, 75 / 255, 1];

  // ── Getters ────────────────────────────────────────────────────
  String get currLang => _currLang;

  /// Maps curr_lang to Flutter's Locale. Fallback: en.
  Locale get appLocale => switch (_currLang) {
        'de' => const Locale('de'),
        'en' => const Locale('en'),
        'es' => const Locale('es'),
        'fr' => const Locale('fr'),
        'ru' => const Locale('ru'),
        _    => const Locale('en'),
      };
  AppData get appData => _appData;
  List<double> get color1 => _color1;
  List<double> get color2 => _color2;
  List<double> get color3 => _color3;

  // ── Initialization ─────────────────────────────────────────────
  Future<void> initialize() async {
    await _fileService.initialize();
    await loadAppData();
  }

  Future<void> loadAppData() async {
    try {
      _baseData = await _fileService.loadJson('data_base/base_data.json');
    } on PersistenceException catch (e) {
      // Bundle-Standarddaten sind read-only; {} = Defaults, aber sichtbar.
      log('loadAppData: base_data unlesbar ($e)');
      _baseData = const {};
    }

    try {
      _appDataRaw = await _fileService.loadJson('data_app/app_data.json');
    } on PersistenceException catch (e) {
      log('loadAppData: app_data unlesbar ($e)');
      try {
        final recovered = await recoverAppData(_fileService);
        _appDataRaw = recovered.toJson();
        StorageErrorBus.instance.report(StorageErrorKind.appDataRecovered);
      } catch (e2) {
        log('loadAppData: Rekonstruktion fehlgeschlagen ($e2)');
        StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
        _appDataRaw = const {};
      }
    }

    _currLang = _baseData['curr_lang']?.toString() ?? 'de';
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
      'deutsch': 'de',
      'englisch': 'en',
      'spanisch': 'es',
      'französisch': 'fr',
      'russisch': 'ru',
      'german': 'de',
      'english': 'en',
      'spanish': 'es',
      'french': 'fr',
      'russian': 'ru',
    };
    final langCode = mapping[norm];
    if (langCode == null) return;

    try {
      await _fileService.updateJsonKey(
          'data_base/base_data.json', 'curr_lang', langCode);
    } on PersistenceException catch (e) {
      log('changeLanguage: Speichern fehlgeschlagen ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
    }
    await loadAppData();
  }
}
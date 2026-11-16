import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/file_service.dart';

/// Central data & locale state – base/app JSON data, texts, colors.
/// Extracted from AppState to eliminate the God Object anti-pattern.
class DataState extends ChangeNotifier {
  final FileService _fileService;

  DataState(this._fileService);
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

  // ── Getters ────────────────────────────────────────────────────
  String get currLang => _currLang;
  Map<String, dynamic> get baseTxt => _baseTxt;
  Map<String, dynamic> get appTxt => _appTxt;

  /// Maps curr_lang to Flutter's Locale. Fallback: en.
  Locale get appLocale => switch (_currLang) {
        'de' => const Locale('de'),
        'en' => const Locale('en'),
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
    _baseData = await _fileService.loadJson('data_base/base_data.json');
    _baseTxtRaw = await _fileService.loadJson('data_base/base_txt.json');
    _appDataRaw = await _fileService.loadJson('data_app/app_data.json');
    _appTxtRaw = await _fileService.loadJson('data_app/app_txt.json');

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
      'deutsch': 'de',
      'englisch': 'en',
      'german': 'de',
      'english': 'en',
    };
    final langCode = mapping[norm];
    if (langCode == null) return;

    await _fileService.updateJsonKey(
        'data_base/base_data.json', 'curr_lang', langCode);
    await loadAppData();
  }
}
import 'dart:developer' show log;

import 'app_models.dart' show LanguageCourse;

/// Zentraler, datengetriebener Sprachkatalog (Ticket #52).
///
/// Alle Sprachdaten kommen aus der Bundle-Konfigurationsdatei
/// [languageConfigAsset] (assets/data_app/languages.json). Eine neue Sprache
/// benötigt NUR einen Eintrag in dieser Datei – die Code-Dateien
/// `language_registry.dart` und `file_service.dart` müssen dafür nicht mehr
/// geändert werden.
///
/// Lädt die Datei nicht (fehlt im Bundle, ungültig, Test-Umgebung ohne Assets),
/// bleiben die **eingebetteten Defaults** aktiv – identisch zum Verhalten vor
/// dem Umbau.
///
/// Rollen pro Config-Eintrag:
/// - `ui`:     in [appLanguages] (UI-Sprachwahl/FlagBox; erfordert zusätzlich
///             die jeweilige `app_localizations_<code>.dart`/`.arb`)
/// - `seed`:   in [dictLanguageCodes] (stabiler Kurs-Fallback, First-Run & Tests)
/// - `course`: in [courseCandidateCodes] (Asset-Copy-Liste + Discovery-Filter)
const String languageConfigAsset = 'assets/data_app/languages.json';

/// true, sobald [loadLanguageConfig] erfolgreich eine Config angewendet hat.
bool languageConfigApplied = false;

/// Sprachkonfiguration einer UI-Sprache.
class AppLanguageConfig {
  /// Sprachcode, z. B. `'de'`.
  final String code;

  /// Pfad zur Flagge als Asset.
  final String flagAsset;

  /// l10n-Key für den lokalisierten Sprachnamen (siehe `AppLocalizations`).
  final String labelKey;

  const AppLanguageConfig({
    required this.code,
    required this.flagAsset,
    required this.labelKey,
  });
}

/// Geparster, VALIDIERTER Eintrag aus der Config-Datei.
class _LanguageEntry {
  final String code;
  final String flagAsset;
  final String labelKey;
  final String nameDe;
  final List<String> aliases;
  final bool ui;
  final bool seed;
  final bool course;

  const _LanguageEntry({
    required this.code,
    required this.flagAsset,
    required this.labelKey,
    required this.nameDe,
    required this.aliases,
    required this.ui,
    required this.seed,
    required this.course,
  });
}

/// Eingebettete Defaults – Fallback, wenn die Config-Datei fehlt oder ungültig
/// ist. Inhalte identisch zum Stand vor Ticket #52.
class _Defaults {
  static const List<AppLanguageConfig> appLanguages = [
    AppLanguageConfig(
      code: 'de',
      flagAsset: 'assets/images/flag_germany.png',
      labelKey: 'german',
    ),
    AppLanguageConfig(
      code: 'en',
      flagAsset: 'assets/images/flag_uk.png',
      labelKey: 'english',
    ),
    AppLanguageConfig(
      code: 'es',
      flagAsset: 'assets/images/flag_spa.png',
      labelKey: 'spanish',
    ),
    AppLanguageConfig(
      code: 'fr',
      flagAsset: 'assets/images/flag_fra.png',
      labelKey: 'french',
    ),
    AppLanguageConfig(
      code: 'ru',
      flagAsset: 'assets/images/flag_rus.png',
      labelKey: 'russian',
    ),
    AppLanguageConfig(
      code: 'el',
      flagAsset: 'assets/images/flag_gre.png',
      labelKey: 'greek',
    ),
  ];

  static const Set<String> dictLanguageCodes = {'de', 'en', 'fr'};

  static const List<String> courseCandidateCodes = [
    'de', 'en', 'fr', 'es', 'ru', 'el', 'it', 'pt',
  ];

  static const Map<String, String> flagForCode = {
    'de': 'assets/images/flag_germany.png',
    'en': 'assets/images/flag_uk.png',
    'es': 'assets/images/flag_spa.png',
    'fr': 'assets/images/flag_fra.png',
    'ru': 'assets/images/flag_rus.png',
    'el': 'assets/images/flag_gre.png',
    'it': 'assets/images/flag_ita.png',
    'pt': 'assets/images/flag_por.png',
  };

  static const Map<String, String> courseLanguageNames = {
    'de': 'Deutsch',
    'en': 'Englisch',
    'es': 'Spanisch',
    'fr': 'Französisch',
    'ru': 'Russisch',
    'el': 'Griechisch',
    'it': 'Italienisch',
    'pt': 'Portugiesisch',
  };

  /// Akzeptierte Sprachnamen (deutsch + englisch) → Sprachcode.
  static const Map<String, String> languageNameToCode = {
    // Deutsch
    'deutsch': 'de',
    'englisch': 'en',
    'spanisch': 'es',
    'französisch': 'fr',
    'russisch': 'ru',
    'griechisch': 'el',
    // Englisch
    'german': 'de',
    'english': 'en',
    'spanish': 'es',
    'french': 'fr',
    'russian': 'ru',
    'greek': 'el',
  };
}

/// Alle 30 Verb-Keys (Dict-Datei-Stem ohne Sprach-Präfix).
///
/// Deterministische Reihenfolge; für [buildCourseDictFiles] ergibt sich pro
/// Sprache die identische Datei-Menge wie bisher.
const List<String> verbKeys = [
  'to_be',
  'to_be_allowed_to',
  'to_begin',
  'to_buy',
  'to_can',
  'to_close',
  'to_come',
  'to_drink',
  'to_eat',
  'to_end',
  'to_find',
  'to_go',
  'to_have',
  'to_help',
  'to_learn',
  'to_like',
  'to_live',
  'to_make',
  'to_must',
  'to_need',
  'to_open',
  'to_read',
  'to_see',
  'to_sell',
  'to_should',
  'to_speak',
  'to_understand',
  'to_want',
  'to_work',
  'to_write',
];

/// Verfügbare CEFR-Level für Kurse.
const List<String> courseLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// ── Aktive, datengetriebene Daten (initial = Defaults). ──────────────
List<AppLanguageConfig> _appLanguages = _Defaults.appLanguages;
Set<String> _dictLanguageCodes = _Defaults.dictLanguageCodes;
List<String> _courseCandidateCodes = _Defaults.courseCandidateCodes;
Map<String, String> _flagForCode = _Defaults.flagForCode;
Map<String, String> _courseLanguageNames = _Defaults.courseLanguageNames;
Map<String, String> _languageNameToCode = _Defaults.languageNameToCode;

/// UI-Sprachregistry: alle wählbaren UI-Sprachen (de/en/es/fr/ru/el).
///
/// Diese Liste steuert AUSSCHLIESSLICH die FlagBox-Sprachwahl (UI-Locale).
/// Für Kurse/Muttersprachen/Dicts gelten [dictLanguageCodes] bzw.
/// [courseCandidateCodes].
List<AppLanguageConfig> get appLanguages => _appLanguages;

/// Seed-Sprachen: garantiert verfügbare Kurssprachen/Wörterbücher.
///
/// Dienen als stabiler Fallback (First-Run & Tests), bis die tatsächlich
/// vorhandenen Sprachen per [FileService.discoverLanguageDicts] ermittelt
/// werden. `availableCourses` startet mit dieser Menge.
Set<String> get dictLanguageCodes => _dictLanguageCodes;

/// Alle Sprachcodes, die potenziell Kurs-Wörterbücher (und Audio) liefern
/// könnten.
///
/// Der `initialize`-Copy-Loop probiert JEDE dieser Kandidaten × Verb-Keys und
/// überspringt fehlende Dateien still. Dadurch erscheint eine neue Sprache
/// automatisch, sobald ihre Dicts ins Bundle und (per Discovery) als vorhanden
/// erkannt werden – OHNE die Kopierliste/den Katalog jedes Mal anzufassen.
List<String> get courseCandidateCodes => _courseCandidateCodes;

/// Anzeige-/Sortiername eines Kurses (deutscher Name). Unbekannter Code →
/// roher Code als Fallback.
String courseLanguageName(String code) => _courseLanguageNames[code] ?? code;

/// Flagasset zum Sprachcode; unbekannter Code → Standard-Fallback der ersten
/// UI-Sprache (identisch zum früheren `appLanguages.first.flagAsset`).
String courseFlagAsset(String code) =>
    _flagForCode[code] ?? (appLanguages.isNotEmpty ? appLanguages.first.flagAsset : '');

/// Löst einen Sprachnamen (normalisiert) in einen Sprachcode auf oder `null`.
String? languageCodeForName(String name) =>
    _languageNameToCode[name.trim().toLowerCase()];

/// Die verfügbaren Kurse (Kurs-ID `'{code}_verben_{level}'`).
///
/// Baut Kurse für die übergebene (oder per Default vorhandene) Sprachenmenge.
/// Kurs-IDs nutzen das kleingeschriebene Level (z. B. 'a1'), während `level`
/// für Anzeige/Fortschritt großgeschrieben bleibt ('A1'). Nur Sprachen mit
/// tatsächlich vorhandenen Dicts sollen übergeben werden.
Map<String, LanguageCourse> buildAvailableCourses([Set<String>? codes]) {
  final result = <String, LanguageCourse>{};
  final langCodes = (codes ?? dictLanguageCodes).toList()..sort();
  for (final code in langCodes) {
    final name = courseLanguageName(code);
    for (final level in courseLevels) {
      final id = '${code}_verben_${level.toLowerCase()}';
      result[id] = LanguageCourse(
        id: id,
        languageCode: code,
        languageName: name,
        level: level,
        category: 'Verben',
        flagAsset: courseFlagAsset(code),
      );
    }
  }
  return Map.unmodifiable(result);
}

/// Die Dict-Kopierliste für [FileService.initialize]: Produkt aus
/// [courseCandidateCodes] × [verbKeys].
///
/// Zentraler Baustein des Auto-Copy: Fehlende Assets werden beim Kopieren
/// still übersprungen (bereits vorhandene Try/Catch-Toleranz in `initialize`),
/// sodass neue Sprachen KEINEN Eintrag hier benötigen – nur die Dateien im
/// Bundle plus (unvermeidbar) deren `pubspec.yaml`-Asset-Deklaration.
List<String> buildCourseDictFiles() {
  final result = <String>[];
  for (final code in courseCandidateCodes) {
    for (final verb in verbKeys) {
      result.add('language_dict/$code/${code}_$verb.json');
    }
  }
  return result;
}

/// Lädt und wendet die Sprach-Config aus [languageConfigAsset] an.
///
/// [assetLoader] injiziert das (Asset-)Laden, damit Tests ohne echte
/// Bundle-Dateien arbeiten können (Signatur wie `FileService.loadBundledJson`).
///
/// Fehlerverhalten: Datei fehlt, ist unlesbar oder enthält mindestens einen
/// ungültigen Eintrag → komplette Config wird VERWORFEN, die eingebetteten
/// Defaults bleiben aktiv (App startet unverändert). Erst wenn die ganze Datei
/// valide ist, wird angewendet.
Future<void> loadLanguageConfig({
  required Future<Map<String, dynamic>> Function(String assetPath) assetLoader,
}) async {
  final Map<String, dynamic> raw;
  try {
    raw = await assetLoader(languageConfigAsset);
  } catch (e) {
    log('language_registry: Config $languageConfigAsset nicht ladbar '
        '(Defaults bleiben aktiv): $e');
    return;
  }

  // `{}`/leer = vertraglicher „nicht verfügbar“-Fallback (z. B. loadBundledJson
  // ohne Bundle-Datei in Tests) → nichts anwenden.
  final rawLanguages = raw['languages'];
  if (rawLanguages is! List || rawLanguages.isEmpty) {
    log('language_registry: Config $languageConfigAsset enthält keine '
        'Sprachen – Defaults bleiben aktiv');
    return;
  }

  final entries = <_LanguageEntry>[];
  final seenCodes = <String>{};
  for (final item in rawLanguages) {
    final parsed = _parseEntry(item);
    if (parsed == null) {
      log('language_registry: Ungültiger Eintrag in $languageConfigAsset – '
          'Defaults bleiben aktiv');
      return;
    }
    if (!seenCodes.add(parsed.code)) {
      log('language_registry: Doppelter Sprachcode "${parsed.code}" in '
          '$languageConfigAsset – Defaults bleiben aktiv');
      return;
    }
    entries.add(parsed);
  }

  // Sicherheitsnetz: mindestens ein Kurs- und ein Seed-Kandidat müssen übrig
  // bleiben, sonst würden weder Kopierliste noch Kurse funktionieren.
  if (entries.isEmpty ||
      !entries.any((e) => e.course) ||
      !entries.any((e) => e.seed)) {
    log('language_registry: Config $languageConfigAsset unbrauchbar (keine '
        'Kurs-/Seed-Sprachen) – Defaults bleiben aktiv');
    return;
  }

  _applyEntries(entries);
  languageConfigApplied = true;
}

/// Parst einen einzelnen Config-Eintrag; `null` bei ungültigem Schema.
_LanguageEntry? _parseEntry(dynamic item) {
  if (item is! Map<String, dynamic>) return null;
  final code = item['code'];
  if (code is! String || code.trim().isEmpty) return null;
  final flagAsset = item['flagAsset'];
  if (flagAsset is! String || flagAsset.isEmpty) return null;
  final labelKey = item['labelKey'];
  if (labelKey is! String || labelKey.isEmpty) return null;
  final nameDe = item['nameDe'];
  if (nameDe is! String || nameDe.isEmpty) return null;
  final rawAliases = item['aliases'];
  if (rawAliases != null && rawAliases is! List) return null;
  if (rawAliases is List &&
      rawAliases.any((a) => a is! String || a.trim().isEmpty)) {
    return null;
  }
  final ui = item['ui'];
  final seed = item['seed'];
  final course = item['course'];
  if (ui != null && ui is! bool) return null;
  if (seed != null && seed is! bool) return null;
  if (course != null && course is! bool) return null;

  return _LanguageEntry(
    code: code.trim(),
    flagAsset: flagAsset,
    labelKey: labelKey,
    nameDe: nameDe,
    aliases: [
      for (final alias in (rawAliases as List? ?? const []))
        (alias as String).trim().toLowerCase(),
    ],
    ui: ui ?? false,
    seed: seed ?? false,
    course: course ?? false,
  );
}

/// Überträgt validierte Einträge auf die aktiven Registry-Daten.
void _applyEntries(List<_LanguageEntry> entries) {
  _appLanguages = [
    for (final e in entries)
      if (e.ui)
        AppLanguageConfig(
            code: e.code, flagAsset: e.flagAsset, labelKey: e.labelKey),
  ];
  _dictLanguageCodes = {
    for (final e in entries)
      if (e.seed) e.code,
  };
  _courseCandidateCodes = [
    for (final e in entries)
      if (e.course) e.code,
  ];
  _flagForCode = {
    for (final e in entries) e.code: e.flagAsset,
  };
  _courseLanguageNames = {
    for (final e in entries) e.code: e.nameDe,
  };
  _languageNameToCode = {
    for (final e in entries)
      for (final alias in e.aliases) alias: e.code,
  };
}

/// Setzt die Registry zurück auf die eingebetteten Defaults (z. B. für
/// neues Laden in Tests; eine zuvor angewendete Config wird verworfen).
void resetLanguageRegistry() {
  _appLanguages = _Defaults.appLanguages;
  _dictLanguageCodes = _Defaults.dictLanguageCodes;
  _courseCandidateCodes = _Defaults.courseCandidateCodes;
  _flagForCode = _Defaults.flagForCode;
  _courseLanguageNames = _Defaults.courseLanguageNames;
  _languageNameToCode = _Defaults.languageNameToCode;
  languageConfigApplied = false;
}

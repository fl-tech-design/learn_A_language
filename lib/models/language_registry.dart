import 'app_models.dart' show LanguageCourse;

/// Zentrale Registry für Sprachen, Verb-Keys und Kurs-Level.
///
/// Trennt die (statische) Datenkatalog-Definition vom Code, damit
/// verfügbare Kurse, Muttersprachen-Auswahl und die Dict-Kopierliste ein
/// einheitliches, erweiterbares Bild der Sprachen liefern.
///
/// Wichtig: Es werden KEINE Sprachdaten erfunden. `es`/`ru` erscheinen nur
/// als UI-Sprachwahl (FlagBox); Kurse und Dict-Pfade bleiben auf die Sprachen
/// mit tatsächlich vorhandenen Wörterbüchern (`dictLanguageCodes`:
/// de/en/fr) beschränkt.
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

/// UI-Sprachregistry: alle wählbaren UI-Sprachen (de/en/es/fr/ru).
///
/// Diese Liste steuert AUSSCHLIESSLICH die FlagBox-Sprachwahl (UI-Locale).
/// Für Kurse/Muttersprachen/Dicts gilt [dictLanguageCodes].
const List<AppLanguageConfig> appLanguages = [
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
];

/// Seed-Sprachen: garantiert verfügbare Kurssprachen/Wörterbücher.
///
/// Dienen als stabiler Fallback (First-Run & Tests), bis die tatsächlich
/// vorhandenen Sprachen per [FileService.discoverLanguageDicts] ermittelt
/// werden. `availableCourses` startet mit dieser Menge.
const Set<String> dictLanguageCodes = {'de', 'en', 'fr'};

/// Alle Sprachcodes, die potenziell Kurs-Wörterbücher (und Audio) liefern
/// könnten.
///
/// Der `initialize`-Copy-Loop probiert JEDE dieser Kandidaten × Verb-Keys und
/// überspringt fehlende Dateien still. Dadurch erscheint eine neue Sprache
/// automatisch, sobald ihre Dicts ins Bundle und (per Discovery) als vorhanden
/// erkannt werden – OHNE die Kopierliste/den Katalog jedes Mal anzufassen.
const List<String> courseCandidateCodes = [
  'de',
  'en',
  'fr',
  'es',
  'ru',
  'el',
  'it',
  'pt',
];

/// Flagassets je Sprachcode (für verfügbare/sichtbare Kurs-Sprachen).
const Map<String, String> _flagForCode = {
  'de': 'assets/images/flag_germany.png',
  'en': 'assets/images/flag_uk.png',
  'es': 'assets/images/flag_spa.png',
  'fr': 'assets/images/flag_fra.png',
  'ru': 'assets/images/flag_rus.png',
  'el': 'assets/images/flag_gre.png',
  'it': 'assets/images/flag_ita.png',
  'pt': 'assets/images/flag_por.png',
};

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

/// Sprachcode für einen akzeptierten Sprachnamen (z. B. `'deutsch'`, `'german'`).
///
/// Behält die bisher in `changeLanguage` akzeptierten deutschen und englischen
/// Sprachnamen-Strings bei. Liefert `null` bei unbekanntem Namen.
const Map<String, String> _languageNameToCode = {
  // Deutsch
  'deutsch': 'de',
  'englisch': 'en',
  'spanisch': 'es',
  'französisch': 'fr',
  'russisch': 'ru',
  // Englisch
  'german': 'de',
  'english': 'en',
  'spanish': 'es',
  'french': 'fr',
  'russian': 'ru',
};

/// Löst einen Sprachnamen (normalisiert) in einen Sprachcode auf oder `null`.
String? languageCodeForName(String name) =>
    _languageNameToCode[name.trim().toLowerCase()];

/// Anzeige-/Sortiername eines Kurses (deutscher Name, wie bisher).
String courseLanguageName(String code) => switch (code) {
      'de' => 'Deutsch',
      'en' => 'Englisch',
      'es' => 'Spanisch',
      'fr' => 'Französisch',
      'ru' => 'Russisch',
      'el' => 'Griechisch',
      'it' => 'Italienisch',
      'pt' => 'Portugiesisch',
      _ => code,
    };

/// Flagasset zum Sprachcode ({} → Standard-Fallback „en“).
String courseFlagAsset(String code) =>
    _flagForCode[code] ?? appLanguages.first.flagAsset;

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
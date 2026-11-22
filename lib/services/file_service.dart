import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'storage_error_bus.dart';

/// Kontrolliert signalisierter Persistenzfehler.
///
/// Wird geworfen, wenn eine Datei existiert, aber nicht gelesen/geparst
/// werden kann (Primärdatei UND `.bak`) oder ein Schreibvorgang fehlschlägt.
/// „Datei existiert nicht" ist KEIN Fehler – das ist der Normalfall und wird
/// weiterhin mit `{}` in [FileService.loadJson] beantwortet.
class PersistenceException implements Exception {
  final String path;
  final Object? cause;

  const PersistenceException(this.path, [this.cause]);

  @override
  String toString() => 'PersistenceException($path, cause: $cause)';
}

/// Wird geworfen, wenn ein aufzulösender Pfad unzulässig ist: leer, NUL-haltig,
/// absolut (auch Windows-Drive), mit `..`/`.`-Segmenten (Slash ODER Backslash)
/// oder ausserhalb des App-Datenverzeichnisses (auch per Symlink-Kette).
///
/// Erbt bewusst von [PersistenceException]; dadurch greifen bestehende
/// `on PersistenceException`-Catch-Blöcke (UI/Manager) weiterhin kontrolliert.
/// Wichtig: Ein abgelehnter Pfad wird bei [FileService.loadJson] NICHT als
/// „Datei existiert nicht" behandelt (kein `{}`), sondern explizit signalisiert.
class PathRejectedException extends PersistenceException {
  PathRejectedException(super.path, [super.cause]);

  @override
  String toString() => 'PathRejectedException($path, cause: $cause)';
}

/// Provides JSON file read/write with automatic first-launch asset copy.
/// Interface extracted from the former static FileService class as part of
/// the static-manager decoupling (point2, Commit A).
abstract class FileService {
  Future<String> get appDir;
  Future<void> initialize();
  Future<Map<String, dynamic>> loadJson(String relativePath);
  Future<void> saveJson(String relativePath, Map<String, dynamic> data);
  Future<void> updateJsonKey(
      String relativePath, String key, Object? value);

  /// Löscht die Datei unter [relativePath], falls sie existiert. Unterliegt
  /// derselben zentralen Pfad-Containment-Prüfung wie Lesen/Schreiben.
  Future<void> deleteFile(String relativePath);

  Future<Map<String, dynamic>> loadBundledJson(String assetPath);
  Future<Map<String, dynamic>> loadLanguageDictFromDir(String langCode);
}

/// Concrete implementation backed by the app documents directory.
///
/// Für Unit-Tests kann ein eigenes Basisverzeichnis übergeben werden
/// ([baseDirOverride]); ohne Angabe wird wie bisher PathProvider genutzt.
class FileServiceImpl implements FileService {
  final String? baseDirOverride;

  FileServiceImpl({this.baseDirOverride});

  String? _appDir;
  String? _canonicalAppDir;

  static final RegExp _absoluteWindowsDrive = RegExp(r'^[A-Za-z]:[\\/]');
  static final RegExp _pathSeparators = RegExp(r'[\\/]');

  @override
  Future<String> get appDir async {
    if (_appDir != null) return _appDir!;
    if (baseDirOverride != null) {
      _appDir = baseDirOverride;
      return _appDir!;
    }
    final dir = await getApplicationDocumentsDirectory();
    _appDir = dir.path;
    return _appDir!;
  }

  /// Kanonischer (symlink-aufgelöster) Basis-Pfad des App-Datenverzeichnisses.
  /// Existiert das Verzeichnis noch nicht, wird der lexikalische Pfad genutzt.
  Future<String> _canonicalAppDirPath() async {
    if (_canonicalAppDir != null) return _canonicalAppDir!;
    final dir = await appDir;
    var canonical = dir;
    try {
      canonical = await Directory(dir).resolveSymbolicLinks();
    } on FileSystemException {
      log('file_service: appDir nicht auflösbar – nutze lexikalischen Pfad');
    }
    _canonicalAppDir = canonical;
    return canonical;
  }

  /// Lexikalische Pfadprüfung: liefert [relativePath] mit normalisierten
  /// `/`-Separatoren zurück oder wirft [PathRejectedException].
  static String _assertSafeRelativePath(String relativePath) {
    if (relativePath.isEmpty) {
      throw PathRejectedException(relativePath, StateError('Leerer Pfad'));
    }
    if (relativePath.contains('\x00') ||
        relativePath.startsWith('/') ||
        _absoluteWindowsDrive.hasMatch(relativePath)) {
      throw PathRejectedException(
          relativePath, StateError('Unerlaubter (absoluter) Pfad'));
    }
    final segments = relativePath.split(_pathSeparators);
    if (segments.any((s) => s == '..' || s == '.')) {
      throw PathRejectedException(
          relativePath, StateError('Unerlaubte Pfadsegmente (.. bzw. .)'));
    }
    return segments.join('/');
  }

  /// Löst [relativePath] gegen das App-Datenverzeichnis auf.
  Future<String> _resolveAppPath(String relativePath) async {
    final safe = _assertSafeRelativePath(relativePath);
    final dir = await appDir;
    return '$dir/$safe';
  }

  /// Stellt sicher, dass [absolutePath] (bzw. sein existenter Vorfahre) nach
  /// Symlink-Auflösung im kanonischen App-Verzeichnis liegt.
  ///
  /// TOCTOU-Hinweis: dart:io bietet keinen atomaren „O_NOFOLLOW"-Zugriff;
  /// diese Prüfung schützt gegen statische und vorkonfigurierte Symlink-Lagen.
  /// Ein Tausch von Verzeichnissen DURCH einen Symlink nach der Prüfung ist
  /// nicht zuverlässig abwehrbar. Auf Android ist das appDir privat und nicht
  /// durch Angreifer beschreibbar; auf Linux-Desktop besitzt ein Angreifer
  /// mit Schreibzugriff auf das appDir ohnehin direkten Datenzugriff.
  Future<void> _ensureCanonicalWithinAppDir(String absolutePath) async {
    final canonicalRoot = await _canonicalAppDirPath();
    String? resolved;
    try {
      resolved = await File(absolutePath).resolveSymbolicLinks();
    } on FileSystemException {
      // Datei existiert (noch) nicht → Parent-Anfrage versuchen.
    }
    if (resolved == null) {
      try {
        resolved = await File(absolutePath).parent.resolveSymbolicLinks();
      } on FileSystemException {
        return; // weder Datei noch Parent existieren → kein Symlink möglich
      }
    }
    if (!_isWithin(canonicalRoot, resolved)) {
      throw PathRejectedException(
        absolutePath,
        StateError('Aufgelöster Pfad liegt ausserhalb des App-Verzeichnisses'),
      );
    }
  }

  static bool _isWithin(String root, String candidate) {
    final r = root.replaceAll('\\', '/');
    final c = candidate.replaceAll('\\', '/');
    return c == r || c.startsWith('$r/');
  }

  @override
  Future<void> initialize() async {
    final dir = await appDir;
    final flagFile = File('$dir/.initialized');
    final firstRun = !await flagFile.exists();

    final files = <String>[
      'data_base/base_data.json',
      'data_app/app_data.json',
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
      'language_dict/fr/fr_to_be.json',
      'language_dict/fr/fr_to_be_allowed_to.json',
      'language_dict/fr/fr_to_begin.json',
      'language_dict/fr/fr_to_buy.json',
      'language_dict/fr/fr_to_can.json',
      'language_dict/fr/fr_to_close.json',
      'language_dict/fr/fr_to_come.json',
      'language_dict/fr/fr_to_drink.json',
      'language_dict/fr/fr_to_eat.json',
      'language_dict/fr/fr_to_end.json',
      'language_dict/fr/fr_to_find.json',
      'language_dict/fr/fr_to_go.json',
      'language_dict/fr/fr_to_have.json',
      'language_dict/fr/fr_to_help.json',
      'language_dict/fr/fr_to_learn.json',
      'language_dict/fr/fr_to_like.json',
      'language_dict/fr/fr_to_live.json',
      'language_dict/fr/fr_to_make.json',
      'language_dict/fr/fr_to_must.json',
      'language_dict/fr/fr_to_need.json',
      'language_dict/fr/fr_to_open.json',
      'language_dict/fr/fr_to_read.json',
      'language_dict/fr/fr_to_see.json',
      'language_dict/fr/fr_to_sell.json',
      'language_dict/fr/fr_to_should.json',
      'language_dict/fr/fr_to_speak.json',
      'language_dict/fr/fr_to_understand.json',
      'language_dict/fr/fr_to_want.json',
      'language_dict/fr/fr_to_work.json',
      'language_dict/fr/fr_to_write.json',
    ];

    for (final rel in files) {
      // Bei bestehenden Installationen werden nur die Wörterbücher aus dem
      // Bundle synchronisiert (Inhalts-Assets, z. B. neues Listen-Schema).
      // App-Daten und User-Dateien bleiben unberührt, damit kein Fortschritt
      // verloren geht.
      if (!firstRun && !rel.startsWith('language_dict/')) continue;
      final assetPath = 'assets/$rel';
      final targetFile = File('$dir/$rel');
      try {
        final bytes = await rootBundle.load(assetPath);
        final parent = targetFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        await targetFile.writeAsBytes(bytes.buffer.asUint8List());
      } catch (e) {
        log('initialize: Kopie von $rel fehlgeschlagen: $e');
      }
    }

    if (firstRun) await flagFile.create();
  }

  @override
  Future<Map<String, dynamic>> loadJson(String relativePath) async {
    final file = File(await _resolveAppPath(relativePath));
    await _ensureCanonicalWithinAppDir(file.path);

    // ── Normalfall: Datei fehlt → {} (semantisch „nicht vorhanden"). ──
    if (!await file.exists()) return {};

    // ── Fehlerfall: Datei existiert, ist aber unlesbar/korrupt. ──
    try {
      return _decodeJsonObject(relativePath, await file.readAsString());
    } catch (e) {
      log('loadJson: $relativePath unlesbar/korrupt ($e)');

      // Backup-Generation als Rettung versuchen.
      final backup = File('${file.path}.bak');
      if (await backup.exists()) {
        try {
          final recovered = _decodeJsonObject(relativePath, await backup.readAsString());
          log('loadJson: $relativePath aus .bak gerettet');
          // Primärdatei atomar reparieren, OHNE das .bak anzufassen
          // (rotierte saveJson später das unreparierte .bak, wäre die
          // Rettung nur einmal wirksam gewesen).
          try {
            await _writeFileAtomic(file.path, recovered, rotateBackup: false);
          } on Exception catch (e2) {
            log('loadJson: Reparatur von $relativePath fehlgeschlagen ($e2)');
            StorageErrorBus.instance.report(StorageErrorKind.userDataRecovered);
          }
          return recovered;
        } catch (e2) {
          log('loadJson: Backup $relativePath.bak ebenfalls unbrauchbar ($e2)');
        }
      }

      throw PersistenceException(relativePath, e);
    }
  }

  /// Decodiert [content] als JSON-Objekt. Wirft [FormatException] bei
  /// ungültigem JSON oder wenn der Top-Level-Typ kein Map ist (z. B.
  /// `[1,2,3]` oder `"text"`) – bewusst OHNE `TypeError`.
  static Map<String, dynamic> _decodeJsonObject(
      String relativePath, String content) {
    final decoded = json.decode(content);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
          '$relativePath: erwartet JSON-Objekt, gefunden ${decoded.runtimeType}');
    }
    return decoded;
  }

  @override
  Future<void> saveJson(
      String relativePath, Map<String, dynamic> data) async {
    final target = await _resolveAppPath(relativePath);
    await _writeFileAtomic(target, data, rotateBackup: true);
  }

  /// Schreibt [data] atomar als JSON nach [relativePath].
  ///
  /// Ablauf (`flush: true`, damit der Inhalt vor dem `rename` auf der Platte
  /// liegt – Stromverlust-Sicherheit):
  /// 1. Existierende Zieldatei → eine Generation als `.bak` rotieren
  ///    (nur wenn [rotateBackup] gesetzt ist – die Rettung in [loadJson]
  ///    repariert die Primärdatei, ohne das Backup anzufassen).
  /// 2. Temp-Datei `$path.tmp` im SELBEN Verzeichnis schreiben → eine volle
  ///    Disk bricht hier, Zieldatei und Backup bleiben intakt.
  /// 3. `tmp.rename(path)` → atomarer Umstieg (gleiches Dateisystem).
  ///
  /// Fehler werden protokolliert und als [PersistenceException] signalisiert –
  /// niemals still geschluckt.
  Future<void> _writeFileAtomic(
      String absolutePath, Map<String, dynamic> data,
      {required bool rotateBackup}) async {
    const encoder = JsonEncoder.withIndent('  ');
    final file = File(absolutePath);
    final parent = file.parent;

    try {
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      // Backstop: Auch intern aufgelöste absolute Pfade müssen innerhalb des
      // App-Verzeichnisses liegen (Symlink-Ketten). Ablehnungen werden NIE als
      // generischer Persistenzfehler verpackt, sondern durchgereicht.
      await _ensureCanonicalWithinAppDir(absolutePath);
      if (rotateBackup && await file.exists()) {
        await File('$absolutePath.bak')
            .writeAsString(await file.readAsString(), flush: true);
      }
      final tmp = File('$absolutePath.tmp');
      await tmp.writeAsString(encoder.convert(data), flush: true);
      await tmp.rename(absolutePath);
    } catch (e) {
      if (e is PathRejectedException) rethrow;
      log('saveJson: Schreiben von $absolutePath fehlgeschlagen: $e');
      throw PersistenceException(absolutePath, e);
    }
  }

  @override
  Future<void> updateJsonKey(
      String relativePath, String key, Object? value) async {
    final data = await loadJson(relativePath);
    data[key] = value;
    await saveJson(relativePath, data);
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    final target = await _resolveAppPath(relativePath);
    await _ensureCanonicalWithinAppDir(target);
    final file = File(target);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (e) {
      log('deleteFile: Löschen von $target fehlgeschlagen: $e');
      throw PersistenceException(target, e);
    }
  }

  @override
  Future<Map<String, dynamic>> loadBundledJson(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('$assetPath: kein JSON-Objekt');
      }
      return decoded;
    } catch (e) {
      // Bundle-Assets sind read-only; {} bleibt hier der vertragliche
      // „nicht verfügbar"-Fallback (Normalfall), aber der Fehler wird sichtbar.
      log('loadBundledJson: $assetPath konnte nicht geladen werden: $e');
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> loadLanguageDictFromDir(
      String langCode) async {
    final String langDirPath;
    try {
      langDirPath = await _resolveAppPath('language_dict/$langCode');
    } on PathRejectedException catch (e) {
      // Unsicherer Sprachcode → kein Zugriff ausserhalb des App-Verzeichnisses;
      // `{}` ist der best-effort-Fallback (read-only, wie bei fehlendem Ordner).
      log('loadLanguageDictFromDir: unsicherer Sprachcode "$langCode" ($e)');
      return {};
    }
    final langDir = Directory(langDirPath);
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
          } catch (e) {
            log('loadLanguageDictFromDir: $fname konnte nicht gelesen werden: $e');
          }
        }
      }
    }
    return result;
  }
}

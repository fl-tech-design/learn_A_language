import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'file_service.dart';

/// Zentrale Manifest-URL der Sprachpakete (raw.githubusercontent.com, main).
///
/// Das Manifest wird von tools/build_packs.dart im Repo
/// fl-tech-design/learn_A_language_packs erzeugt (Ticket #68).
const String packManifestUrl =
    'https://raw.githubusercontent.com/fl-tech-design/learn_A_language_packs'
    '/main/manifest/manifest.json';

/// Installationsstatus eines Sprachpakets.
enum PackInstallStatus { notInstalled, installed }

/// Fehlerkategorien der Pack-Infrastruktur.
enum PackErrorKind {
  manifestUnavailable,
  packNotFound,
  downloadFailed,
  checksumMismatch,
  corruptZip,
  invalidPack,
  uninstallFailed,
  ioError,
}

/// Kontrollierter Fehler der Pack-Infrastruktur.
///
/// [langCode] ist bei manifestweiten Fehlern leer (`''`).
class PackException implements Exception {
  final PackErrorKind kind;
  final String langCode;
  final Object? cause;

  const PackException(this.kind, this.langCode, [this.cause]);

  @override
  String toString() =>
      'PackException($kind, lang: "${langCode.isEmpty ? '-' : langCode}", '
      'cause: $cause)';
}

/// Ein Paket-Eintrag im Manifest (eine Sprache).
class PackEntry {
  final String id;
  final String version;
  final String url;
  final int sizeBytes;
  final String sha256;
  final String minAppVersion;
  final List<String> contents;

  const PackEntry({
    required this.id,
    required this.version,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    this.minAppVersion = '',
    this.contents = const [],
  });

  factory PackEntry.fromJson(Map<String, dynamic> json) => PackEntry(
        id: json['id'] as String,
        version: json['version'] as String,
        url: json['url'] as String,
        sizeBytes: (json['size_bytes'] as num).toInt(),
        sha256: json['sha256'] as String,
        minAppVersion: json['min_app_version'] as String? ?? '',
        contents: [
          for (final c in (json['contents'] as List? ?? const [])) c as String,
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'url': url,
        'size_bytes': sizeBytes,
        'sha256': sha256,
        'min_app_version': minAppVersion,
        'contents': contents,
      };
}

/// Geparstes Manifest mit allen Paket-Einträgen.
class PackManifest {
  final int schemaVersion;
  final String version;
  final List<PackEntry> packs;

  const PackManifest({
    required this.schemaVersion,
    required this.version,
    required this.packs,
  });

  factory PackManifest.fromJson(Map<String, dynamic> json) {
    final rawPacks = json['packs'];
    if (rawPacks is! List) {
      throw const FormatException('manifest: "packs" ist keine Liste');
    }
    return PackManifest(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      version: json['version']?.toString() ?? '',
      packs: [
        for (final p in rawPacks) PackEntry.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  /// Eintrag zu [langCode] oder `null`, falls nicht im Manifest.
  PackEntry? entryFor(String langCode) {
    for (final p in packs) {
      if (p.id == langCode) return p;
    }
    return null;
  }
}

/// Ergebnis einer erfolgreichen Installation.
class PackInstallation {
  final PackEntry entry;

  /// Relativ zum App-Verzeichnis extrahierte Dateipfade (ohne `pack.json`).
  final List<String> extractedFiles;

  const PackInstallation({
    required this.entry,
    required this.extractedFiles,
  });
}

/// Pack-Verwaltung (Ticket #68): Manifest laden, Pakete installieren
/// (Download → SHA-256-Prüfung → Entpacken) und deinstallieren.
///
/// Installierte Pakete liegen unter `language_dict/<lang>/`, `audio/<lang>/`
/// und `grammar/grammar_<lang>/` im App-Datenverzeichnis – identisch zu den
/// Pfaden, die der Rest der App erwartet. Der Installationsstatus wird über
/// Marker-Dateien unter `.pack_marker/<lang>.json` geführt (robust auch bei
/// Paketen, die z. B. keine Grammatik enthalten).
///
/// Benutzerdaten werden von install/uninstall NIE angefasst.
abstract class PackManager {
  /// Lädt und parst das zentrale Manifest von [packManifestUrl].
  Future<PackManifest> loadManifest();

  /// Installationsstatus von [langCode] (ohne Netzwerkzugriff).
  Future<PackInstallStatus> installStatus(String langCode);

  /// Alle Sprachcodes mit gesetztem Installations-Marker.
  Future<Set<String>> installedPacks();

  /// Installiert das Paket für [langCode]: Manifest laden, ZIP von der
  /// unveränderlichen URL laden, SHA-256 gegen das Manifest prüfen, in das
  /// App-Datenverzeichnis entpacken, Marker setzen.
  ///
  /// Wirft [PackException] bei Netzwerk-, Prüfsummen- oder Paketfehlern.
  Future<PackInstallation> install(String langCode);

  /// Deinstalliert das Paket für [langCode]: Marker und die drei
  /// Sprachordner werden gelöscht. Benutzerdaten bleiben unberührt.
  Future<void> uninstall(String langCode);
}

// ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
// ██  Konkrete Implementierung
// ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

class PackManagerImpl implements PackManager {
  final FileService _fileService;
  final http.Client _httpClient;
  final String manifestUrl;

  static const Duration manifestTimeout = Duration(seconds: 30);
  static const Duration downloadTimeout = Duration(seconds: 120);

  static const String _markerDirName = '.pack_marker';
  static const String _tmpDirName = '.pack_tmp';

  PackManagerImpl({
    required FileService fileService,
    http.Client? httpClient,
    this.manifestUrl = packManifestUrl,
  })  : _fileService = fileService,
        _httpClient = httpClient ?? http.Client();

  @override
  Future<PackManifest> loadManifest() async {
    final http.Response response;
    try {
      response = await _httpClient
          .get(Uri.parse(manifestUrl))
          .timeout(manifestTimeout);
    } catch (e) {
      throw PackException(PackErrorKind.manifestUnavailable, '', e);
    }
    if (response.statusCode != 200) {
      throw PackException(PackErrorKind.manifestUnavailable, '',
          'HTTP ${response.statusCode}');
    }
    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Manifest ist kein JSON-Objekt');
      }
      return PackManifest.fromJson(decoded);
    } catch (e) {
      throw PackException(PackErrorKind.manifestUnavailable, '', e);
    }
  }

  @override
  Future<PackInstallStatus> installStatus(String langCode) async {
    final marker = await _markerFile(langCode);
    return await marker.exists()
        ? PackInstallStatus.installed
        : PackInstallStatus.notInstalled;
  }

  @override
  Future<Set<String>> installedPacks() async {
    final appDir = await _fileService.appDir;
    final markerDir = Directory('$appDir/$_markerDirName');
    if (!await markerDir.exists()) return {};
    final result = <String>{};
    await for (final entity in markerDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.json')) {
        result.add(name.substring(0, name.length - 5));
      }
    }
    return result;
  }

  @override
  Future<PackInstallation> install(String langCode) async {
    final manifest = await loadManifest();
    final entry = manifest.entryFor(langCode);
    if (entry == null) {
      throw PackException(PackErrorKind.packNotFound, langCode);
    }

    final appDir = await _fileService.appDir;
    final tmpFile = File('$appDir/$_tmpDirName/$langCode.zip');

    // 1) ZIP von der unveränderlichen URL laden.
    final http.Response response;
    try {
      await tmpFile.parent.create(recursive: true);
      response = await _httpClient
          .get(Uri.parse(entry.url))
          .timeout(downloadTimeout);
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.downloadFailed, langCode, e);
    }
    if (response.statusCode != 200) {
      await _cleanupTmp(tmpFile);
      throw PackException(
          PackErrorKind.downloadFailed, langCode, 'HTTP ${response.statusCode}');
    }
    try {
      await tmpFile.writeAsBytes(response.bodyBytes, flush: true);
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.ioError, langCode, e);
    }

    // 2) SHA-256 gegen das Manifest prüfen – erst danach wird irgendetwas
    //    in den App-Bereich geschrieben.
    final List<int> zipBytes;
    final String digest;
    try {
      zipBytes = await tmpFile.readAsBytes();
      digest = sha256.convert(zipBytes).toString();
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.ioError, langCode, e);
    }
    if (digest.toLowerCase() != entry.sha256.toLowerCase()) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.checksumMismatch, langCode,
          'erwartet ${entry.sha256}, berechnet $digest');
    }

    // 3) Entpacken mit Pfad-Sicherheit.
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.corruptZip, langCode, e);
    }

    final extracted = <String>[];
    String? packJsonId;
    try {
      for (final f in archive) {
        if (!f.isFile) continue; // Verzeichnisse werden implizit angelegt.
        final rawName = f.name.replaceAll('\\', '/');
        final name =
            rawName.startsWith('./') ? rawName.substring(2) : rawName;
        if (name == 'pack.json') {
          // pack.json ist Paket-Metadaten und wird nicht in den App-Bereich
          // geschrieben (kollidiert sonst über Sprachen hinweg); nur validiert.
          packJsonId = _parsePackJsonId(f.content as List<int>);
          continue;
        }
        final safePath = _assertSafeRelativePath(name);
        final target = File('$appDir/$safePath');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(f.content as List<int>, flush: true);
        extracted.add(safePath);
      }
    } on PackException {
      await _cleanupTmp(tmpFile);
      rethrow;
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.invalidPack, langCode, e);
    }

    // 4) pack.json validieren: id muss zum Sprachcode passen.
    if (packJsonId != langCode) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.invalidPack, langCode,
          'pack.json-id erwartet "$langCode", gefunden '
          '"${packJsonId ?? 'kein pack.json im ZIP'}"');
    }

    // 5) Marker setzen (Installationsstatus).
    try {
      final marker = await _markerFile(langCode);
      await marker.parent.create(recursive: true);
      await marker.writeAsString(
          json.encode({
            'id': langCode,
            'version': entry.version,
            'installed_at': DateTime.now().toIso8601String(),
          }),
          flush: true);
    } catch (e) {
      await _cleanupTmp(tmpFile);
      throw PackException(PackErrorKind.ioError, langCode, e);
    }

    // 6) Temporäre Datei entfernen.
    await _cleanupTmp(tmpFile);

    log('pack_manager: Paket "$langCode" (${entry.version}) installiert '
        '(${extracted.length} Dateien)');
    return PackInstallation(entry: entry, extractedFiles: extracted);
  }

  @override
  Future<void> uninstall(String langCode) async {
    final appDir = await _fileService.appDir;
    try {
      await _deleteIfExists(await _markerFile(langCode));
      await _deleteDirIfExists('$appDir/language_dict/$langCode');
      await _deleteDirIfExists('$appDir/audio/$langCode');
      await _deleteDirIfExists('$appDir/grammar/grammar_$langCode');
    } catch (e) {
      throw PackException(PackErrorKind.uninstallFailed, langCode, e);
    }
    log('pack_manager: Paket "$langCode" deinstalliert');
  }

  Future<File> _markerFile(String langCode) async {
    final dir = await _fileService.appDir;
    return File('$dir/$_markerDirName/$langCode.json');
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _deleteDirIfExists(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _cleanupTmp(File tmpFile) async {
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
      // Leeren tmp-Ordner mitentfernen; nicht leer (z. B. paralleler
      // Download) bleibt er bestehen und wird von Directory.delete geworfen.
      final parent = tmpFile.parent;
      if (await parent.exists()) await parent.delete();
    } catch (e) {
      log('pack_manager: tmp-Cleanup fehlgeschlagen: $e');
    }
  }

  /// Liest `id` aus `pack.json`; `null` bei unlesbarem/ungültigem Inhalt.
  static String? _parsePackJsonId(List<int> content) {
    try {
      final decoded = json.decode(utf8.decode(content));
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id'];
        return id is String ? id : null;
      }
    } catch (_) {
      // wird vom Aufrufer als invalidPack behandelt
    }
    return null;
  }

  /// Pfadprüfung analog zu `FileService._assertSafeRelativePath` (Ticket #43):
  /// leere Pfade, NUL, absolute Pfade (auch Windows-Drives) sowie `..`/`.`
  /// Segmente (Slash ODER Backslash) werden abgelehnt.
  static String _assertSafeRelativePath(String relativePath) {
    if (relativePath.isEmpty) {
      throw const FormatException('Leerer ZIP-Pfad');
    }
    if (relativePath.contains('\x00') ||
        relativePath.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(relativePath)) {
      throw FormatException('Unerlaubter (absoluter) ZIP-Pfad: $relativePath');
    }
    final segments = relativePath.split(RegExp(r'[\\/]'));
    if (segments.any((s) => s == '..' || s == '.')) {
      throw FormatException(
          'Unerlaubte ZIP-Pfadsegmente (.. bzw. .): $relativePath');
    }
    return segments.join('/');
  }
}

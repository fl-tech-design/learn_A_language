import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:learn_a_language/services/pack_manager.dart';

import 'helpers/fakes.dart';

/// Erzeugt ein ZIP aus `files` (Pfad -> Inhalt) per [ZipEncoder].
List<int> buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.add(ArchiveFile(e.key, e.value.length, e.value));
  }
  return ZipEncoder().encode(archive);
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> packJson(String id) => {
      'id': id,
      'version': '1.0.0',
      'schema_version': 1,
      'contents': ['language_dict', 'audio'],
      'license': 'test',
    };

Map<String, dynamic> buildManifest(
  String lang, {
  required String sha256,
  required int size,
}) =>
    {
      'schema_version': 1,
      'version': '1.0.0',
      'packs': [
        {
          'id': lang,
          'version': '1.0.0',
          'url': 'https://example.com/lal-pack-$lang-1.0.0.zip',
          'size_bytes': size,
          'sha256': sha256,
          'min_app_version': '1.13.0',
          'contents': ['language_dict', 'audio'],
        },
      ],
    };

/// Gültiges ZIP für Sprache `lang` mit Dict + Audio + pack.json.
List<int> validZip(String lang) => buildZip({
      'pack.json': utf8.encode(jsonEncode(packJson(lang))),
      'language_dict/$lang/${lang}_to_be.json':
          utf8.encode('{"infinitive":"sein"}'),
      'audio/$lang/verbs/${lang}_audio_to_be/audio_ich_bin_m.mp3':
          utf8.encode('fake-audio'),
    });

MockClient httpClientFor({
  required List<int> zipBytes,
  Map<String, dynamic>? manifest,
  int manifestStatus = 200,
}) {
  final effectiveManifest = manifest ??
      buildManifest('de',
          sha256: sha256Hex(zipBytes), size: zipBytes.length);
  return MockClient((request) async {
    final url = request.url.toString();
    if (url.contains('/manifest/manifest.json')) {
      if (manifestStatus != 200) return http.Response('kaputt', manifestStatus);
      return http.Response(jsonEncode(effectiveManifest), 200,
          headers: {'content-type': 'application/json'});
    }
    if (url.endsWith('.zip')) {
      return http.Response.bytes(zipBytes, 200,
          headers: {'content-type': 'application/zip'});
    }
    return http.Response('not found', 404);
  });
}

void main() {
  late Directory tempDir;
  late FakeFileService fileService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pack_manager_test_');
    fileService = FakeFileService(appDirValue: tempDir.path);
    // App-Version für die min_app_version-Prüfung bereitstellen. Standard ist
    // hoch genug (1.13.0+27 >= min 1.13.0), damit bestehende Install-Tests
    // weiterlaufen; Tests für den Fehlerpfad überschreiben das lokal.
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'learn_a_language',
      packageName: 'learn_a_language',
      version: '1.13.0+27',
      buildNumber: '27',
      buildSignature: '',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('loadManifest', () {
    test('parst ein gültiges Manifest', () async {
      final zip = validZip('de');
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      final manifest = await manager.loadManifest();

      expect(manifest.schemaVersion, 1);
      expect(manifest.version, '1.0.0');
      expect(manifest.packs, hasLength(1));
      expect(manifest.packs.first.id, 'de');
      expect(manifest.packs.first.sha256, sha256Hex(zip));
    });

    test('wirft manifestUnavailable bei HTTP-Fehler', () async {
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(
            zipBytes: validZip('de'), manifestStatus: 500),
      );

      expect(
        manager.loadManifest(),
        throwsA(isA<PackException>().having(
            (e) => e.kind, 'kind', PackErrorKind.manifestUnavailable)),
      );
    });
  });

  group('appVersion / isVersionAtLeast', () {
    test('liefert die aktuelle App-Version aus package_info_plus', () async {
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: validZip('de')),
      );

      expect(await manager.appVersion(), '1.13.0+27');
    });

    test('vergleicht Major/Minor/Patch korrekt', () {
      expect(PackManager.isVersionAtLeast('2.0.0', '1.13.0'), isTrue);
      expect(PackManager.isVersionAtLeast('1.13.0', '1.13.0'), isTrue);
      expect(PackManager.isVersionAtLeast('1.14.0', '1.13.0'), isTrue);
      expect(PackManager.isVersionAtLeast('1.13.1', '1.13.0'), isTrue);
      expect(PackManager.isVersionAtLeast('1.12.0', '1.13.0'), isFalse);
      expect(PackManager.isVersionAtLeast('1.13.0', '1.13.1'), isFalse);
    });

    test('ignoriert den Build-Teil nach +', () {
      expect(PackManager.isVersionAtLeast('1.13.0+26', '1.13.0'), isTrue);
      expect(PackManager.isVersionAtLeast('2.0.0+1', '1.13.0+26'), isTrue);
      expect(PackManager.isVersionAtLeast('1.12.0+99', '1.13.0'), isFalse);
      expect(PackManager.isVersionAtLeast('1.13.0+27', '1.13.0'), isTrue);
    });
  });

  group('install', () {
    test('installiert Paket: SHA-Prüfung, Entpacken, Marker', () async {
      final zip = validZip('de');
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      final result = await manager.install('de');

      expect(result.entry.id, 'de');
      expect(result.extractedFiles,
          contains('language_dict/de/de_to_be.json'));
      expect(result.extractedFiles,
          contains('audio/de/verbs/de_audio_to_be/audio_ich_bin_m.mp3'));

      expect(
          await File('${tempDir.path}/language_dict/de/de_to_be.json')
              .exists(),
          isTrue);
      expect(
          await File(
                  '${tempDir.path}/audio/de/verbs/de_audio_to_be/audio_ich_bin_m.mp3')
              .exists(),
          isTrue);
      expect(await File('${tempDir.path}/pack.json').exists(), isFalse);

      expect(await manager.installStatus('de'), PackInstallStatus.installed);
      expect(await Directory('${tempDir.path}/.pack_tmp').exists(), isFalse);
    });

    test('bricht mit appVersionTooLow ab, wenn die App zu alt ist', () async {
      // App-Version bewusst unter der min_app_version (1.13.0) setzen.
      PackageInfo.setMockInitialValues(
        appName: 'learn_a_language',
        packageName: 'learn_a_language',
        version: '1.12.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final zip = validZip('de');
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      expect(
        () => manager.install('de'),
        throwsA(isA<PackException>()
            .having((e) => e.kind, 'kind', PackErrorKind.appVersionTooLow)
            .having((e) => e.cause, 'cause', '1.13.0')),
      );
      // Nichts installiert, keine Reste.
      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
      expect(await Directory('${tempDir.path}/.pack_tmp').exists(), isFalse);
    });

    test('wirft packNotFound für unbekannte Sprache', () async {
      final zip = validZip('de');
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      expect(
        () => manager.install('xx'),
        throwsA(isA<PackException>()
            .having((e) => e.kind, 'kind', PackErrorKind.packNotFound)),
      );
    });

    test('wirft checksumMismatch und extrahiert NICHTS bei falscher SHA-256',
        () async {
      final zip = validZip('de');
      final manifest = buildManifest('de',
          sha256: List.filled(64, '0').join(), size: 1);
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip, manifest: manifest),
      );

      expect(
        () => manager.install('de'),
        throwsA(isA<PackException>().having(
            (e) => e.kind, 'kind', PackErrorKind.checksumMismatch)),
      );

      expect(
          await File('${tempDir.path}/language_dict/de/de_to_be.json')
              .exists(),
          isFalse);
      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
      expect(await Directory('${tempDir.path}/.pack_tmp').exists(), isFalse);
    });

    test('wirft invalidPack bei falscher pack.json-id', () async {
      // pack.json sagt "en", installiert wird aber "de".
      final zip = buildZip({
        'pack.json': utf8.encode(jsonEncode(packJson('en'))),
        'language_dict/de/de_to_be.json': utf8.encode('{}'),
      });
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      expect(
        () => manager.install('de'),
        throwsA(isA<PackException>()
            .having((e) => e.kind, 'kind', PackErrorKind.invalidPack)),
      );
      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
    });

    test('wehrt Pfad-Traversal im ZIP ab (../)', () async {
      final zip = buildZip({
        'pack.json': utf8.encode(jsonEncode(packJson('de'))),
        '../evil.txt': utf8.encode('böse'),
      });
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );

      expect(
        () => manager.install('de'),
        throwsA(isA<PackException>()
            .having((e) => e.kind, 'kind', PackErrorKind.invalidPack)),
      );
      expect(await File('${tempDir.parent.path}/evil.txt').exists(), isFalse);
    });
  });

  group('installStatus / installedPacks / uninstall', () {
    test('Startzustand: nichts installiert', () async {
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: validZip('de')),
      );

      expect(await manager.installedPacks(), isEmpty);
      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
    });

    test('uninstall entfernt Marker und Sprachordner', () async {
      final zip = validZip('de');
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: zip),
      );
      await manager.install('de');

      await manager.uninstall('de');

      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
      expect(await manager.installedPacks(), isEmpty);
      expect(
          await File('${tempDir.path}/language_dict/de/de_to_be.json')
              .exists(),
          isFalse);
      expect(
          await File(
                  '${tempDir.path}/audio/de/verbs/de_audio_to_be/audio_ich_bin_m.mp3')
              .exists(),
          isFalse);
    });

    test('uninstall ist idempotent (kein Fehler, wenn nichts installiert)',
        () async {
      final manager = PackManagerImpl(
        fileService: fileService,
        httpClient: httpClientFor(zipBytes: validZip('de')),
      );

      await manager.uninstall('de');

      expect(await manager.installStatus('de'), PackInstallStatus.notInstalled);
    });
  });
}


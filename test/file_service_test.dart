import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_a_language/services/file_service.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';

void main() {
  // Echte Dateisystem-Tests via baseDirOverride (kein PathProvider-Mock).
  late Directory tmpDir;
  late FileServiceImpl fs;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('lal_fs_test_');
    fs = FileServiceImpl(baseDirOverride: tmpDir.path);
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  String abs(String rel) => '${tmpDir.path}/$rel';

  Future<void> writeFile(String rel, String content) async {
    final f = File(abs(rel));
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  group('loadJson – Semantik-Trennung (fehlt == Normalfall, korrupt == Fehler)', () {
    test('fehlende Datei liefert {} (kein Fehler)', () async {
      expect(
        await fs.loadJson('data_app/files_user/data_ghost.json'),
        isEmpty,
      );
    });

    test('unlesbares JSON ohne Backup wirft PersistenceException', () async {
      await writeFile('data_app/files_user/data_bad.json', '{ kaputt');

      expect(
        () => fs.loadJson('data_app/files_user/data_bad.json'),
        throwsA(isA<PersistenceException>()),
      );
    });

    test('JSON-Array [1,2,3] wirft PersistenceException statt TypeError', () async {
      await writeFile('data_app/files_user/data_arr.json', '[1,2,3]');

      // Kein Crash (TypeError), sondern kontrollierte Signalisierung.
      expect(
        () => fs.loadJson('data_app/files_user/data_arr.json'),
        throwsA(isA<PersistenceException>()),
      );
    });
  });

  group('loadJson – Backup-Rettung & Reparatur', () {
    test('korrupte Datei wird aus gültigem .bak gerettet', () async {
      const rel = 'data_app/files_user/data_alice.json';
      await writeFile(rel, '{ kaputt');
      await writeFile('$rel.bak', '{"u_name": "alice"}');

      final data = await fs.loadJson(rel);

      expect(data, {'u_name': 'alice'});
    });

    test(
        'JSON-Array [1,2,3] mit gültigem .bak → Rettung statt TypeError/Crash',
        () async {
      const rel = 'data_app/files_user/data_arr.json';
      await writeFile(rel, '[1,2,3]');
      await writeFile('$rel.bak', '{"u_name": "alice"}');

      final data = await fs.loadJson(rel);

      expect(data, {'u_name': 'alice'});
    });

    test('nach Rettung ist die Primärdatei repariert, .bak unangetastet',
        () async {
      const rel = 'data_app/files_user/data_alice.json';
      await writeFile(rel, '{ kaputt');
      await writeFile('$rel.bak', '{"u_name": "alice"}');

      final data = await fs.loadJson(rel);
      expect(data, {'u_name': 'alice'});

      // Primärdatei wurde atomar repariert (gültiges Objekt mit u_name).
      final repaired = jsonDecode(await File(abs(rel)).readAsString());
      expect((repaired as Map<String, dynamic>)['u_name'], 'alice');
      // .bak blieb inhaltlich unverändert (wird NICHT überschrieben).
      expect(await File(abs('$rel.bak')).readAsString(), '{"u_name": "alice"}');
      // Keine .tmp-Überreste.
      expect(await File(abs('$rel.tmp')).exists(), isFalse);
    });

    test('nächster saveJson rotiert das reparierte .bak korrekt', () async {
      const rel = 'data_app/files_user/data_alice.json';
      await writeFile(rel, '{ kaputt');
      await writeFile('$rel.bak', '{"u_name": "alice"}');
      await fs.loadJson(rel); // → repariert zu {"u_name":"alice"}

      await fs.saveJson(rel, {'u_name': 'alice', 'm_lang': 'de'});

      // Neuer Inhalt in der Primärdatei ...
      final prim = jsonDecode(await File(abs(rel)).readAsString());
      expect((prim as Map<String, dynamic>)['m_lang'], 'de');
      // ... und das .bak enthält die reparierte Vorversion (nicht die
      // ursprünglich korrupte Datei) → Rettung bleibt dauerhaft wirksam.
      final bak = jsonDecode(await File(abs('$rel.bak')).readAsString());
      expect((bak as Map<String, dynamic>)['u_name'], 'alice');
      expect(bak['m_lang'], isNull);
    });
  });

  group('saveJson – atomares Schreiben mit Backup', () {
    test('legt .bak der Vorversion an und schreibt ohne .tmp-Reste', () async {
      const rel = 'data_app/files_user/data_alice.json';
      await writeFile(rel, '{"old": true}');

      await fs.saveJson(rel, {'u_name': 'alice'});

      final prim = jsonDecode(await File(abs(rel)).readAsString());
      expect((prim as Map<String, dynamic>)['u_name'], 'alice');
      final bak = jsonDecode(await File(abs('$rel.bak')).readAsString());
      expect((bak as Map<String, dynamic>)['old'], true);
      expect(await File(abs('$rel.tmp')).exists(), isFalse);
    });

    test('Schreibfehler wird signalisiert statt geschluckt', () async {
      // Parent ist eine DATEI, kein Verzeichnis → writeAsString schlägt fehl.
      const rel = 'blocker/data_alice.json';
      final blocker = File(abs('blocker'));
      await blocker.parent.create(recursive: true);
      await blocker.writeAsString('x');

      expect(() => fs.saveJson(rel, {'u_name': 'alice'}),
          throwsA(isA<PersistenceException>()));
    });
  });

  group('Pfad-Containment (Path-Traversal-Abwehr, Ticket 1)', () {
    test('saveJson mit ../-Traversal wird abgelehnt, nichts wird geschrieben',
        () async {
      await expectLater(
        () => fs.saveJson('../escape.json', {'x': 1}),
        throwsA(isA<PathRejectedException>()),
      );
      expect(await File('${tmpDir.parent.path}/escape.json').exists(), isFalse);
    });

    test('loadJson mit ../-Traversal wird abgelehnt', () {
      expect(
        () => fs.loadJson('../../x.json'),
        throwsA(isA<PathRejectedException>()),
      );
    });

    test('absolute Pfade werden abgelehnt (Unix & Windows-Drive)', () async {
      expect(() => fs.loadJson('/etc/passwd'),
          throwsA(isA<PathRejectedException>()));
      expect(() => fs.saveJson('C:\\x.json', {'a': 1}),
          throwsA(isA<PathRejectedException>()));
      expect(() => fs.loadJson('C:/x.json'),
          throwsA(isA<PathRejectedException>()));
    });

    test('Backslash-Traversal wird abgelehnt', () {
      expect(
        () => fs.loadJson('data_app\\..\\..\\x.json'),
        throwsA(isA<PathRejectedException>()),
      );
    });

    test('NUL-Zeichen und leerer Pfad werden abgelehnt', () {
      expect(() => fs.loadJson('a\x00b.json'),
          throwsA(isA<PathRejectedException>()));
      expect(() => fs.loadJson(''), throwsA(isA<PathRejectedException>()));
    });

    test('`.`-Segmente werden abgelehnt', () {
      expect(() => fs.loadJson('./data_app/x.json'),
          throwsA(isA<PathRejectedException>()));
    });

    test('updateJsonKey lehnt Traversal-Pfade ab (voller Aufrufpfad)', () async {
      await writeFile('data_app/app_data.json', '{"a": 1}');
      await expectLater(
        () => fs.updateJsonKey('../app_data.json', 'k', 1),
        throwsA(isA<PathRejectedException>()),
      );
    });

    test('legitime Unterverzeichnisse bleiben nutzbar (Roundtrip)', () async {
      await fs.saveJson('a/b/c/data.json', {'x': 1});
      expect(await fs.loadJson('a/b/c/data.json'), {'x': 1});
    });

    test('Symlink-Ausbruch wird abgelehnt (Lesen, Schreiben, Löschen)', () async {
      if (Platform.isWindows) return; // Link-Erzeugung setzt unter Windows Rechte voraus
      final outside = await Directory.systemTemp.createTemp('lal_outside_');
      addTearDown(() => outside.delete(recursive: true));
      await Link('${tmpDir.path}/linked').create(outside.path);

      await expectLater(
        () => fs.saveJson('linked/x.json', {'x': 1}),
        throwsA(isA<PathRejectedException>()),
      );

      final outsideFile = File('${outside.path}/x.json');
      await outsideFile.parent.create(recursive: true);
      await outsideFile.writeAsString('{"y": 2}');

      await expectLater(
        () => fs.loadJson('linked/x.json'),
        throwsA(isA<PathRejectedException>()),
      );
      await expectLater(
        () => fs.deleteFile('linked/x.json'),
        throwsA(isA<PathRejectedException>()),
      );
      // Die Datei ausserhalb bleibt unangetastet.
      expect(await outsideFile.exists(), isTrue);
    });
    test('Leaf-Symlink: Zugriff über aufgelösten Zielpfad (TOCTOU #43)',
        () async {
      if (Platform.isWindows) return; // Link-Erzeugung setzt unter Windows Rechte voraus
      // Innerhalb liegendes Ziel – via Symlink im App-Verzeichnis referenziert.
      final internalDir = Directory('${tmpDir.path}/internal');
      await internalDir.create(recursive: true);
      final target = File('${internalDir.path}/data.json');
      await target.writeAsString('{"pinned": true}');

      // Lesen über den Leaf-Link trifft den kanonischen Zielpfad (innerhalb).
      await Link('${tmpDir.path}/link.json').create('${internalDir.path}/data.json');
      expect(await fs.loadJson('link.json'), {'pinned': true});

      // Schreiben über den Leaf-Link trifft das Ziel 'linkw.json' (der Link wird
      // NICHT durch eine reguläre Datei ersetzt) – Zugriff läuft über den
      // aufgelösten kanonischen Zielpfad, nicht über eine erneute Auflösung.
      final src = File('${tmpDir.path}/linkw.json');
      await src.writeAsString('{"old": 0}');
      await Link('${tmpDir.path}/link.json').delete();
      await Link('${tmpDir.path}/link.json').create(src.path);
      await fs.saveJson('link.json', {'written': 2});
      // Ziel (aufgelöster Pfad) wurde aktualisiert, der Link bleibt Symlink.
      expect(await src.readAsString(), contains('"written"'));
      expect(await Link('${tmpDir.path}/link.json').exists(), isTrue);
    });
  });

  group('discoverLanguageDicts – Laufzeit-Discovery (dynamische Sprachen)', () {
    test('findet nur Kandidaten-Sprachen, deren Dicts vorhanden sind', () async {
      // Dicts für de (Seed) und es (später hinzugefügt) + Fremdordner.
      await writeFile('language_dict/de/de_to_be.json', '{}');
      await writeFile('language_dict/es/es_to_go.json', '{}');
      await writeFile('language_dict/fremd/daten.json', '{}');

      final found = await fs.discoverLanguageDicts();

      expect(found, containsAll(['de', 'es']));
      // Nicht-Kandidat (fremd) erscheint nicht; Seed de/en/fr bleiben Sache des
      // Aufrufers (DataState), nicht dieser Discovery.
      expect(found, isNot(contains('fremd')));
    });

    test('leeres/fehlendes Verzeichnis liefert {}', () async {
      expect(await fs.discoverLanguageDicts(), isEmpty);
    });
  });

  group('initialize – Asset-Kopierfehler (Ticket #42)', () {
    setUp(StorageErrorBus.instance.clear);

    /// Loader, der für [assetPath] eine Exception wirft; sonst 2 Bytes '{}'.
    Future<ByteData> Function(String) loaderThrowingFor(String assetPath) =>
        (path) async {
      if (path == assetPath) {
        throw StateError('Asset nicht verfügbar (simuliert)');
      }
      return ByteData(2)..setUint8(0, 0x7B)..setUint8(1, 0x7D); // '{}'
    };

    test('vollständige Kopie: leere Fehlerliste, kein Bus-Eintrag', () async {
      final fsOk = FileServiceImpl(
        baseDirOverride: tmpDir.path,
        loadAsset: (path) async =>
            ByteData(2)..setUint8(0, 0x7B)..setUint8(1, 0x7D),
      );

      final failed = await fsOk.initialize();

      expect(failed, isEmpty);
      expect(StorageErrorBus.instance.takeLast(), isNull);
      // Basis-Datei wurde kopiert, .initialized-Flag gesetzt.
      expect(await File(abs('data_base/base_data.json')).exists(), isTrue);
      expect(await File(abs('.initialized')).exists(), isTrue);
    });

    test(
        'fehlendes Bundle-Asset wird still übersprungen (kein Kopierfehler, '
        'bewusste Toleranz für neue Sprachen)', () async {
      final fsPartial = FileServiceImpl(
        baseDirOverride: tmpDir.path,
        loadAsset: loaderThrowingFor('assets/language_dict/es/es_to_be.json'),
      );

      final failed = await fsPartial.initialize();

      // Fehlendes Asset ist KEIN Kopierfehler → nicht in der Fehlerliste,
      // keine Bus-Meldung; vorhandene Kopien laufen weiter.
      expect(failed, isEmpty);
      expect(StorageErrorBus.instance.takeLast(), isNull);
      expect(await File(abs('data_base/base_data.json')).exists(), isTrue);
      expect(await File(abs('language_dict/es/es_to_be.json')).exists(),
          isFalse);
    });

    test('Schreibfehler wird gemeldet: Pfad in Rückgabe + Bus-Eintrag', () async {
      // 'data_app' als DATEI anlegen → parent.create(recursive) für
      // app_data.json schlägt fehl (echter Kopierfehler, kein fehlendes Asset).
      final blocker = File(abs('data_app'));
      await blocker.parent.create(recursive: true);
      await blocker.writeAsString('blocker');

      final fsWriteError = FileServiceImpl(
        baseDirOverride: tmpDir.path,
        loadAsset: (path) async =>
            ByteData(2)..setUint8(0, 0x7B)..setUint8(1, 0x7D),
      );

      final failed = await fsWriteError.initialize();

      // Betroffener Pfad wird dem Aufrufer gemeldet ...
      expect(failed, contains('data_app/app_data.json'));
      // ... und der Bus signalisiert assetsCopyFailed (UI-Hinweis).
      expect(
          StorageErrorBus.instance.takeLast(),
          StorageErrorKind.assetsCopyFailed);
      // .initialized wird trotzdem gesetzt → App startet, Fehler sichtbar.
      expect(await File(abs('.initialized')).exists(), isTrue);
    });
  });

}
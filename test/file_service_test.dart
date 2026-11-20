import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_a_language/services/file_service.dart';

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
}
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_manager.dart';
import 'package:learn_a_language/models/app_models.dart';

import 'helpers/fakes.dart';

UserData _minimalUser(String username, String mLang) => UserData(
      uName: username,
      mLang: mLang,
      progress: const {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
      learnedLanguages: const [],
      language: const {},
      vocab: const {},
    );

void main() {
  group('UserManagerImpl.createUserFile', () {
    test('legt neuen Benutzer mit Default-Daten an', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      final result = await mgr.createUserFile('alice', 'de', {'custom': 1});

      expect(result, contains('erfolgreich'));
      final saved = fs.store['data_app/files_user/data_alice.json']!;
      expect(saved['u_name'], 'alice');
      expect(saved['m_lang'], 'de');
      expect(saved['language'], {'custom': 1});
      expect(saved['vocab'], isEmpty);
      expect(saved['progress'], isA<Map>());
    });

    test('verweigert doppelte Benutzernamen', () async {
      final fs = FakeFileService(store: {
        'data_app/files_user/data_bob.json': {'u_name': 'bob'},
      });
      final mgr = UserManagerImpl(fs);

      final result = await mgr.createUserFile('bob', 'de', {});

      expect(result, 'Benutzer bob existiert bereits.');
      expect(fs.store['data_app/files_user/data_bob.json'], {'u_name': 'bob'});
    });
  });

  group('UserManagerImpl loadUserdata / saveUserdata', () {
    test('gibt null zurück, wenn keine Datei existiert', () async {
      final mgr = UserManagerImpl(FakeFileService());

      expect(await mgr.loadUserdata('ghost'), isNull);
    });

    test('rundet UserData über das JSON ab', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      await mgr.saveUserdata('alice', _minimalUser('alice', 'de'));
      final loaded = await mgr.loadUserdata('alice');

      expect(loaded, isNotNull);
      expect(loaded!.uName, 'alice');
      expect(loaded.mLang, 'de');
    });
  });

  group('UserManagerImpl.addNewUserToList', () {
    test('fügt hinzu und dedupliziert', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      await mgr.addNewUserToList('alice');
      await mgr.addNewUserToList('alice');

      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.registeredUser, ['alice']);
    });
  });

  group('UserManagerImpl.deleteUser', () {
    test('leerer Benutzername liefert Hinweis', () async {
      final mgr = UserManagerImpl(FakeFileService());

      expect(await mgr.deleteUser('   '), 'Kein Benutzername angegeben.');
    });

    test('nicht registrierte Benutzer werden abgelehnt', () async {
      final fs = FakeFileService(store: {
        'data_app/app_data.json': {
          'registered_user': ['alice'],
        },
      });
      final mgr = UserManagerImpl(fs);

      final result = await mgr.deleteUser('bob');

      expect(result, "Benutzer 'bob' ist nicht registriert.");
    });

    test('entfernt eingeloggten Benutzer und setzt den Login zurück', () async {
      final fs = FakeFileService(store: {
        'data_app/app_data.json': {
          'registered_user': ['alice', 'bob'],
          'logged_u_name': 'alice',
          'user_logged_in': true,
        },
      });
      final mgr = UserManagerImpl(fs);

      final result = await mgr.deleteUser('alice');

      expect(result, contains('gelöscht'));
      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.registeredUser, ['bob']);
      expect(appData.loggedUName, '');
      expect(appData.userLoggedIn, false);
    });

    test('löscht auch die Benutzerdatei von der Platte', () async {
      final dir = await Directory.systemTemp.createTemp('lal_user_test_');
      addTearDown(() => dir.delete(recursive: true));
      final fs = FakeFileService(
        appDirValue: dir.path,
        store: {
          'data_app/app_data.json': {
            'registered_user': ['alice'],
          },
        },
      );
      final userFile = File('${dir.path}/data_app/files_user/data_alice.json');
      await userFile.parent.create(recursive: true);
      await userFile.writeAsString('{}');

      final mgr = UserManagerImpl(fs);
      final result = await mgr.deleteUser('alice');

      expect(result, "Benutzer 'alice' wurde gelöscht.");
      expect(await userFile.exists(), isFalse);
    });

    test('meldet, wenn die Datei nicht gelöscht werden kann', () async {
      final fs = FakeFileService(
        appDirThrows: true,
        store: {
          'data_app/app_data.json': {
            'registered_user': ['alice'],
          },
        },
      );
      final mgr = UserManagerImpl(fs);

      final result = await mgr.deleteUser('alice');

      expect(result, contains('Datei konnte nicht gelöscht werden'));
      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.registeredUser, isEmpty);
    });
  });

  group('UserManagerImpl.createUserFile – Username-Härtung', () {
    test('lehnt ungültige Benutzernamen ab', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      for (final name in [
        '   ',
        'Hans Müller',
        'a/b',
        '../x',
        'a\$b',
        'a.b',
        'user name',
        'u%näme',
      ]) {
        final result = await mgr.createUserFile(name, 'de', {});
        expect(result, contains('Ungültiger Benutzername'),
            reason: 'Name "$name" wurde nicht abgelehnt');
      }
      // Es darf KEINE Datei angelegt worden sein (kein Pfad-Traversal).
      expect(fs.store.keys.any((k) => k.startsWith('data_')), isFalse);
    });

    test('trimmt Benutzernamen vor dem Speichern', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      final result = await mgr.createUserFile('  alice_1  ', 'de', {});

      expect(result, contains('erfolgreich'));
      final saved = fs.store['data_app/files_user/data_alice_1.json']!;
      expect(saved['u_name'], 'alice_1');
    });

    test('meldet korrupte User-Datei als Fehler statt "existiert bereits"',
        () async {
      final fs = FakeFileService(
          corruptPaths: {'data_app/files_user/data_old.json'});
      final mgr = UserManagerImpl(fs);

      final result = await mgr.createUserFile('old', 'de', {});

      expect(result, contains('beschädigt'));
      expect(fs.store['data_app/files_user/data_old.json'], isNull);
    });
  });

  group('UserManagerImpl app_data-Rekonstruktion', () {
    test('unrettbare app_data: registered_user aus User-Dateien rekonstruiert',
        () async {
      final dir = await Directory.systemTemp.createTemp('lal_recover_');
      addTearDown(() => dir.delete(recursive: true));

      final fs = FakeFileService(
        appDirValue: dir.path,
        corruptPaths: {'data_app/app_data.json'},
      );
      final f1 = File('${dir.path}/data_app/files_user/data_anna.json');
      await f1.parent.create(recursive: true);
      await f1.writeAsString('{"u_name": "anna"}');
      final f2 = File('${dir.path}/data_app/files_user/data_bob.json');
      await f2.writeAsString('{"u_name": "bob"}');
      // Artefakte dürfen NICHT als Benutzer gezählt werden.
      await File('${dir.path}/data_app/files_user/data_junk.json.bak')
          .writeAsString('{"u_name": "junk"}');
      await File('${dir.path}/data_app/files_user/data_x.tmp')
          .writeAsString('{"u_name": "tmp"}');

      final mgr = UserManagerImpl(fs);
      await mgr.addNewUserToList('carla');

      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.registeredUser, ['anna', 'bob', 'carla']);
      // Die echten User-Dateien bleiben unangetastet.
      expect(await f1.readAsString(), contains('anna'));
      expect(await f2.readAsString(), contains('bob'));
    });
  });

  group('UserManagerImpl.deleteUser', () {
    test('entfernt auch die .bak-Datei des Benutzers', () async {
      final dir = await Directory.systemTemp.createTemp('lal_delbak_');
      addTearDown(() => dir.delete(recursive: true));
      final fs = FakeFileService(
        appDirValue: dir.path,
        store: {
          'data_app/app_data.json': {'registered_user': ['alice']},
        },
      );
      final userFile = File('${dir.path}/data_app/files_user/data_alice.json');
      await userFile.parent.create(recursive: true);
      await userFile.writeAsString('{"u_name": "alice"}');
      final bak = File('${dir.path}/data_app/files_user/data_alice.json.bak');
      await bak.writeAsString('{"u_name": "alice"}');

      final mgr = UserManagerImpl(fs);
      final result = await mgr.deleteUser('alice');

      expect(result, contains('gelöscht'));
      expect(await userFile.exists(), isFalse);
      expect(await bak.exists(), isFalse);
    });
  });

  group('UserManagerImpl Login-State', () {
    test('changeLoginState schreibt user_logged_in', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      await mgr.changeLoginState(newState: true);

      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.userLoggedIn, true);
    });

    test('setLoggedUname schreibt logged_u_name', () async {
      final fs = FakeFileService();
      final mgr = UserManagerImpl(fs);

      await mgr.setLoggedUname('alice');

      final appData = AppData.fromJson(fs.store['data_app/app_data.json']!);
      expect(appData.loggedUName, 'alice');
    });
  });
}

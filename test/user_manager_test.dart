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

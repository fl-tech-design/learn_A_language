import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/grammar_manager.dart';
import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/managers/session_manager.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/models/grammar_models.dart';

import 'helpers/fakes.dart';

const _sessionPath = 'data_app/last_session.json';

void main() {
  group('SessionManager', () {
    test('save -> load: Rundtrip mit allen Argument-Typen', () async {
      final store = <String, Map<String, dynamic>>{};
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      await manager.save(
        user: 'alice',
        navigationState: NavigationState()
          ..setWordMode('read')
          ..setSelectedCategoryId('grp_alltag'),
        routes: const [
          SessionRoute(name: '/learning'),
          SessionRoute(name: '/category', arguments: 'grp_alltag'),
          SessionRoute(
              name: '/collection',
              arguments:
                  CollectionScreenArgs(collectionId: 'weitere_verben', mode: 'learn')),
        ],
      );

      final snapshot = await manager.loadSnapshotForUser('alice');
      expect(snapshot, isNotNull);
      expect(snapshot!.user, 'alice');
      expect(snapshot.wordMode, 'read');
      expect(snapshot.selectedCategoryId, 'grp_alltag');
      expect(snapshot.routes, hasLength(3));
      expect(snapshot.routes[0].name, '/learning');
      expect(snapshot.routes[0].arguments, isNull);
      expect(snapshot.routes[1].name, '/category');
      expect(snapshot.routes[1].arguments, 'grp_alltag');
      final collectionArgs = snapshot.routes[2].arguments;
      expect(collectionArgs, isA<CollectionScreenArgs>());
      expect((collectionArgs! as CollectionScreenArgs).collectionId,
          'weitere_verben');
      expect((collectionArgs as CollectionScreenArgs).mode, 'learn');
    });

    test('E3: Session-Restore /category → /progress_group mit Kategorie-Id '
        'und activeCourseId', () async {
      final store = <String, Map<String, dynamic>>{};
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      final nav = NavigationState()
        ..setActiveCourse(const LanguageCourse(
          id: 'de_verben_a1',
          languageCode: 'de',
          languageName: 'Deutsch',
          level: 'A1',
          category: 'Verben',
          flagAsset: 'assets/images/flag_germany.png',
        ))
        ..setSelectedCategoryId('erste_verben');

      await manager.save(
        user: 'alice',
        navigationState: nav,
        routes: const [
          SessionRoute(name: '/learning'),
          SessionRoute(name: '/category', arguments: 'erste_verben'),
          SessionRoute(name: '/progress_group', arguments: 'grp_alltag'),
        ],
      );

      final snapshot = await manager.loadSnapshotForUser('alice');
      expect(snapshot, isNotNull);
      expect(snapshot!.activeCourseId, 'de_verben_a1');
      expect(snapshot.selectedCategoryId, 'erste_verben');
      expect(snapshot.routes, hasLength(3));
      expect(snapshot.routes[2].name, '/progress_group');
      expect(snapshot.routes[2].arguments, 'grp_alltag');
    });


    test('GrammarBlock-Argument wird per Id aufgelöst', () async {
      final store = <String, Map<String, dynamic>>{
        // Grammatik liegt seit der Sprachpaket-Auslagerung (Ticket #68) im
        // App-Speicher (relativer Pfad zu GrammarManagerImpl.assetPath).
        GrammarManagerImpl.assetPath: {
          'schema_version': '1.0.0',
          'content_version': '1',
          'framework': 'CEFR',
          'levels': ['A1'],
          'blocks': [
            {
              'id': 'b1',
              'level': 'A1',
              'category': 'cat',
              'order': 1,
              'title': {'de': 'Titel', 'en': 'Title'},
              'summary': {'de': 'Zusammenfassung', 'en': 'Summary'},
              'explanation': {'de': 'Erklaerung', 'en': 'Explanation'},
            },
          ],
        },
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      await manager.save(
        user: 'alice',
        navigationState: NavigationState(),
        routes: const [
          SessionRoute(name: '/grammardetail'),
        ],
      );

      // Ohne Argument ist /grammardetail ungültig -> wird verworfen.
      final snapshot = await manager.loadSnapshotForUser('alice');
      expect(snapshot, isNull);

      // Mit gültiger Block-Id (per Hand geschrieben, wie der Observer es tut):
      store[_sessionPath] = {
        'version': 1,
        'user': 'alice',
        'wordMode': 'new',
        'selectedCategoryId': null,
        'routes': [
          {
            'name': '/grammardetail',
            'args': {'type': 'grammar_block', 'id': 'b1'},
          },
        ],
      };
      final restored = await manager.loadSnapshotForUser('alice');
      expect(restored, isNotNull);
      expect(restored!.routes.single.arguments, isA<GrammarBlock>());
      expect((restored.routes.single.arguments! as GrammarBlock).id, 'b1');
    });

    test('Unbekannte Block-Id verwirft die Route', () async {
      final store = <String, Map<String, dynamic>>{
        _sessionPath: {
          'version': 1,
          'user': 'alice',
          'wordMode': 'new',
          'selectedCategoryId': null,
          'routes': [
            {
              'name': '/grammardetail',
              'args': {'type': 'grammar_block', 'id': 'gibt_es_nicht'},
            },
          ],
        },
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      final snapshot = await manager.loadSnapshotForUser('alice');
      // Keine gültige Route übrig -> kein Restore.
      expect(snapshot, isNull);
    });

    test('Session eines anderen Benutzers wird verworfen', () async {
      final store = <String, Map<String, dynamic>>{
        _sessionPath: {
          'version': 1,
          'user': 'alice',
          'wordMode': 'new',
          'selectedCategoryId': null,
          'routes': [
            {'name': '/learning'},
          ],
        },
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      final snapshot = await manager.loadSnapshotForUser('bob');
      expect(snapshot, isNull);
      // Fremde Session wurde gelöscht.
      expect(store[_sessionPath], isNull);
    });

    test('Korrupte/fehlende Session liefert null', () async {
      final store = <String, Map<String, dynamic>>{
        _sessionPath: {
          'version': 99,
          'user': 'alice',
          'routes': [
            {'name': '/learning'},
          ],
        },
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      expect(await manager.loadSnapshotForUser('alice'), isNull);

      // Fehlende Datei (leerer Store) -> null.
      final emptyFs = FakeFileService(store: {});
      final emptyManager = SessionManager(emptyFs, GrammarManagerImpl(emptyFs));
      expect(await emptyManager.loadSnapshotForUser('alice'), isNull);
    });

    test('Nicht wiederherstellbare Routen werden verworfen', () async {
      final store = <String, Map<String, dynamic>>{
        _sessionPath: {
          'version': 1,
          'user': 'alice',
          'wordMode': 'new',
          'selectedCategoryId': null,
          'routes': [
            {'name': '/unbekannt'},
            {'name': '/learning'},
          ],
        },
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      final snapshot = await manager.loadSnapshotForUser('alice');
      expect(snapshot, isNotNull);
      expect(snapshot!.routes.single.name, '/learning');
    });

    test('clear entfernt die Session-Datei', () async {
      final store = <String, Map<String, dynamic>>{
        _sessionPath: {'version': 1, 'user': 'alice', 'routes': []},
      };
      final fs = FakeFileService(store: store);
      final manager = SessionManager(fs, GrammarManagerImpl(fs));

      await manager.clear();
      expect(store[_sessionPath], isNull);
    });
  });
}

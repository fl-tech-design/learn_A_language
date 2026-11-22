import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';

import 'helpers/fakes.dart';

UserData _userData({
  String uName = 'alice',
  String mLang = 'de',
  Map<String, VocabEntry> vocab = const {},
  Map<String, Map<String, VocabEntry>> vocabByLang = const {},
  List<String> selectedCourses = const [],
  Map<String, int> progress = const {
    'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0,
  },
}) =>
    UserData(
      uName: uName,
      mLang: mLang,
      progress: progress,
      learnedLanguages: const [],
      language: const {},
      vocab: vocab,
      vocabByLang: vocabByLang.isNotEmpty ? vocabByLang : null,
      selectedCourses: selectedCourses,
    );

VocabEntry _v(String key) => VocabEntry(
      key: key,
      word: key,
      translation: key,
      examples: const [],
      examplesNative: const [],
    );

void main() {
  // Kurse der Sprache 'de' – werden automatisch gewählt, wenn der Wortschatz
  // unter 'de' liegt (Kurs-basiertes Modell).
  final deCourses = availableCourses.entries
      .where((e) => e.value.languageCode == 'de')
      .map((e) => e.key)
      .toList();

  group('UserState.login', () {
    test('lädt Daten, initialisiert Vokabeln und wählt Kurse automatisch',
        () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(vocab: {'k': _v('k')}));
      final vm = FakeVocabManager();
      final state = UserState(userManager: um, vocabManager: vm);

      await state.login('alice');

      expect(um.userLoggedIn, true);
      expect(um.loggedUName, 'alice');
      expect(state.userData!.uName, 'alice');
      expect(vm.initCount, 1);
      expect(vm.migrateCount, 1);
      // Wortschatz liegt unter 'de' → die deutschen Kurse werden automatisch
      // gewählt (Kurs-basiertes Modell statt mLang-Kopplung).
      expect(um.lastSaved!.selectedCourses, deCourses);
      expect(state.selectedCourseIds, deCourses);
    });
  });

  group('UserState.login – Persistenz-Fehler', () {
    test('korrupte User-Datei: Fehlertext, kein Halblogin, Warnung einmalig',
        () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager(unreadableUsers: {'alice'});
      final vm = FakeVocabManager();
      final state = UserState(userManager: um, vocabManager: vm);

      final error = await state.login('alice');

      expect(error, isNotNull);
      // Kein persistierter Halblogin in app_data.
      expect(um.userLoggedIn, isFalse);
      expect(um.loggedUName, isEmpty);
      expect(state.userData, isNull);
      // Warnung einmalig konsumierbar (kein SnackBar-Spam).
      expect(StorageErrorBus.instance.takeLast(),
          StorageErrorKind.userDataUnloadable);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });

    test('Erfolg persistiert Login-State erst nach validierten Daten', () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager();
      um.seed('alice', _userData());
      final vm = FakeVocabManager();
      final state = UserState(userManager: um, vocabManager: vm);

      final error = await state.login('alice');

      expect(error, isNull);
      expect(um.userLoggedIn, isTrue);
      expect(um.loggedUName, 'alice');
      expect(state.userData, isNotNull);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });
  });

  group('UserState.registerUser', () {
    test('erstellt Benutzer, loggt ein und initialisiert Vokabeln', () async {
      final um = FakeUserManager();
      final vm = FakeVocabManager(languageDicts: {
        'en': {
          'to_go': {'infinitive': 'go'},
        },
      });
      final state = UserState(userManager: um, vocabManager: vm);

      final result = await state.registerUser('carl', 'de');

      expect(result, isNull);
      expect(um.userLoggedIn, true);
      expect(um.loggedUName, 'carl');
      // Kein automatischer Zielsprachen-Init im Kurs-basierten Modell: Der
      // Wortschatz entsteht erst, wenn ein Kurs hinzugefügt wird.
      expect(vm.loadDictCount, 0);
      expect(vm.initCount, 0);
      expect(vm.migrateCount, 0);
      expect(state.userData!.uName, 'carl');
    });

    test('bricht ab, wenn der Benutzer bereits existiert', () async {
      final um = FakeUserManager();
      um.seed('carl', _userData(uName: 'carl'));
      final state =
          UserState(userManager: um, vocabManager: FakeVocabManager());

      final result = await state.registerUser('carl', 'de');

      expect(result, contains('existiert bereits'));
      expect(um.userLoggedIn, false);
    });
  });

  group('UserState Kurs-Getter', () {
    test('leitet Kurse aus den vorhandenen Wortschatz-Sprachen ab', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(vocab: {'k': _v('k')}));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      expect(state.selectedCourseIds, deCourses);
    });

    test('availableNewCourses schließt selektierte aus', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(selectedCourses: ['de_verben_a1']));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      expect(state.selectedCourseIds, ['de_verben_a1']);
      final newIds = state.availableNewCourses.map((c) => c.id).toList();
      expect(newIds, isNot(contains('de_verben_a1')));
      expect(newIds, contains('en_verben_a1'));
      expect(newIds.length, availableCourses.length - 1);
    });

    test('ohne Vokabeln und Kurse bleibt die Liste leer', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData());
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      expect(state.selectedCourseIds, isEmpty);
    });
  });

  group('UserState.addCourse', () {
    test('fügt Kurse hinzu und schreibt sie in die UserData', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData());
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.addCourse('en_verben_a1');

      expect(state.selectedCourseIds, ['en_verben_a1']);
      expect(um.lastSaved!.selectedCourses, ['en_verben_a1']);
    });

    test('ignoriert Duplikate und unbekannte Kurs-IDs', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData());
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.addCourse('en_verben_a1');
      await state.addCourse('en_verben_a1');
      await state.addCourse('gibtEsNicht');

      expect(state.selectedCourses.map((c) => c.id), ['en_verben_a1']);
    });
  });

  group('UserState.removeCourse', () {
    test('entfernt einen Kurs aus der Auswahl', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(
          selectedCourses: ['de_verben_a1', 'en_verben_a1']));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.removeCourse('de_verben_a1');

      expect(state.selectedCourseIds, ['en_verben_a1']);
      expect(um.lastSaved!.selectedCourses, ['en_verben_a1']);
    });

    test('setzt den Level-Fortschritt des entfernten Kurses zurück', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(
            selectedCourses: ['en_verben_a1', 'en_verben_a2'],
            progress: const {
              'A1': 5,
              'A2': 3,
              'B1': 0,
              'B2': 0,
              'C1': 0,
              'C2': 0,
            },
            vocab: {'k': _v('k')},
          ));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.removeCourse('en_verben_a1');

      expect(state.userData!.progress['A1'], 0);
      // Vokabeln bleiben, weil noch ein Kurs derselben Sprache gewählt ist.
      expect(state.userData!.vocabByLang, isNotEmpty);
    });

    test('löscht Vokabeln, wenn der letzte Kurs der Sprache entfernt wird',
        () async {
      final um = FakeUserManager();
      // Wortschatz unter 'en' – der Sprache des zu entfernenden Kurses.
      um.seed('alice', _userData(selectedCourses: ['en_verben_a1'],
          vocabByLang: {
            'en': {'k': _v('k')},
          }));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.removeCourse('en_verben_a1');

      expect(state.selectedCourseIds, isEmpty);
      expect(state.userData!.vocabByLang, isEmpty);
    });

    test('behält Vokabeln, wenn nur ein fremdsprachiger Kurs übrig bleibt',
        () async {
      final um = FakeUserManager();
      // Wortschatz getrennt je Sprache: 'de' (zu entfernender Kurs) und
      // 'en' (bleibender Kurs der verbleibenden Sprache).
      um.seed('alice', _userData(
            selectedCourses: ['de_verben_a1', 'en_verben_a1'],
            vocabByLang: {
              'de': {'k': _v('k')},
              'en': {'k2': _v('k2')},
            },
          ));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      // Nur der Wortschatz der entfernten Sprache ('de') wird gelöscht; der
      // verbleibende Kurs 'en' behält seinen eigenen Wortschatz.
      await state.removeCourse('de_verben_a1');

      expect(state.selectedCourseIds, ['en_verben_a1']);
      expect(state.userData!.vocabByLang.containsKey('de'), isFalse);
      expect(state.userData!.vocabByLang['en'], isNotEmpty);
    });

    test('ignoriert unbekannte und nicht gewählte Kurs-IDs', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(selectedCourses: ['en_verben_a1']));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      await state.removeCourse('gibtEsNicht');
      await state.removeCourse('en_verben_a2');

      expect(state.selectedCourseIds, ['en_verben_a1']);
      expect(um.saveCount, 0);
    });
  });

  group('UserState – korrupte User-Datei (Ticket 3 Härtung)', () {
    test('addCourse bei Korruption: kein Crash, eine Warnung', () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager();
      um.seed('alice', _userData(selectedCourses: ['en_verben_a1']));
      final state =
          UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      // Datei wird ab jetzt als korrupt/unlesbar gemeldet.
      um.unreadableUsers.add('alice');
      StorageErrorBus.instance.clear();

      await state.addCourse('de_verben_a1');

      // Kein Crash; genau eine konsumierbare Warnung.
      expect(StorageErrorBus.instance.takeLast(),
          StorageErrorKind.userDataUnloadable);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });

    test('removeCourse bei Korruption: kein Crash, eine Warnung', () async {
      StorageErrorBus.instance.clear();
      final um = FakeUserManager();
      um.seed('alice', _userData(selectedCourses: ['en_verben_a1']));
      final state =
          UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      um.unreadableUsers.add('alice');
      StorageErrorBus.instance.clear();

      await state.removeCourse('en_verben_a1');

      expect(StorageErrorBus.instance.takeLast(),
          StorageErrorKind.userDataUnloadable);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });

    test('_autoSelectCourses bei Korruption: kein Crash, eine Warnung',
        () async {
      StorageErrorBus.instance.clear();
      // login lädt UserData bei Index 0, _loadUserData bei 1 und
      // _autoSelectCourses bei 2 – nur der letzte soll hier scheitern.
      final um = FakeUserManager(failOnLoadIndex: const {2});
      um.seed('alice', _userData(vocab: {'k': _v('k')})); // vocab, keine Kurse
      final state =
          UserState(userManager: um, vocabManager: FakeVocabManager());

      final error = await state.login('alice');

      // Login selbst erfolgreich – nur Auto-Select schlägt fehl, ohne Crash.
      expect(error, isNull);
      expect(StorageErrorBus.instance.takeLast(),
          StorageErrorKind.userDataUnloadable);
      expect(StorageErrorBus.instance.takeLast(), isNull);
    });
  });
}

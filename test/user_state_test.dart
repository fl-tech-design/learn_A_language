import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/models/app_models.dart';

import 'helpers/fakes.dart';

UserData _userData({
  String uName = 'alice',
  String mLang = 'de',
  Map<String, VocabEntry> vocab = const {},
  List<String> selectedCourses = const [],
}) =>
    UserData(
      uName: uName,
      mLang: mLang,
      progress: const {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0},
      learnedLanguages: const [],
      language: const {},
      vocab: vocab,
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
  // Zielsprachen-Kurse ('en'), die bei mLang 'de' automatisch ausgewählt
  // werden, sobald Vokabeln vorhanden sind.
  final enCourses = availableCourses.entries
      .where((e) => e.value.languageCode == 'en')
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
      // mLang 'de' → Zielsprache 'en' → alle en-Kurse werden gespeichert
      expect(um.lastSaved!.selectedCourses, enCourses);
      expect(state.selectedCourseIds, enCourses);
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
      expect(vm.loadDictCount, 1);
      expect(vm.initCount, 1);
      expect(vm.migrateCount, 1);
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
    test('leitet Kurse aus der Zielsprache ab und speichert sie', () async {
      final um = FakeUserManager();
      um.seed('alice', _userData(vocab: {'k': _v('k')}));
      final state = UserState(userManager: um, vocabManager: FakeVocabManager());
      await state.login('alice');

      expect(state.selectedCourseIds, enCourses);
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
}

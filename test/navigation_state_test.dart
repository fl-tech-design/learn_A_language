import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/navigation_state.dart';
import 'package:learn_a_language/models/app_models.dart';

/// Regressionstests für die deterministische Sprachauflösung (Ticket #74).
///
/// Ohne gesetzten aktiven Kurs-Kontext bestimmte früher die
/// Einfügereihenfolge von `vocabByLang` (z. B. immer `'de'` zuerst) die
/// Kurssprache – für Griechisch/Russisch-Nutzer luden Lern-/Spiel-Screens in
/// der falschen Sprache („Keine gelesenen Wörter zum spielen").
void main() {
  UserData makeUserData({
    List<String> selectedCourses = const [],
    Map<String, Map<String, VocabEntry>>? vocabByLang,
  }) =>
      UserData(
        uName: 'alice',
        mLang: 'de',
        progress: const {},
        learnedLanguages: const [],
        language: const {},
        vocabByLang: vocabByLang ?? const {},
        selectedCourses: selectedCourses,
      );

  group('NavigationState.resolveActiveLang (Ticket #74)', () {
    test('ohne aktiven Kurs: erste gewählte Kurssprache statt keys.first',
        () {
      refreshAvailableCourses({'de', 'el', 'ru'});
      final nav = NavigationState();
      // 'de' wurde zuerst angelegt – die Einfügereihenfolge würde 'de'
      // liefern; die Kurswahl des Nutzers bestimmt aber 'el'.
      final userData = makeUserData(
        selectedCourses: const ['el_verben_a1', 'de_verben_a1'],
        vocabByLang: const {'de': {}, 'el': {}},
      );

      expect(nav.resolveActiveLang(userData), 'el');
    });

    test('aktiver Kurs-Kontext hat Vorrang vor der Kurswahl', () {
      refreshAvailableCourses({'de', 'el', 'ru'});
      final nav = NavigationState();
      nav.setActiveCourse(availableCourses['ru_verben_a1']!);
      final userData = makeUserData(
        selectedCourses: const ['el_verben_a1', 'de_verben_a1'],
        vocabByLang: const {'de': {}, 'el': {}},
      );

      expect(nav.resolveActiveLang(userData), 'ru');
    });

    test('ohne Kurse: Fallback auf ersten Sprach-Bucket', () {
      final nav = NavigationState();
      final userData = makeUserData(vocabByLang: const {'ru': {}, 'de': {}});

      expect(nav.resolveActiveLang(userData), 'ru');
    });

    test('ohne Daten: Default de', () {
      expect(NavigationState().resolveActiveLang(null), 'de');
    });
  });
}

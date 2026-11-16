import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/models/app_models.dart';

void main() {
  group('AppData Roundtrip (toJson → fromJson)', () {
    test('volles AppData-Objekt bleibt nach Roundtrip identisch', () {
      final appData = AppData(
        registeredUser: const ['alice', 'bob'],
        loggedUName: 'alice',
        userLoggedIn: true,
        wordsPerSession: 5,
      );

      final roundtripped = AppData.fromJson(appData.toJson());

      expect(roundtripped.registeredUser, ['alice', 'bob']);
      expect(roundtripped.loggedUName, 'alice');
      expect(roundtripped.userLoggedIn, true);
      expect(roundtripped.stayLoggedIn, true);
      expect(roundtripped.wordsPerSession, 5);
    });
  });
}
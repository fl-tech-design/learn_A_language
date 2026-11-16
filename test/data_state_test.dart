import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/data_state.dart';

import 'helpers/fakes.dart';

void main() {
  group('DataState', () {
    test('appLocale bildet Sprachcodes ab, Default de', () {
      final state = DataState(FakeFileService());

      expect(state.appLocale, const Locale('de'));
    });

    test('loadAppData liest base_data und übersetzt Farbwerte', () async {
      final fs = FakeFileService(store: {
        'data_base/base_data.json': {
          'curr_lang': 'en',
          'colors': {
            'color1': [255, 0, 0, 255],
            'color2': [0, 128, 255, 255],
            'color3': [75, 75, 75, 255],
          },
        },
        'data_app/app_data.json': {
          'words_per_session': 7,
          'user_logged_in': true,
        },
      });
      final state = DataState(fs);

      await state.loadAppData();

      expect(state.appLocale, const Locale('en'));
      expect(state.appData.wordsPerSession, 7);
      expect(state.appData.userLoggedIn, true);
      expect(state.color1, [1.0, 0.0, 0.0, 1.0]);
      expect(state.color2[1], closeTo(128 / 255, 1e-9));
      expect(state.color3[0], closeTo(75 / 255, 1e-9));
    });

    test('fehlende Dateien liefern Defaults statt Fehler', () async {
      final state = DataState(FakeFileService());

      await state.loadAppData();

      expect(state.appLocale, const Locale('de'));
      expect(state.appData.wordsPerSession, 3);
      expect(state.appData.userLoggedIn, false);
    });

    test('nicht listenförmige colors → weiße Fallback-Farbe', () async {
      final fs = FakeFileService(store: {
        'data_base/base_data.json': {
          'colors': {
            'color1': 'kaputt',
          },
        },
      });
      final state = DataState(fs);

      await state.loadAppData();

      expect(state.color1, [1.0, 1.0, 1.0, 1.0]);
    });

    test('changeLanguage normalisiert Namen und aktualisiert curr_lang',
        () async {
      final fs = FakeFileService(store: {
        'data_base/base_data.json': {'curr_lang': 'de'},
      });
      final state = DataState(fs);
      await state.loadAppData();

      await state.changeLanguage('Englisch');

      expect(fs.store['data_base/base_data.json']!['curr_lang'], 'en');
      expect(state.appLocale, const Locale('en'));
    });

    test('changeLanguage ignoriert unbekannte Werte', () async {
      final fs = FakeFileService(store: {
        'data_base/base_data.json': {'curr_lang': 'de'},
      });
      final state = DataState(fs);
      await state.loadAppData();

      await state.changeLanguage('Klingonisch');

      expect(fs.store['data_base/base_data.json']!['curr_lang'], 'de');
      expect(state.appLocale, const Locale('de'));
    });
  });
}

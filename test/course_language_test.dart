import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/managers/user_state.dart';
import 'package:learn_a_language/managers/vocab_manager.dart';
import 'package:learn_a_language/models/app_models.dart';
import 'package:learn_a_language/services/audio_service.dart';

import 'helpers/fakes.dart';

/// Minimal-Wörterbuch im neuen Listen-Schema (1 Verb, 1 Person-Position),
/// inkl. Audio-Pfaden der jeweiligen Sprache.
Map<String, dynamic> _verb({
  required String infinitive,
  required String trans0,
  required String audioPath,
}) =>
    {
      'infinitive': infinitive,
      'present': {
        'translations': [trans0, '', '', '', '', ''],
        'examples': [
          ['', '', ''],
          ['', '', ''],
          ['', '', ''],
          ['', '', ''],
          ['', '', ''],
          ['', '', ''],
        ],
        'audio': [
          ['$audioPath/m.mp3', '', '', '', '', ''],
          ['$audioPath/f.mp3', '', '', '', '', ''],
        ],
      },
    };

/// Bundle-Fake, das auf den Asset-Pfad antwortet (pro Sprache).
class _PerPathBundle extends FakeFileService {
  final Map<String, Map<String, dynamic>> byPath;
  _PerPathBundle({required this.byPath})
      : super(store: const {}, languageDicts: const {}, appDirValue: '');

  @override
  Future<Map<String, dynamic>> loadBundledJson(String assetPath) async =>
      byPath[assetPath] ?? const {};
}

void main() {
  group('Kurs-basiertes Sprachenmodell (Bug: de-Kurs lud en-Daten)', () {
    Future<UserState> _stateWith({
      required Map<String, Map<String, dynamic>> languageDicts,
    }) async {
      final userMgr = FakeUserManager();
      userMgr.seed('u', UserData(
            uName: 'u',
            mLang: 'de',
            progress: const {},
            learnedLanguages: const [],
            language: const {},
          ));
      final state = UserState(
        userManager: userMgr,
        vocabManager: VocabManagerImpl(userMgr, FakeFileService(languageDicts: languageDicts)),
      );
      await state.login('u'); // lädt UserData; ohne Kurse/Wordschatz kein Init
      return state;
    }

    test('de-Kurs (mLang de) lädt deutsche Wörter, nicht englische',
        () async {
      final state = await _stateWith(languageDicts: {
        'de': {'to_go': _verb(infinitive: 'gehen', trans0: 'ich gehe', audioPath: 'audio/de/verben/gehen/audio_ich_gehe')},
        'en': {'to_go': _verb(infinitive: 'go', trans0: 'I go', audioPath: 'audio/en/to go/audio_i_go')},
        'fr': {'to_go': _verb(infinitive: 'aller', trans0: "je vais", audioPath: 'audio/fr/aller/audio_je_vais')},
      });

      await state.addCourse('de_verben_a1');

      final byLang = state.userData!.vocabByLang;
      // Deutscher Wortschatz ist befüllt, englischer NICHT.
      expect(byLang.containsKey('de'), isTrue);
      expect(byLang.containsKey('en'), isFalse);
      expect(byLang['de']!['to_go_present_0']!.word, 'ich gehe');
    });

    test('fr-Kurs (mLang de) lädt französische Wörter', () async {
      final state = await _stateWith(languageDicts: {
        'de': {'to_go': _verb(infinitive: 'gehen', trans0: 'ich gehe', audioPath: 'audio/de/verben/gehen/audio_ich_gehe')},
        'en': {'to_go': _verb(infinitive: 'go', trans0: 'I go', audioPath: 'audio/en/to go/audio_i_go')},
        'fr': {'to_go': _verb(infinitive: 'aller', trans0: "je vais", audioPath: 'audio/fr/aller/audio_je_vais')},
      });

      await state.addCourse('fr_verben_a1');

      final byLang = state.userData!.vocabByLang;
      expect(byLang.containsKey('fr'), isTrue);
      expect(byLang.containsKey('en'), isFalse);
      expect(byLang['fr']!['to_go_present_0']!.word, 'je vais');
    });

    test('Audio folgt der Kurssprache (de vs. en)', () async {
      final fake = _PerPathBundle(byPath: {
        'assets/language_dict/de/de_to_go.json':
            _verb(infinitive: 'gehen', trans0: 'ich gehe', audioPath: 'audio/de/verben/gehen/audio_ich_gehe'),
      });
      final audio = AudioService(fileService: fake);

      // Für 'de' existiert Audio (Pfade aus dem deutschen Wörterbuch) …
      expect(
          await audio.hasAudio(
              langCode: 'de', verbKey: 'to_go', tense: 'present', person: 0),
          isTrue);
      // … für 'en' nicht (kein en-Wörterbuch geladen).
      expect(
          await audio.hasAudio(
              langCode: 'en', verbKey: 'to_go', tense: 'present', person: 0),
          isFalse);
    });
  });
}
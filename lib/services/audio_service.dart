import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import 'file_service.dart';

/// Spielt Verb-Konjugations-Audio (Aussprache von Wort/Übersetzung) ab.
///
/// Die Audiodateien liegen pro Verb/Zeitform in der jeweiligen language_dict-JSON
/// unter dem Schlüssel `audio`: ein Array aus ZWEI parallel gefüllten Listen
/// (Index 0 = Stimme m, Index 1 = Stimme f), je 6 Einträge in
/// Konjugationsreihenfolge – identisch zur `translations`-Liste. Die Pfade sind
/// assets-relativ (z. B. `audio/de/verbs/de_audio_to_work/audio_ich_arbeite_m.mp3`) und
/// werden direkt an [AssetSource] übergeben; audioplayers ergänzt `assets/`.
///
/// Die Zielsprache wird NICHT mehr aus der Muttersprache abgeleitet: [langCode]
/// kommt vom Kurs-Kontext und bestimmt, welche Wörterbuch-JSON (und damit
/// welche Audio-Pfade) geladen wird.
///
/// Wird pro Wort abgespielt (Stimme zufällig 0/1), mit automatischem Fallback
/// auf die jeweils andere Stimme, falls für die gewürfelte Stimme keine Datei
/// existiert. Fehlt für beide Stimmen ein Pfad, wird lautlos nichts getan.
class AudioService {
  /// Standard-Abspieltempo (Ticket #32): global 0.98, damit manche
  /// TTS-Ausgaben nicht „zu schnell“ wirken.
  static const double normalTempo = 0.98;

  /// Langsames Abspieltempo für den Slow-Button (Anfänger-Modus, Ticket #32,
  /// angepasst auf 0.65 in Ticket #62: spürbar langsamer, aber nicht verzerrt).
  static const double slowTempo = 0.65;

  final FileService _fileService;
  final Random _random = Random();
  final Map<String, Map<String, dynamic>> _verbCache = {};
  AudioPlayer? _player;

  AudioService({required FileService fileService})
      : _fileService = fileService;

  Future<Map<String, dynamic>> _loadVerb(String lang, String verbKey) async {
    final cacheKey = '$lang/$verbKey';
    final cached = _verbCache[cacheKey];
    if (cached != null) return cached;
    final data = await _fileService
        .loadBundledJson('assets/language_dict/$lang/${lang}_$verbKey.json');
    _verbCache[cacheKey] = data;
    return data;
  }

  String _at(dynamic audio, int voice, int person) {
    if (audio is! List || audio.length <= voice) return '';
    final list = audio[voice];
    if (list is List && person >= 0 && person < list.length) {
      final p = list[person];
      if (p is String) return p;
    }
    return '';
  }

  /// Liefert die assets-relativen Pfade beider Stimmen (m, f) zum Eintrag.
  ///
  /// Rückgabe als Record `(m, f)`; leere Strings bedeuten „keine Datei“.
  Future<(String, String)> _bothPaths(String lang, String verbKey,
      String tense, int person) async {
    if (verbKey.isEmpty) return ('', '');
    final verb = await _loadVerb(lang, verbKey);
    final tenseData = verb[tense];
    if (tenseData is! Map) return ('', '');
    final audio = tenseData['audio'];
    if (audio is! List || audio.length < 2) return ('', '');
    return (
      _at(audio, 0, person),
      _at(audio, 1, person),
    );
  }

  /// True, wenn für den Eintrag in [langCode] mindestens ein Audio existiert.
  Future<bool> hasAudio({required String langCode, required String verbKey,
      required String tense, required int person}) async {
    final (m, f) = await _bothPaths(langCode, verbKey, tense, person);
    return m.isNotEmpty || f.isNotEmpty;
  }

  /// Spielt die Aussprache zum Eintrag ab (Stimme zufällig m/f, mit Fallback).
  ///
  /// [tempo] ist die Abspielgeschwindigkeit (1.0 = Original); Standard siehe
  /// [normalTempo], der Slow-Button nutzt [slowTempo] (Ticket #32).
  /// Plattformen ohne `setPlaybackRate` spielen unverändert (still abgefangen).
  Future<void> play({required String langCode, required String verbKey,
      required String tense, required int person,
      double tempo = normalTempo}) async {
    if (verbKey.isEmpty) return;
    final (m, f) = await _bothPaths(langCode, verbKey, tense, person);
    final voice = _random.nextInt(2);
    var path = voice == 0 ? m : f;
    if (path.isEmpty) path = voice == 0 ? f : m;
    if (path.isEmpty) return; // Stille statt Fehler.

    _player ??= AudioPlayer();
    try {
      await _player!.setPlaybackRate(tempo);
    } catch (_) {
      // Nicht unterstützte Plattform: mit Original-Tempo weiter.
    }
    await _player!.stop();
    await _player!.play(AssetSource(path));
  }

  /// Stoppt die laufende Wiedergabe (vor Screen-Wechsel).
  Future<void> stop() async {
    if (_player != null) await _player!.stop();
  }

  Future<void> dispose() async {
    if (_player != null) await _player!.dispose();
    _verbCache.clear();
  }
}
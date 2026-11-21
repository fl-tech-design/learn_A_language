import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import 'file_service.dart';
import '../managers/user_manager.dart';

/// Spielt Verb-Konjugations-Audio (Aussprache von Wort/Übersetzung) ab.
///
/// Die Audiodateien liegen pro Verb/Zeitform in der jeweiligen language_dict-JSON
/// unter dem Schlüssel `audio`: ein Array aus ZWEI parallel gefüllten Listen
/// (Index 0 = Stimme m, Index 1 = Stimme f), je 6 Einträge in
/// Konjugationsreihenfolge – identisch zur `translations`-Liste. Die Pfade sind
/// assets-relativ (z. B. `audio/de/verben/arbeiten/audio_ich_arbeite_m.mp3`) und
/// werden direkt an [AssetSource] übergeben; audioplayers ergänzt `assets/`.
///
/// Wird pro Wort abgespielt (Stimme zufällig 0/1), mit automatischem Fallback
/// auf die jeweils andere Stimme, falls für die gewürfelte Stimme keine Datei
/// existiert. Fehlt für beide Stimmen ein Pfad, wird lautlos nichts getan.
class AudioService {
  final FileService _fileService;
  final UserManager _userManager;
  final Random _random = Random();
  final Map<String, Map<String, dynamic>> _verbCache = {};
  final Map<String, String> _targetLangCache = {};
  AudioPlayer? _player;

  AudioService({
    required FileService fileService,
    required UserManager userManager,
  })  : _fileService = fileService,
        _userManager = userManager;

  /// Zielsprache (die Sprache der gezeigten Konjugationen) eines Lernenden.
  /// Abgeleitet aus der Muttersprache: de-Muttersprachler lernen en und umgekehrt.
  static String targetForMotherTongue(String motherTongue) =>
      motherTongue == 'de' ? 'en' : 'de';

  Future<String> _targetLanguage(String username) async {
    final cached = _targetLangCache[username];
    if (cached != null) return cached;
    var target = 'de'; // Vernünftiger Default (meiste Inhalte sind Deutsch).
    try {
      final ud = await _userManager.loadUserdata(username);
      if (ud != null) target = targetForMotherTongue(ud.mLang);
    } catch (_) {
      // read-only best effort – ohne Benutzerdaten fällt es auf 'de' zurück.
    }
    _targetLangCache[username] = target;
    return target;
  }

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
  Future<(String, String)> _bothPaths(String target, String verbKey,
      String tense, int person) async {
    if (verbKey.isEmpty) return ('', '');
    final verb = await _loadVerb(target, verbKey);
    final tenseData = verb[tense];
    if (tenseData is! Map) return ('', '');
    final audio = tenseData['audio'];
    if (audio is! List || audio.length < 2) return ('', '');
    return (
      _at(audio, 0, person),
      _at(audio, 1, person),
    );
  }

  /// True, wenn für den Eintrag mindestens ein Audio existiert (Replay-Button).
  Future<bool> hasAudio({required String username, required String verbKey,
      required String tense, required int person}) async {
    final target = await _targetLanguage(username);
    final (m, f) = await _bothPaths(target, verbKey, tense, person);
    return m.isNotEmpty || f.isNotEmpty;
  }

  /// Spielt die Aussprache zum Eintrag ab (Stimme zufällig m/f, mit Fallback).
  Future<void> play({required String username, required String verbKey,
      required String tense, required int person}) async {
    if (verbKey.isEmpty) return;
    final target = await _targetLanguage(username);
    final (m, f) = await _bothPaths(target, verbKey, tense, person);
    final voice = _random.nextInt(2);
    var path = voice == 0 ? m : f;
    if (path.isEmpty) path = voice == 0 ? f : m;
    if (path.isEmpty) return; // Stille statt Fehler.

    _player ??= AudioPlayer();
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
    _targetLangCache.clear();
  }
}
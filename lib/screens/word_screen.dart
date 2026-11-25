import '../routes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/data_state.dart';
import '../services/audio_service.dart';
import '../managers/navigation_state.dart';
import '../managers/user_state.dart';
import '../managers/vocab_queries.dart';
import '../models/app_models.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/info_dialog.dart';
import '../dialogs/limit_dialog.dart';
import '../l10n/app_localizations.dart';

/// Word display screen – 1:1 from wordpage.py/kv.
class WordScreen extends StatefulWidget {
  const WordScreen({super.key});
  @override
  State<WordScreen> createState() => _WordScreenState();
}

class _WordScreenState extends State<WordScreen> {
  List<VocabEntry> _words = [];
  int _index = 0;
  bool _answerChecked = false;
  String _feedback = '';
  Color _feedbackColor = AppTheme.green2;
  DayStreak? _streak;

  AudioService? _audio;
  Timer? _audioTimer;
  bool _hasAudioWord = false;
  String _lang = 'de';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = context.read<AudioService?>();
    _loadWords();
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    final audio = _audio;
    if (audio != null) unawaited(audio.stop());
    super.dispose();
  }

  Future<void> _loadWords() async {
    final dataState = context.read<DataState>();
    final navState = context.read<NavigationState>();
    final uname = dataState.appData.loggedUName;
    if (uname.isEmpty) return;
    // Kurssprache des geöffneten Kurses (bestimmt Wörter und Audio).
    _lang = navState.resolveActiveLang(context.read<UserState>().userData);
    final mode = navState.wordMode;
    final limit = dataState.appData.wordsPerSession;
    List<VocabEntry> words;
    final vq = context.read<VocabQueries>();
    if (mode == 'new') {
      final cat = _categoryById(navState.selectedCategoryId);
      if (cat != null) {
        words = await vq.getGroupNewWords(uname, cat,
            langCode: _lang, limit: limit);
      } else {
        words = await vq.getNewWords(uname, langCode: _lang, limit: limit);
      }
      _streak = await vq.getDayStreak(uname);
    } else if (mode == 'read') {
      // „Gelesene Wörter": alle schon angeschauten Karten dieser Kategorie.
      final cat = _categoryById(navState.selectedCategoryId);
      words = cat != null
          ? await vq.getGroupReadWords(uname, cat, langCode: _lang)
          : await vq.getReadWords(uname, langCode: _lang);
    } else {
      // Ordner „Gelernte Wörter": alle fertig gelernten Karten (Level 8).
      final cat = _categoryById(navState.selectedCategoryId);
      words = cat != null
          ? await vq.getGroupLearnedWords(uname, cat, langCode: _lang)
          : await vq.getLearnedWords(uname, langCode: _lang);
    }
    if (mounted) {
      setState(() {
        _words = words;
        _index = 0;
        _answerChecked = false;
        _feedback = '';
      });
      _onWordChanged();
    }
  }

  void _onRead() {
    if (_words.isEmpty || _answerChecked) return;
    final navState = context.read<NavigationState>();
    final dataState = context.read<DataState>();
    final mode = navState.wordMode;
    final word = _words[_index];
    final uname = dataState.appData.loggedUName;

    context
        .read<VocabQueries>()
        .checkWordAnswer(uname, word.key, word.translation, langCode: _lang)
        .then((result) {
      if (!mounted) return;
      setState(() => _answerChecked = true);
      if (mode == 'new') {
        context.read<VocabQueries>().updateDayStreak(uname);
        context.read<VocabQueries>().getDayStreak(uname).then((s) {
          if (mounted) setState(() => _streak = s);
        });
        if (_index + 1 >= _words.length) {
          // Sitzungs-Ende: weiter mit dem nächsten Block oder beenden.
          _showLimitDialog();
          return;
        }
        setState(() {
          _index++;
          _answerChecked = false;
          _feedback = '';
        });
        _onWordChanged();
      } else {
        setState(() {
          _feedback = result.message;
          _feedbackColor = result.correct ? AppTheme.green2 : AppTheme.red2;
        });
      }
    });
  }

  void _showLimitDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showLimitDialog(context,
        title: l10n.titPageLearning,
        message: l10n.limitReached,
        continueText: l10n.btnContinue,
        endText: l10n.btnEndSession);
    if (!mounted) return;
    if (result == true) {
      await _continueLearning();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _continueLearning() async {
    final dataState = context.read<DataState>();
    final uname = dataState.appData.loggedUName;
    final limit = dataState.appData.wordsPerSession;
    final navState = context.read<NavigationState>();
    final cat = _categoryById(navState.selectedCategoryId);
    final vq = context.read<VocabQueries>();
    final List<VocabEntry> extra;
    if (cat != null) {
      extra = await vq.getGroupNewWords(uname, cat,
          langCode: _lang, limit: limit, offset: _words.length);
    } else {
      extra = await vq.getNewWords(uname,
          langCode: _lang, limit: limit, offset: _words.length);
    }
    if (extra.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() {
      _words = extra;
      _index = 0;
      _answerChecked = false;
      _feedback = '';
    });
    _onWordChanged();
  }

  WordCategory? _categoryById(String? id) {
    if (id == null) return null;
    for (final c in courseWordCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _navigate(int delta) {
    if (_words.isEmpty) return;
    setState(() {
      _index = (_index + delta) % _words.length;
      _answerChecked = false;
      _feedback = '';
    });
    _onWordChanged();
  }

  VocabEntry? get _currentWord {
    if (_words.isEmpty || _index >= _words.length) return null;
    return _words[_index];
  }

  /// Nach jedem Wortwechsel: aktuelles Wort per Auto-Play (nach kurzer Pause)
  /// vorsprechen und prüfen, ob Audio für den Replay-Button existiert.
  void _onWordChanged() {
    _audioTimer?.cancel();
    final audio = _audio;
    final w = _currentWord;
    if (audio == null || w == null) {
      if (_hasAudioWord) setState(() => _hasAudioWord = false);
      return;
    }
    final verbKey = vocabVerbKey(w.key);
    final tense = vocabTenseKey(w.key);
    final person = vocabPersonIndex(w.key);
    final lang = _lang;

    _audioTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(audio.play(
          langCode: lang, verbKey: verbKey, tense: tense, person: person));
    });

    audio
        .hasAudio(
            langCode: lang, verbKey: verbKey, tense: tense, person: person)
        .then((has) {
      if (mounted && has != _hasAudioWord) {
        setState(() => _hasAudioWord = has);
      }
    });
  }

  /// Wiederholt die Aussprache des aktuellen Wortes (Replay-Button).
  ///
  /// [tempo] wählt die Geschwindigkeit: Standard [AudioService.normalTempo]
  /// oder langsamer via [AudioService.slowTempo] (Slow-Button, Ticket #32).
  void _replay([double tempo = AudioService.normalTempo]) {
    final audio = _audio;
    final w = _currentWord;
    if (audio == null || w == null) return;
    unawaited(audio.play(
        langCode: _lang,
        verbKey: vocabVerbKey(w.key),
        tense: vocabTenseKey(w.key),
        person: vocabPersonIndex(w.key),
        tempo: tempo));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = context.read<NavigationState>().wordMode;
    final isNew = mode == 'new';
    final isReview = mode == 'read' || mode == 'learned';
    final word = _currentWord;
    final examples =
        word?.examples ?? const ['']; // Vorgabe [''] wie altes _parseList
    final examplesNative =
        word?.examplesNative ?? const ['']; // Vorgabe [''] wie altes _parseList

    return Scaffold(
      body: Column(children: [
        BoxTitle(
            title: l10n.titPageLearning,
            onInfo: () =>
                showInfoDialog(context, l10n.infWord, l10n.information)),
        if (isNew && _streak != null)
          SizedBox(
              height: 20,
              child: Text(
                  l10n.streakAndRecord(_streak!.current, _streak!.longest),
                  style: const TextStyle(
                      fontSize: AppTheme.infFontSize,
                      color: Color(0xFFFFB31A)))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: word == null
                    ? Center(
                        child: Text(l10n.noWords,
                            style: const TextStyle(
                                fontSize: AppTheme.lblFontSize)))
                    : _buildWordContent(
                        word, examples, examplesNative, isNew, isReview))),
        BoxBottom(
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp),
      ]),
    );
  }

  Widget _buildWordContent(VocabEntry word, List<String> examples,
      List<String> examplesNative, bool isNew, bool isReview) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(word.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 36))),
          Text(word.translation,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppTheme.lblFontSize, color: Colors.white70)),
          if (_hasAudioWord)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: PlaybackButtons(
                onPlay: _replay,
                onSlow: () => _replay(AudioService.slowTempo),
              ),
            ),
          const SizedBox(height: 8),
          if (examples.any((e) => e.isNotEmpty))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.examplesTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: AppTheme.infFontSize,
                        color: Colors.white60))),
          for (var i = 0; i < 3; i++)
            if (i < examples.length && examples[i].isNotEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '• ${examples[i]}${i < examplesNative.length && examplesNative[i].isNotEmpty ? "  (${examplesNative[i]})" : ""}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: AppTheme.infFontSize,
                          color: Colors.white60))),
          const SizedBox(height: 8),
          Text(l10n.labLevel(word.level),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTheme.infFontSize)),
          if (_feedback.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppTheme.lblFontSize,
                        color: _feedbackColor))),
          const SizedBox(height: 12),
          if (!isReview)
            SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: _answerChecked ? null : _onRead,
                    child: Text(l10n.btnRead,
                        style:
                            const TextStyle(fontSize: AppTheme.btnFontSize)))),
          if (isReview)
            SizedBox(
                height: 56,
                child: Row(children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => _navigate(-1),
                          child: Text(l10n.btnPrev,
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize)))),
                  Expanded(
                      child: TextButton(
                          onPressed: () => _navigate(1),
                          child: Text(l10n.btnNextWord,
                              style: const TextStyle(
                                  fontSize: AppTheme.btnFontSize)))),
                ])),
          const SizedBox(height: 8),
          SizedBox(
              height: 56,
              width: double.infinity,
              child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.back,
                      style: const TextStyle(
                          fontSize: AppTheme.btnFontSize,
                          color: AppTheme.colorPrimary)))),
        ],
      ),
    );
  }
}

import 'vocab_key.dart';

/// Data model for a vocabulary entry as stored in user files.
class VocabEntry {
  final String key;
  final String word;
  final String translation;
  final List<String> examples;
  final List<String> examplesNative;
  final int level;
  final String status; // 'new' | 'seen'
  final String? lastReviewed; // ISO8601
  final String? reviewDue; // date string or null

  VocabEntry({
    required this.key,
    required this.word,
    required this.translation,
    required this.examples,
    required this.examplesNative,
    this.level = 0,
    this.status = 'new',
    this.lastReviewed,
    this.reviewDue,
  });

  factory VocabEntry.fromJson(String key, Map<String, dynamic> json) {
    return VocabEntry(
      key: key,
      word: json['word']?.toString() ?? key.replaceAll('_', ' '),
      translation: json['translation']?.toString() ?? '',
      examples: _parseStringList(json['examples']),
      examplesNative: _parseStringList(json['examples_native']),
      level: json['level'] as int? ?? 0,
      status: json['status']?.toString() ?? 'new',
      lastReviewed: json['last_reviewed']?.toString(),
      reviewDue: json['review_due']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'translation': translation,
      'examples': examples,
      'examples_native': examplesNative,
      'level': level,
      'status': status,
      'last_reviewed': lastReviewed,
      'review_due': reviewDue,
    };
  }

  VocabEntry copyWith({
    String? key,
    String? word,
    String? translation,
    List<String>? examples,
    List<String>? examplesNative,
    int? level,
    String? status,
    String? lastReviewed,
    String? reviewDue,
    bool clearLastReviewed = false,
    bool clearReviewDue = false,
  }) {
    return VocabEntry(
      key: key ?? this.key,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      examples: examples ?? this.examples,
      examplesNative: examplesNative ?? this.examplesNative,
      level: level ?? this.level,
      status: status ?? this.status,
      lastReviewed:
          clearLastReviewed ? null : (lastReviewed ?? this.lastReviewed),
      reviewDue: clearReviewDue ? null : (reviewDue ?? this.reviewDue),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [''];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }
}

/// Day streak tracking for a user.
class DayStreak {
  final int current;
  final int longest;
  final String lastDate; // YYYY-MM-DD

  const DayStreak({
    this.current = 0,
    this.longest = 0,
    this.lastDate = '',
  });

  factory DayStreak.fromJson(Map<String, dynamic> json) {
    return DayStreak(
      current: json['current'] as int? ?? 0,
      longest: json['longest'] as int? ?? 0,
      lastDate: json['last_date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'current': current,
        'longest': longest,
        'last_date': lastDate,
      };
}

/// Aggregierte User-Statistiken, berechnet aus EINEM UserData-Load
/// (neue/faellige/gelesene/gelernte Woerter plus Tagesstreak).
class UserStats {
  final int newCount;
  final int dueCount;
  final int readCount;
  final int learnedCount;
  final DayStreak streak;

  const UserStats({
    this.newCount = 0,
    this.dueCount = 0,
    this.readCount = 0,
    this.learnedCount = 0,
    this.streak = const DayStreak(),
  });
}

/// Result of a word-answer check.
class AnswerCheckResult {
  final bool correct;
  final String? correctWord;
  final int? newLevel;
  final String message;
  final bool statusChanged;

  /// Kennzeichnet, dass die Antwort zwar ausgewertet, der daraus folgende
  /// Fortschritt aber NICHT persistiert werden konnte (Fehler transparent
  /// machen, ohne das Spiel abzubrechen).
  final bool persistenceFailed;

  const AnswerCheckResult({
    required this.correct,
    this.correctWord,
    this.newLevel,
    this.message = '',
    this.statusChanged = false,
    this.persistenceFailed = false,
  });
}

/// A word extracted from a language dictionary JSON file.
class LangDictWord {
  final String key;
  final String word;
  final String translation;
  final List<String> examples;

  const LangDictWord({
    required this.key,
    required this.word,
    required this.translation,
    this.examples = const [],
  });
}

/// Data model for user data stored in data_{username}.json.
class UserData {
  final String uName;
  final String mLang;
  final Map<String, int> progress;
  final List<String> learnedLanguages;
  final Map<String, dynamic> language;
  final Map<String, VocabEntry> vocab;
  final DayStreak? dayStreak;
  final int gameHighscore;
  final Map<String, int> crosswordBestTimes;
  final Map<String, int> fillInBestTimes;
  final List<String> selectedCourses;

  UserData({
    required this.uName,
    required this.mLang,
    required this.progress,
    required this.learnedLanguages,
    required this.language,
    required this.vocab,
    this.dayStreak,
    this.gameHighscore = 0,
    this.crosswordBestTimes = const {},
    this.fillInBestTimes = const {},
    this.selectedCourses = const [],
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    final vocabRaw = json['vocab'] as Map<String, dynamic>? ?? {};
    final vocab = <String, VocabEntry>{};
    vocabRaw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        vocab[key] = VocabEntry.fromJson(key, value);
      }
    });

    return UserData(
      uName: json['u_name']?.toString() ?? '',
      mLang: json['m_lang']?.toString() ?? 'de',
      progress: _parseProgress(json['progress']),
      learnedLanguages: List<String>.from(json['learned_languages'] ?? []),
      language: json['language'] as Map<String, dynamic>? ?? {},
      vocab: vocab,
      dayStreak: json['day_streak'] is Map
          ? DayStreak.fromJson(json['day_streak'])
          : null,
      gameHighscore: json['game_highscore'] as int? ?? 0,
      crosswordBestTimes: _parseIntMap(json['crossword_best_times']),
      fillInBestTimes: _parseIntMap(json['fill_in_best_times']),
      selectedCourses: List<String>.from(json['selected_courses'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'u_name': uName,
      'm_lang': mLang,
      'progress': progress,
      'learned_languages': learnedLanguages,
      'language': language,
      'vocab': vocab.map((key, value) => MapEntry(key, value.toJson())),
      if (dayStreak != null) 'day_streak': dayStreak!.toJson(),
      if (gameHighscore > 0) 'game_highscore': gameHighscore,
      if (crosswordBestTimes.isNotEmpty)
        'crossword_best_times': crosswordBestTimes,
      if (fillInBestTimes.isNotEmpty) 'fill_in_best_times': fillInBestTimes,
      'selected_courses': selectedCourses,
    };
  }

  UserData copyWith({
    String? uName,
    String? mLang,
    Map<String, int>? progress,
    List<String>? learnedLanguages,
    Map<String, dynamic>? language,
    Map<String, VocabEntry>? vocab,
    DayStreak? dayStreak,
    bool clearDayStreak = false,
    int? gameHighscore,
    Map<String, int>? crosswordBestTimes,
    Map<String, int>? fillInBestTimes,
    List<String>? selectedCourses,
  }) {
    return UserData(
      uName: uName ?? this.uName,
      mLang: mLang ?? this.mLang,
      progress: progress ?? this.progress,
      learnedLanguages: learnedLanguages ?? this.learnedLanguages,
      language: language ?? this.language,
      vocab: vocab ?? this.vocab,
      dayStreak:
          clearDayStreak ? null : (dayStreak ?? this.dayStreak),
      gameHighscore: gameHighscore ?? this.gameHighscore,
      crosswordBestTimes: crosswordBestTimes ?? this.crosswordBestTimes,
      fillInBestTimes: fillInBestTimes ?? this.fillInBestTimes,
      selectedCourses: selectedCourses ?? this.selectedCourses,
    );
  }

  static Map<String, int> _parseProgress(dynamic p) {
    if (p is Map<String, dynamic>) {
      return p.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    }
    return {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0};
  }

  static Map<String, int> _parseIntMap(dynamic p) {
    if (p is! Map) return const {};
    final result = <String, int>{};
    p.forEach((k, v) {
      final n = v is num ? v.toInt() : int.tryParse(v.toString());
      if (n != null) result[k.toString()] = n;
    });
    return result;
  }
}

/// App-level data (app_data.json).
class AppData {
  final List<String> registeredUser;
  final String loggedUName;
  final bool userLoggedIn;
  final bool stayLoggedIn;
  final int wordsPerSession;

  AppData({
    this.registeredUser = const [],
    this.loggedUName = '',
    this.userLoggedIn = false,
    this.stayLoggedIn = true,
    this.wordsPerSession = 3,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      registeredUser: List<String>.from(json['registered_user'] ?? []),
      loggedUName: json['logged_u_name']?.toString() ?? '',
      userLoggedIn: json['user_logged_in'] == true,
      stayLoggedIn: json['stay_logged_in'] ?? true,
      wordsPerSession: json['words_per_session'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registered_user': registeredUser,
      'logged_u_name': loggedUName,
      'user_logged_in': userLoggedIn,
      'stay_logged_in': stayLoggedIn,
      'words_per_session': wordsPerSession,
    };
  }

  AppData copyWith({
    List<String>? registeredUser,
    String? loggedUName,
    bool? userLoggedIn,
    bool? stayLoggedIn,
    int? wordsPerSession,
  }) {
    return AppData(
      registeredUser: registeredUser ?? this.registeredUser,
      loggedUName: loggedUName ?? this.loggedUName,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      stayLoggedIn: stayLoggedIn ?? this.stayLoggedIn,
      wordsPerSession: wordsPerSession ?? this.wordsPerSession,
    );
  }
}

/// Model for a language course (language + level + category).
class LanguageCourse {
  final String id;
  final String languageCode;
  final String languageName;
  final String level;
  final String category;
  final String flagAsset;

  const LanguageCourse({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.level,
    required this.category,
    required this.flagAsset,
  });
}

/// Levels, für die aktuell Kurs-Inhalte (Wörter/Grammatik) verfügbar sind.
/// Die Grammatik ist pro Level aufgeteilt (grammar_a1_de_en.json …), daher
/// sind alle CEFR-Level aktiv.
const Set<String> activeCourseLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};

/// All available courses in the app.
const Map<String, LanguageCourse> availableCourses = {
  'en_verben_a1': LanguageCourse(
    id: 'en_verben_a1',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'A1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'en_verben_a2': LanguageCourse(
    id: 'en_verben_a2',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'A2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'en_verben_b1': LanguageCourse(
    id: 'en_verben_b1',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'B1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'en_verben_b2': LanguageCourse(
    id: 'en_verben_b2',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'B2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'en_verben_c1': LanguageCourse(
    id: 'en_verben_c1',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'C1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'en_verben_c2': LanguageCourse(
    id: 'en_verben_c2',
    languageCode: 'en',
    languageName: 'Englisch',
    level: 'C2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_uk.png',
  ),
  'de_verben_a1': LanguageCourse(
    id: 'de_verben_a1',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'A1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
  'de_verben_a2': LanguageCourse(
    id: 'de_verben_a2',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'A2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
  'de_verben_b1': LanguageCourse(
    id: 'de_verben_b1',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'B1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
  'de_verben_b2': LanguageCourse(
    id: 'de_verben_b2',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'B2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
  'de_verben_c1': LanguageCourse(
    id: 'de_verben_c1',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'C1',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
  'de_verben_c2': LanguageCourse(
    id: 'de_verben_c2',
    languageCode: 'de',
    languageName: 'Deutsch',
    level: 'C2',
    category: 'Verben',
    flagAsset: 'assets/images/flag_germany.png',
  ),
};

/// A category that groups vocabulary verb files into learnable units.
///
/// Categories are stored as data (not hardcoded in screens) so the grouping
/// of the 30 verbs can be adjusted easily without touching the UI. Each
/// category references its verb dict keys (file stem after the language
/// prefix, e.g. 'to_be', 'to_be_allowed_to').
class WordCategory {
  final String id;
  final int order;

  /// l10n key for the localized category title.
  final String titleKey;

  /// Verb dict keys belonging to this category.
  final List<String> verbKeys;

  const WordCategory({
    required this.id,
    required this.order,
    required this.titleKey,
    required this.verbKeys,
  });

  /// Whether a vocab entry key (e.g. 'to_be_present_0') belongs to this
  /// category.
  ///
  /// Exakte Verb-Key-Zuordnung statt Prefix-Match: Treffer nur wenn
  /// [entryKey] exakt einem [verbKeys]-Element entspricht oder der per
  /// [vocabVerbKey] extrahierte Verb-Schlüssel exakt einem Element von
  /// [verbKeys] gleicht. Dadurch fällt z. B. 'to_be_allowed_to_present_0'
  /// nicht mehr fälschlich unter 'to_be'.
  bool containsEntryKey(String entryKey) =>
      verbKeys.any((vk) => entryKey == vk || vocabVerbKey(entryKey) == vk);
}

/// Liefert die [WordCategory] zur Id oder null.
WordCategory? wordCategoryById(String? id) {
  if (id == null) return null;
  for (final c in courseWordCategories) {
    if (c.id == id) return c;
  }
  return null;
}

/// Eine Sammlung (Überkategorie) von Word-Kategorien, z. B. "Verben".
///
/// Ermöglicht Hierarchien wie "Erste Verben" (eine direkt lernbare Kategorie)
/// und "Weitere Verben" (mit 5 Unterkategorien). Später kommen weitere
/// Sammlungen wie "Nomen" oder "Sätze" dazu.
class WordCollection {
  final String id;
  final int order;

  /// l10n key for the localized collection title.
  final String titleKey;

  /// Ids der enthaltenen [WordCategory]s.
  final List<String> categoryIds;

  const WordCollection({
    required this.id,
    required this.order,
    required this.titleKey,
    required this.categoryIds,
  });

  /// Die enthaltenen Word-Kategorien (in [categoryIds]-Reihenfolge).
  List<WordCategory> get categories {
    final result = <WordCategory>[];
    for (final id in categoryIds) {
      final c = wordCategoryById(id);
      if (c != null) result.add(c);
    }
    return result;
  }
}

/// Liefert die [WordCollection] zur Id oder null.
WordCollection? wordCollectionById(String? id) {
  if (id == null) return null;
  for (final c in courseWordCollections) {
    if (c.id == id) return c;
  }
  return null;
}

/// Navigations-Argumente für den Sammlungs-Screen ([CollectionScreen]).
class CollectionScreenArgs {
  final String collectionId;
  final String mode; // 'learn' | 'progress'

  const CollectionScreenArgs({
    required this.collectionId,
    required this.mode,
  });
}

/// The six vocabulary categories covering all 30 A1 verbs.
///
/// "Erste Verben" enthält die 5 Modalverben (können, wollen, sollen, dürfen,
/// müssen); die übrigen 25 Verben sind in 5 Gruppen à 5 Verben unter
/// "Weitere Verben" gesammelt.
const List<WordCategory> courseWordCategories = [
  WordCategory(
    id: 'erste_verben',
    order: 1,
    titleKey: 'catFirstVerbs',
    verbKeys: ['to_can', 'to_want', 'to_should', 'to_be_allowed_to', 'to_must'],
  ),
  WordCategory(
    id: 'grp_alltag',
    order: 2,
    titleKey: 'catGrpAlltag',
    verbKeys: ['to_be', 'to_have', 'to_need', 'to_like', 'to_see'],
  ),
  WordCategory(
    id: 'grp_bewegung',
    order: 3,
    titleKey: 'catGrpMovement',
    verbKeys: ['to_go', 'to_come', 'to_live', 'to_work', 'to_find'],
  ),
  WordCategory(
    id: 'grp_lernen',
    order: 4,
    titleKey: 'catGrpLearning',
    verbKeys: ['to_read', 'to_write', 'to_speak', 'to_understand', 'to_learn'],
  ),
  WordCategory(
    id: 'grp_arbeit',
    order: 5,
    titleKey: 'catGrpWork',
    verbKeys: ['to_buy', 'to_sell', 'to_make', 'to_begin', 'to_end'],
  ),
  WordCategory(
    id: 'grp_genuss',
    order: 6,
    titleKey: 'catGrpEnjoy',
    verbKeys: ['to_open', 'to_close', 'to_eat', 'to_drink', 'to_help'],
  ),
];

/// Die Lern-Sammlungen des "Lernen"-Screens: "Erste Verben" (direkt lernbar)
/// und "Weitere Verben" (Sammlung mit 5 Unterkategorien).
const List<WordCollection> courseWordCollections = [
  WordCollection(
    id: 'erste_verben',
    order: 1,
    titleKey: 'catFirstVerbs',
    categoryIds: ['erste_verben'],
  ),
  WordCollection(
    id: 'weitere_verben',
    order: 2,
    titleKey: 'catMoreVerbs',
    categoryIds: [
      'grp_alltag',
      'grp_bewegung',
      'grp_lernen',
      'grp_arbeit',
      'grp_genuss',
    ],
  ),
];

/// Aggregierte Fortschritts-Zahlen einer Word-Kategorie.
class CategoryCounts {
  final int total;
  final int newCount;
  final int dueCount;
  final int readCount;
  final int learnedCount;

  const CategoryCounts({
    this.total = 0,
    this.newCount = 0,
    this.dueCount = 0,
    this.readCount = 0,
    this.learnedCount = 0,
  });

  bool get hasWords => total > 0;
}

/// Model for a question in the Turbo quiz.
class QuizQuestion {
  final String key;
  final String word;
  final String translation;
  final List<String> options; // 4 shuffled options incl. correct

  QuizQuestion({
    required this.key,
    required this.word,
    required this.translation,
    required this.options,
  });
}

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

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [''];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }
}

/// Data model for user data stored in data_{username}.json.
class UserData {
  final String uName;
  final String mLang;
  final Map<String, int> progress;
  final List<String> learnedLanguages;
  final Map<String, dynamic> language;
  final Map<String, VocabEntry> vocab;
  final Map<String, dynamic>? dayStreak;
  final int gameHighscore;

  UserData({
    required this.uName,
    required this.mLang,
    required this.progress,
    required this.learnedLanguages,
    required this.language,
    required this.vocab,
    this.dayStreak,
    this.gameHighscore = 0,
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
      dayStreak: json['day_streak'] as Map<String, dynamic>?,
      gameHighscore: json['game_highscore'] as int? ?? 0,
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
      if (dayStreak != null) 'day_streak': dayStreak,
      if (gameHighscore > 0) 'game_highscore': gameHighscore,
    };
  }

  static Map<String, int> _parseProgress(dynamic p) {
    if (p is Map<String, dynamic>) {
      return p.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    }
    return {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0, 'C1': 0, 'C2': 0};
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

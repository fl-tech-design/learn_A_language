/// Typed models for the grammar catalogue
/// (`assets/grammar/grammar_de/grammar_de_en.json`).
///
/// The document is schema-versioned, bilingual (de/en) and CEFR-based. Every
/// human-readable string is stored as [LocalizedText] keyed by language code
/// ('de', 'en') so screens can render content in the user's native language.
library;

/// A short string per language code, e.g. `{'de': '…', 'en': '…'}`.
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  factory LocalizedText.fromJson(dynamic json) {
    final map = <String, String>{};
    if (json is Map) {
      json.forEach((key, value) {
        final s = value?.toString();
        if (s != null && s.isNotEmpty) map[key.toString()] = s;
      });
    }
    return LocalizedText(map);
  }

  bool get isEmpty => values.isEmpty;

  /// Returns the value for [lang], or the first available value as fallback.
  String? pick(String lang) {
    final direct = values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    if (values.isEmpty) return null;
    return values.values.first;
  }
}

/// One example pair: a German sentence and its English equivalent.
class GrammarExample {
  final String de;
  final String en;
  final LocalizedText? hint;

  const GrammarExample({required this.de, required this.en, this.hint});

  factory GrammarExample.fromJson(dynamic json) {
    if (json is! Map) return const GrammarExample(de: '', en: '');
    return GrammarExample(
      de: json['de']?.toString() ?? '',
      en: json['en']?.toString() ?? '',
      hint: json['hint'] == null ? null : LocalizedText.fromJson(json['hint']),
    );
  }

  /// Example text in [lang]; falls back to the other language.
  String pick(String lang) =>
      lang == 'de' ? _firstNonEmpty(de, en) : _firstNonEmpty(en, de);

  static String _firstNonEmpty(String a, String b) =>
      a.isNotEmpty ? a : b;
}

/// A typical pitfall (wrong/correct pattern) with an explanation.
class GrammarPitfall {
  final String wrong;
  final String correct;
  final LocalizedText why;

  const GrammarPitfall({
    required this.wrong,
    required this.correct,
    required this.why,
  });

  factory GrammarPitfall.fromJson(dynamic json) {
    if (json is! Map) {
      return const GrammarPitfall(
          wrong: '', correct: '', why: LocalizedText({}));
    }
    return GrammarPitfall(
      wrong: json['wrong']?.toString() ?? '',
      correct: json['correct']?.toString() ?? '',
      why: LocalizedText.fromJson(json['why']),
    );
  }
}

/// Optional mini exercise with a solution and accepted variants.
class GrammarQuickCheck {
  final LocalizedText task;
  final String solution;
  final List<String> accepted;

  const GrammarQuickCheck({
    required this.task,
    required this.solution,
    this.accepted = const [],
  });

  factory GrammarQuickCheck.fromJson(dynamic json) {
    if (json is! Map) {
      return const GrammarQuickCheck(task: LocalizedText({}), solution: '');
    }
    return GrammarQuickCheck(
      task: LocalizedText.fromJson(json['task']),
      solution: json['solution']?.toString() ?? '',
      accepted: json['accepted'] is List
          ? (json['accepted'] as List).whereType<String>().toList()
          : const [],
    );
  }
}

/// One grammar learning unit (a `block` in the JSON).
class GrammarBlock {
  final String id;
  final String level;
  final String category;
  final int order;
  final LocalizedText title;
  final LocalizedText summary;
  final LocalizedText explanation;
  final LocalizedText? contrast;
  final List<GrammarExample> examples;
  final GrammarPitfall? pitfall;
  final GrammarQuickCheck? quickCheck;
  final List<String> tags;
  final List<String> prerequisites;
  final LocalizedText? examFocus;

  const GrammarBlock({
    required this.id,
    required this.level,
    required this.category,
    required this.order,
    required this.title,
    required this.summary,
    required this.explanation,
    this.contrast,
    this.examples = const [],
    this.pitfall,
    this.quickCheck,
    this.tags = const [],
    this.prerequisites = const [],
    this.examFocus,
  });

  factory GrammarBlock.fromJson(dynamic json) {
    if (json is! Map) {
      return const GrammarBlock(
        id: '',
        level: '',
        category: '',
        order: 0,
        title: LocalizedText({}),
        summary: LocalizedText({}),
        explanation: LocalizedText({}),
      );
    }
    return GrammarBlock(
      id: json['id']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      title: LocalizedText.fromJson(json['title']),
      summary: LocalizedText.fromJson(json['summary']),
      explanation: LocalizedText.fromJson(json['explanation']),
      contrast: _nullableText(json['contrast']),
      examples: json['examples'] is List
          ? (json['examples'] as List).map(GrammarExample.fromJson).toList()
          : const [],
      pitfall: json['pitfall'] == null
          ? null
          : GrammarPitfall.fromJson(json['pitfall']),
      quickCheck: json['quick_check'] == null
          ? null
          : GrammarQuickCheck.fromJson(json['quick_check']),
      tags: _stringList(json['tags']),
      prerequisites: _stringList(json['prerequisites']),
      examFocus: _nullableText(json['exam_focus']),
    );
  }
}

/// A grammar category (`categories` in the JSON), e.g. sentence_structure.
class GrammarCategory {
  final String id;
  final int order;
  final LocalizedText title;
  final List<String> levels;

  const GrammarCategory({
    required this.id,
    required this.order,
    required this.title,
    this.levels = const [],
  });

  factory GrammarCategory.fromJson(dynamic json) {
    if (json is! Map) {
      return const GrammarCategory(id: '', order: 0, title: LocalizedText({}));
    }
    return GrammarCategory(
      id: json['id']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      title: LocalizedText.fromJson(json['title']),
      levels: _stringList(json['levels']),
    );
  }
}

/// Per-level description (`levels_info` in the JSON).
class LevelInfo {
  final String level;
  final LocalizedText title;
  final LocalizedText canDo;
  final List<String> exams;

  const LevelInfo({
    required this.level,
    required this.title,
    required this.canDo,
    this.exams = const [],
  });

  factory LevelInfo.fromJson(dynamic json) {
    if (json is! Map) {
      return const LevelInfo(
          level: '', title: LocalizedText({}), canDo: LocalizedText({}));
    }
    return LevelInfo(
      level: json['level']?.toString() ?? '',
      title: LocalizedText.fromJson(json['title']),
      canDo: LocalizedText.fromJson(json['can_do']),
      exams: _stringList(json['exams']),
    );
  }
}

/// The full grammar document.
class GrammarDocument {
  final String schemaVersion;
  final String contentVersion;
  final String? contentStatus;
  final String framework;
  final List<String> levels;
  final Map<String, String> direction; // l1 -> l2
  final List<String> uiLanguages;
  final List<LevelInfo> levelsInfo;
  final List<GrammarCategory> categories;
  final List<GrammarBlock> blocks;

  const GrammarDocument({
    this.schemaVersion = '',
    this.contentVersion = '',
    this.contentStatus,
    this.framework = '',
    this.levels = const [],
    this.direction = const {},
    this.uiLanguages = const [],
    this.levelsInfo = const [],
    this.categories = const [],
    this.blocks = const [],
  });

  factory GrammarDocument.fromJson(Map<String, dynamic> json) {
    final direction = <String, String>{};
    final rawDir = json['direction'];
    if (rawDir is Map) {
      rawDir.forEach((key, value) {
        if (value != null) direction[key.toString()] = value.toString();
      });
    }
    return GrammarDocument(
      schemaVersion: json['schema_version']?.toString() ?? '',
      contentVersion: json['content_version']?.toString() ?? '',
      contentStatus: json['content_status']?.toString(),
      framework: json['framework']?.toString() ?? '',
      levels: _stringList(json['levels']),
      direction: direction,
      uiLanguages: _stringList(json['ui_languages']),
      levelsInfo: json['levels_info'] is List
          ? (json['levels_info'] as List)
              .whereType<Map>()
              .map(LevelInfo.fromJson)
              .toList()
          : const [],
      categories: json['categories'] is List
          ? (json['categories'] as List)
              .whereType<Map>()
              .map(GrammarCategory.fromJson)
              .toList()
          : const [],
      blocks: json['blocks'] is List
          ? (json['blocks'] as List)
              .whereType<Map>()
              .map(GrammarBlock.fromJson)
              .toList()
          : const [],
    );
  }

  /// Categories sorted by their `order` field.
  List<GrammarCategory> get sortedCategories =>
      List<GrammarCategory>.of(categories)
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Blocks belonging to [categoryId], sorted by order then level.
  List<GrammarBlock> blocksOfCategory(String categoryId) {
    return blocks
        .where((b) => b.category == categoryId)
        .toList()
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        if (orderCmp != 0) return orderCmp;
        return a.level.compareTo(b.level);
      });
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  return const [];
}

LocalizedText? _nullableText(dynamic json) =>
    json == null ? null : LocalizedText.fromJson(json);
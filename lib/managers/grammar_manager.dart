import '../models/grammar_models.dart';
import '../services/file_service.dart';

/// Abstraction for the grammar catalogue. Screens depend on this interface,
/// so additional grammar documents/languages can be added later without
/// touching the UI.
abstract class GrammarManager {
  /// Loads (and caches) the grammar document from the bundled asset.
  ///
  /// When [level] is set (e.g. `'A2'`), a level-specific asset is loaded
  /// (e.g. `assets/grammar/grammar_de/grammar_a2_de_en.json`) so the UI only shows
  /// topics for that CEFR level. When [level] is null/empty the full
  /// catalogue (`grammar_de_en.json`) is returned.
  Future<GrammarDocument> load({String? level});
}

/// Concrete implementation backed by [FileService].
class GrammarManagerImpl implements GrammarManager {
  static const assetPath = 'assets/grammar/grammar_de/grammar_de_en.json';

  final FileService _fileService;
  final Map<String, GrammarDocument> _cache = {};

  GrammarManagerImpl(this._fileService);

  @override
  Future<GrammarDocument> load({String? level}) async {
    final key =
        (level == null || level.isEmpty) ? 'default' : level.toUpperCase();
    final cached = _cache[key];
    if (cached != null) return cached;

    final path = key == 'default'
        ? assetPath
        : 'assets/grammar/grammar_de/grammar_${key.toLowerCase()}_de_en.json';
    final data = await _fileService.loadBundledJson(path);
    final doc = GrammarDocument.fromJson(data);
    _cache[key] = doc;
    return doc;
  }
}
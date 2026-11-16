import '../models/grammar_models.dart';
import '../services/file_service.dart';

/// Abstraction for the grammar catalogue. Screens depend on this interface,
/// so additional grammar documents/languages can be added later without
/// touching the UI.
abstract class GrammarManager {
  /// Loads (and caches) the grammar document from the bundled asset.
  Future<GrammarDocument> load();
}

/// Concrete implementation backed by [FileService].
class GrammarManagerImpl implements GrammarManager {
  static const assetPath = 'assets/grammar/grammar_de_en.json';

  final FileService _fileService;
  GrammarDocument? _cache;

  GrammarManagerImpl(this._fileService);

  @override
  Future<GrammarDocument> load() async {
    if (_cache != null) return _cache!;
    final data = await _fileService.loadBundledJson(assetPath);
    _cache = GrammarDocument.fromJson(data);
    return _cache!;
  }
}
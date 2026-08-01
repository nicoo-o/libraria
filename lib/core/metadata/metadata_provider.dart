/// Interface commune aux enrichisseurs de métadonnées (V2+, 00_VISION_ET_PORTEE.md).
/// Ce ne sont PAS des `ContentSource` : ils enrichissent un item déjà en bibliothèque,
/// ils ne fournissent jamais de fichier à télécharger (voir la distinction Open Library
/// faite pour ADR-003 : enrichisseur, pas fournisseur de contenu).
abstract class MetadataProvider {
  String get id;
  Future<Map<String, Object?>> enrich({required String title, String? author});
}

/// V2 — TODO : implémenter contre l'API Open Library.
class OpenLibraryEnricher implements MetadataProvider {
  @override
  String get id => 'open_library';

  @override
  Future<Map<String, Object?>> enrich({required String title, String? author}) {
    throw UnimplementedError('OpenLibraryEnricher — V2, voir 00_VISION_ET_PORTEE.md.');
  }
}

// TmdbProvider, AniListProvider : V3+ (bibliothèque multimédia), mêmes principes,
// à écrire quand le chapitre 12.11 (Multimédia V3+) devient pertinent.

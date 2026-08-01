import '../../core/http/http_client.dart';
import '../base_content_source.dart';
import '../content_source.dart';

/// Z-Library — source étendue, **GitHub Edition uniquement** (ADR-014).
/// Domaines miroirs instables, catalogue partiellement sous droits.
///
/// Interdite dans le build Play Store : la constante `kExtendedSourcesAvailable`
/// est false par défaut, et l'enregistrement dans `ExtendedSourcesRegistry` ne
/// se fait que si le flag de compilation est vrai. Même si l'utilisateur active
/// le toggle dans Paramètres, il n'y a rien à activer côté Play Store — le tree
/// shaker a supprimé la classe du binaire.
///
/// TODO (P2, GitHub Edition) : implémenter doSearch() une fois le protocole
/// API validé. Rester dans les rails de `BaseContentSource` — pas de contournement
/// du rate limiter, du circuit breaker, ni de `UrlValidator`.
class ZLibrarySource extends BaseContentSource {
  ZLibrarySource({required this.httpClient});

  final HttpClient httpClient;

  @override
  String get id => 'zlibrary';

  @override
  String get displayName => 'Z-Library';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) {
    throw UnimplementedError(
      'ZLibrarySource.doSearch() — GitHub Edition seulement, voir ADR-014.',
    );
  }
}

import '../../core/http/http_client.dart';
import '../../core/models/media_type.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';
import '../content_source.dart';


/// JSON non-officiel (`ebooks.json`) en premier choix, OPDS en secours si le JSON
/// échoue — ADR-004. Le parsing XML du fallback OPDS reste un stub volontaire en V1
/// (liste vide + log), à implémenter en V2 seulement si le JSON venait à disparaître
/// (SRC-02, 11_BACKLOG.md).
class StandardEbooksSource extends BaseContentSource {
  StandardEbooksSource({required this.httpClient});

  final HttpClient httpClient;

  @override
  String get id => 'standard_ebooks';

  @override
  String get displayName => 'Standard Ebooks';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    try {
      // ADR-004 : JSON en premier choix.
      return await _searchJson(query, page: page, limit: limit);
    } catch (_) {
      // OPDS fallback en V1 : liste vide (volontaire).
      return _searchOpdsFallback(query);
    }
  }

  Future<SourceSearchResult> _searchJson(String query, {int? page, int? limit}) async {
    // Endpoint (documenté dans ADR-004) : https://standardebooks.org/ebooks.json
    // [Correctif] La racine JSON de cet endpoint est un TABLEAU, pas un objet —
    // `getList()`, pas `get()` (qui levait systématiquement une exception ici,
    // silencieusement absorbée par le catch de doSearch() : voir le commentaire
    // sur HttpClient.getList()).
    final list = await httpClient.getList('https://standardebooks.org/ebooks.json');

    final q = query.toLowerCase();

    final filtered = list
        .where((e) {
          final title = (e['title'] as String?)?.toLowerCase() ?? '';
          final author = (e['author'] as String?)?.toLowerCase() ?? '';
          return title.contains(q) || author.contains(q);
        })
        .toList();

    final offset = ((page ?? 1) - 1) * (limit ?? 20);
    final l = limit ?? 20;

    final pageItems = filtered
        .skip(offset)
        .take(l)
        .map((e) {
          final slug = e['url'] as String? ?? '';
          final title = e['title'] as String? ?? '';
          final author = e['author'] as String?;

          final downloadUrl = slug.isNotEmpty
              ? 'https://standardebooks.org$slug/downloads/epub'
              : '';

          final coverUrl = slug.isNotEmpty
              ? 'https://standardebooks.org$slug/downloads/cover.jpg'
              : null;

          return SearchResult(
            id: 'se_$slug',
            title: title,
            author: author,
            mediaType: MediaType.book,
            downloadUrl: downloadUrl,
            isDirectDownload: true,
            sourceName: displayName,
            coverUrl: coverUrl,
            description: null,
            externalId: slug,
            year: null,
          );
        })
        .where((r) => r.downloadUrl.isNotEmpty && r.title.isNotEmpty)
        .toList();

    return SourceSearchResult(items: pageItems, hasMore: false, totalCount: filtered.length);
  }

  /// Stub volontaire — liste vide + log, pas d'implémentation XML en V1 (ADR-004).
  Future<SourceSearchResult> _searchOpdsFallback(String query) async {
    return const SourceSearchResult(items: [], hasMore: false);
  }
}

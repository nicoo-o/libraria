import '../../core/http/http_client.dart';
import '../../core/models/media_type.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';
import '../content_source.dart';


/// Gutendex REST (JSON) — 70 000+ titres, très stable, sans clé API (ADR-003).
/// TODO (P1, 10_ROADMAP.md) : implémenter doSearch() contre
/// https://gutendex.com/books/?search=<query>&page=<page>.
class GutenbergSource extends BaseContentSource {
  GutenbergSource({required this.httpClient});

  final HttpClient httpClient;

  @override
  String get id => 'gutenberg';

  @override
  String get displayName => 'Project Gutenberg';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    // Gutendex: https://gutendex.com/books/?search=<query>&page=<page>
    final data = await httpClient.get(
      'https://gutendex.com/books',
      queryParameters: {
        'search': query,
        'page': page ?? 1,
      },
    );

    final results = (data['results'] as List?) ?? [];
    final mapped = results
        .map((b) {
          final formats = (b['formats'] as Map?) ?? {};
          final cover = (b['formats'] as Map?)?['image/jpeg'] as String?;
          final epub = formats['application/epub+zip'] as String?;

          final creators = b['authors'] as List?;
          final author = (creators != null && creators.isNotEmpty)
              ? (creators.first['name'] as String?)
              : null;

          final id = (b['id'] as int?)?.toString() ??
              (b['id'] as String?) ??
              '';
          final title = (b['title'] as String?) ?? '';
          final epubUrl = epub ?? '';

          if (epubUrl.isEmpty || title.isEmpty) return null;

          return SearchResult(
            id: 'gb_$id',
            title: title,
            author: author,
            mediaType: MediaType.book,
            downloadUrl: epubUrl,
            isDirectDownload: true,
            sourceName: displayName,
            coverUrl: cover,
            description: null,
            externalId: 'gb_$id',
            year: null,
          );
        })
        .whereType<SearchResult>()
        .toList();

    final hasMore = data['next'] != null;
    final totalCount = data['count'] as int?;

    final capped = (limit != null && limit > 0) ? mapped.take(limit).toList() : mapped;
    return SourceSearchResult(items: capped, totalCount: totalCount, hasMore: hasMore);
  }
}

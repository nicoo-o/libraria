import '../../core/http/http_client.dart';
import '../../core/models/media_type.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';
import '../content_source.dart';


/// `librivox.org/api` REST — audiobooks du domaine public, livrés en dizaines de MP3
/// séparés par livre (voir lib/readers/audio_player_screen.dart pour la lecture
/// continue multi-fichiers, 07_READER_AUDIOBOOK.md).
class LibrivoxSource extends BaseContentSource {
  LibrivoxSource({required this.httpClient});

  final HttpClient httpClient;

  @override
  String get id => 'librivox';

  @override
  String get displayName => 'LibriVox';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    // API feed: https://librivox.org/api/feed/audiobooks/?title=<q>&format=json&limit=<n>&offset=<o>
    final l = limit ?? 20;
    final p = page ?? 1;
    final offset = (p - 1) * l;

    // [Correctif] La doc officielle LibriVox exige le terme de recherche dans
    // le CHEMIN de l'URL (/title/^query), CARET NON ENCODE -- l'ancienne
    // syntaxe ?title=^query renvoyait systematiquement 404, et %5E encode
    // renvoyait aussi 404 (l'API attend le caret litteral dans le chemin).
    // format/limit/offset restent des query parameters, pas des segments de chemin.
    final safeQuery = Uri.encodeComponent(query);
    final data = await httpClient.get(
      'https://librivox.org/api/feed/audiobooks/title/^$safeQuery',
      queryParameters: {
        'format': 'json',
        'limit': l,
        'offset': offset,
      },
    );

    final books = (data['books'] as List?) ?? [];

    final mapped = books
        .map((b) {
          final title = b['title'] as String? ?? '';
          final id = b['id'] as String? ?? '';
          final url = b['url_zip_file'] as String? ?? '';
          if (title.isEmpty || url.isEmpty) return null;

          final authors = b['authors'] as List?;
          final author =
              (authors != null && authors.isNotEmpty) ? authors.first['display_name'] as String? : null;

          return SearchResult(
            id: 'lv_$id',
            title: title,
            author: author,
            mediaType: MediaType.audiobook,
            downloadUrl: url,
            isDirectDownload: true,
            sourceName: displayName,
            coverUrl: b['coverart_jpg'] as String?,
            description: null,
            externalId: id,
            year: null,
          );
        })
.whereType<SearchResult>()
        .toList();

    return SourceSearchResult(items: mapped, hasMore: false, totalCount: null);
  }
}

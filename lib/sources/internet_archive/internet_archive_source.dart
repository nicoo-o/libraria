import '../../core/http/http_client.dart';
import '../../core/logging/app_logger.dart';
import '../../core/models/media_type.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';
import '../content_source.dart';


/// `archive.org/advancedsearch` — livres ET audiobooks, domaine public + prêt légal.
/// Seule source V1 à exposer des checksums MD5/SHA-1 par fichier (`fetchChecksums`,
/// utilisée par DownloadManager après téléchargement, 05_DOWNLOAD_MANAGER.md).
class InternetArchiveSource extends BaseContentSource {
  InternetArchiveSource({required this.httpClient});

  final HttpClient httpClient;

  @override
  String get id => 'internet_archive';

  @override
  String get displayName => 'Internet Archive';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    // advancedsearch.php?q=<query>&fl[]=identifier&fl[]=title&fl[]=creator&rows=<n>&page=<p>
    final rows = limit ?? 20;
    final data = await httpClient.get(
      'https://archive.org/advancedsearch.php',
      queryParameters: {
        'q': query,
        'fl[]': ['identifier', 'title', 'creator'],
        'rows': rows,
        'page': page ?? 1,
        'output': 'json',
      },
    );

    final docs = (data['response']?['docs'] as List?) ?? [];

    // Remarque : mapping simple V1.
    final items = docs
        .map((d) {
          final identifier = d['identifier'] as String? ?? '';
          final title = d['title'] as String? ?? '';
          final creator = d['creator'];

          if (identifier.isEmpty || title.isEmpty) return null;

          final author = creator is List && creator.isNotEmpty
              ? creator.first as String?
              : creator as String?;

          final isAudiobook =
              title.toLowerCase().contains('audiobook');
          final mediaType =
              isAudiobook ? MediaType.audiobook : MediaType.book;

          // Note: pour l'instant, on pointe vers un .epub.
          // (La logique audio multi-fichiers sera affinée plus tard.)
          final downloadUrl =
              'https://archive.org/download/$identifier/$identifier.epub';

          return SearchResult(
            id: 'ia_$identifier',
            title: title,
            author: author,
            mediaType: mediaType,
            sourceName: displayName,
            downloadUrl: downloadUrl,
            isDirectDownload: true,
            coverUrl: 'https://archive.org/services/img/$identifier',
            externalId: identifier,
            year: null,
          );
        })
        .whereType<SearchResult>()
        .where((r) => r.downloadUrl.isNotEmpty)
        .toList();

    return SourceSearchResult(
      items: items,
      totalCount: data['response']?['numFound'] as int?,
      hasMore: false,
    );
  }


  /// Passe par le rate limiter de SA source, pas un appel « hors radar » (S-04,
  /// 11_BACKLOG.md).
  Future<Map<String, String>?> fetchChecksums(String identifier, String filename) {
    return rateLimited(() async {
      try {
        final meta = await httpClient.get('https://archive.org/metadata/$identifier');
        final files = (meta['files'] as List).cast<Map>();
        final match = files.firstWhere((f) => f['name'] == filename, orElse: () => {});
        if (match.isEmpty) return null;
        return {
          if (match['sha1'] != null) 'sha1': match['sha1'] as String,
          if (match['md5'] != null) 'md5': match['md5'] as String,
        };
      } catch (e) {
        AppLogger.warn('Checksum fetch failed for $identifier', module: 'INTERNET_ARCHIVE', error: e);
        return null; // un échec ne bloque jamais le téléchargement
      }
    });
  }
}

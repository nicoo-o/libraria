import 'media_type.dart';

/// Un résultat renvoyé par un `ContentSource` (lib/sources/content_source.dart).
/// `fetchChecksums` reste `dynamic`/optionnel : seule Internet Archive l'implémente
/// parmi les 4 sources V1 (voir 06_SOURCES_CONNECTEURS.md).
class SearchResult {
  final String id;
  final String title;
  final String? author;
  final MediaType mediaType;
  final String downloadUrl;
  final bool isDirectDownload;
  final String sourceName;
  final String? coverUrl;
  final String? description;
  final String? externalId;
  final int? year;

  const SearchResult({
    required this.id,
    required this.title,
    this.author,
    required this.mediaType,
    required this.downloadUrl,
    this.isDirectDownload = true,
    required this.sourceName,
    this.coverUrl,
    this.description,
    this.externalId,
    this.year,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'mediaType': mediaType.name,
        'downloadUrl': downloadUrl,
        'isDirectDownload': isDirectDownload,
        'sourceName': sourceName,
        'coverUrl': coverUrl,
        'description': description,
        'externalId': externalId,
        'year': year,
      };

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        id: j['id'] as String,
        title: j['title'] as String,
        author: j['author'] as String?,
        mediaType: MediaType.values.byName(j['mediaType'] as String),
        downloadUrl: j['downloadUrl'] as String,
        isDirectDownload: (j['isDirectDownload'] as bool?) ?? true,
        sourceName: j['sourceName'] as String,
        coverUrl: j['coverUrl'] as String?,
        description: j['description'] as String?,
        externalId: j['externalId'] as String?,
        year: j['year'] as int?,
      );
}

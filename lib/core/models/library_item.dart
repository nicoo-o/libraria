import 'media_type.dart';

/// Miroir exact de la table `library_items` (docs/restructuration_claude.md, chapitre 04
/// + colonnes v13/v15 ajoutées au chapitre 12).
class LibraryItem {
  final String id;
  final String title;
  final String? author;
  final MediaType mediaType;
  final String? localPath;
  final String? coverPath;
  final String? sourceName;
  final String? sourceUrl;
  final DateTime addedAt;
  DateTime? lastOpenedAt;
  double readProgress; // barre de progression, affichage rapide
  String? lastCfi; // v10 — source de vérité pour la reprise EXACTE
  final bool isFavorite;
  final String? notes;
  final int? year;
  final String? genre;
  final double? rating;
  final int? durationS;
  final String? description;
  final String? coverUrl;
  final String? externalId;
  final bool isMissing; // v9
  final DateTime? lastVerifiedAt; // v9
  final DateTime? deletedAt; // v9 — corbeille soft, purge à 30 jours
  final String? contentSha256; // v9
  final String? seriesName; // v13 (chapitre 12, NF-002)
  final int readCount; // v13 (chapitre 12)
  final double? playbackSpeedPref; // v14 (chapitre 12, NF-023)

  LibraryItem({
    required this.id,
    required this.title,
    this.author,
    required this.mediaType,
    this.localPath,
    this.coverPath,
    this.sourceName,
    this.sourceUrl,
    required this.addedAt,
    this.lastOpenedAt,
    this.readProgress = 0.0,
    this.lastCfi,
    this.isFavorite = false,
    this.notes,
    this.year,
    this.genre,
    this.rating,
    this.durationS,
    this.description,
    this.coverUrl,
    this.externalId,
    this.isMissing = false,
    this.lastVerifiedAt,
    this.deletedAt,
    this.contentSha256,
    this.seriesName,
    this.readCount = 0,
    this.playbackSpeedPref,
  });

  factory LibraryItem.fromMap(Map<String, Object?> map) {
    DateTime? toDate(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

    return LibraryItem(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      mediaType: MediaTypeStorage.fromStorage(map['media_type'] as String),
      localPath: map['local_path'] as String?,
      coverPath: map['cover_path'] as String?,
      sourceName: map['source_name'] as String?,
      sourceUrl: map['source_url'] as String?,
      addedAt: toDate(map['added_at'])!,
      lastOpenedAt: toDate(map['last_opened_at']),
      readProgress: (map['read_progress'] as num?)?.toDouble() ?? 0.0,
      lastCfi: map['last_cfi'] as String?,
      isFavorite: (map['is_favorite'] as int?) == 1,
      notes: map['notes'] as String?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      durationS: map['duration_s'] as int?,
      description: map['description'] as String?,
      coverUrl: map['cover_url'] as String?,
      externalId: map['external_id'] as String?,
      isMissing: (map['is_missing'] as int?) == 1,
      lastVerifiedAt: toDate(map['last_verified_at']),
      deletedAt: toDate(map['deleted_at']),
      contentSha256: map['content_sha256'] as String?,
      seriesName: map['series_name'] as String?,
      readCount: (map['read_count'] as int?) ?? 0,
      playbackSpeedPref: (map['playback_speed_pref'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    int? toMs(DateTime? d) => d?.millisecondsSinceEpoch;
    return {
      'id': id,
      'title': title,
      'author': author,
      'media_type': mediaType.storageValue,
      'local_path': localPath,
      'cover_path': coverPath,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'added_at': toMs(addedAt),
      'last_opened_at': toMs(lastOpenedAt),
      'read_progress': readProgress,
      'last_cfi': lastCfi,
      'is_favorite': isFavorite ? 1 : 0,
      'notes': notes,
      'year': year,
      'genre': genre,
      'rating': rating,
      'duration_s': durationS,
      'description': description,
      'cover_url': coverUrl,
      'external_id': externalId,
      'is_missing': isMissing ? 1 : 0,
      'last_verified_at': toMs(lastVerifiedAt),
      'deleted_at': toMs(deletedAt),
      'content_sha256': contentSha256,
      'series_name': seriesName,
      'read_count': readCount,
      'playback_speed_pref': playbackSpeedPref,
    };
  }
}

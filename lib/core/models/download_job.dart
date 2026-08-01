import 'dart:convert';

import 'search_result.dart';
import 'library_item.dart';
import 'media_type.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

/// Miroir de la table `downloads` (guide Partie 2.1) + état en mémoire
class DownloadJob {
  final String id;
  final SearchResult result;

  int priority; // 1=haute, 2=normale, 3=basse
  DownloadStatus status;
  double progress;

  int retryCount;

  /// [Correctif — bug réel trouvé en test réel] En mémoire uniquement (pas
  /// persisté : voir le commentaire sur `resumeQueuedJobs()` dans
  /// download_manager.dart pour pourquoi ce n'est pas nécessaire). Distingue
  /// un `failed` par épuisement des 3 retries PENDANT que le réseau était
  /// encore coupé (retentable dès la reconnexion) d'un `failed` définitif
  /// (ex. 404 — le fichier n'existe juste pas, retenter ne changera rien).
  bool wasNetworkFailure = false;

  String? localPath;
  String? coverPath;
  String? errorMessage;
  DateTime? completedAt;

  String? expectedSha1;
  String? expectedMd5;

  final DateTime createdAt;

  DownloadJob({
    required this.id,
    required this.result,
    this.priority = 2,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.retryCount = 0,
    this.wasNetworkFailure = false,
    this.localPath,
    this.coverPath,
    this.errorMessage,
    this.completedAt,
    this.expectedSha1,
    this.expectedMd5,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DownloadJob.fromMap(Map<String, Object?> map) {
    final resultJson = map['result_json'] as String?;
    final decoded = resultJson != null && resultJson.isNotEmpty
        ? (jsonDecode(resultJson) as Map<String, dynamic>)
        : <String, dynamic>{};

    return DownloadJob(
      id: map['id'] as String,
      result: decoded.isNotEmpty ? SearchResult.fromJson(decoded) : _fallbackFromColumns(map),
      priority: (map['priority'] as int?) ?? 2,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DownloadStatus.queued,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      retryCount: (map['retry_count'] as int?) ?? 0,
      localPath: map['save_path'] as String?,
      errorMessage: map['error_message'] as String?,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int),
      expectedSha1: map['expected_sha1'] as String?,
      expectedMd5: map['expected_md5'] as String?,
      wasNetworkFailure: (map['was_network_failure'] as int?) == 1,
      // [Correctif] `created_at` est NOT NULL dans le schéma (downloads) — une ligne
      // relue depuis une DB migrée sans cette colonne (ne devrait plus arriver
      // depuis migration_v16, gardé par sécurité) retombe sur "maintenant".
      createdAt: map['created_at'] == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static SearchResult _fallbackFromColumns(Map<String, Object?> map) {
    // Compat temporaire si une DB ancienne existait sans result_json.
    return SearchResult(
      id: (map['id'] as String),
      title: (map['title'] as String?) ?? '',
      author: null,
      mediaType: MediaType.book,
      sourceName: 'unknown',
      downloadUrl: (map['download_url'] as String?) ?? '',
      isDirectDownload: true,
      coverUrl: null,
      description: null,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        // [Correctif] `title` et `download_url` sont NOT NULL dans le schéma
        // `downloads` (schema_full.dart / migration_v1) et n'étaient pas écrites
        // ici : tout `db.insert('downloads', job.toMap())` aurait levé
        // "NOT NULL constraint failed". `result_json` reste la source de vérité
        // pour la reconstruction complète (fromMap) ; ces deux colonnes ne
        // servent qu'à satisfaire la contrainte et à permettre une requête SQL
        // directe (ex: liste des titres en échec) sans désérialiser le JSON.
        'title': result.title,
        'download_url': result.downloadUrl,
        'result_json': jsonEncode(result.toJson()),
        'save_path': localPath,
        'status': status.name,
        'progress': progress,
        'priority': priority,
        'error_message': errorMessage,
        'retry_count': retryCount,
        // [Correctif] NOT NULL également, jamais écrite auparavant.
        'created_at': createdAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'expected_sha1': expectedSha1,
        'expected_md5': expectedMd5,
        'was_network_failure': wasNetworkFailure ? 1 : 0,
        'source_connector': result.sourceName,
      };

  LibraryItem toLibraryItem() => LibraryItem(
        id: id,
        title: result.title,
        author: result.author,
        mediaType: result.mediaType,
        localPath: localPath,
        coverPath: coverPath,
        sourceName: result.sourceName,
        sourceUrl: result.downloadUrl,
        addedAt: DateTime.now(),
      );
}

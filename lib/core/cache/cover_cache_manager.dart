import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Cache LRU disque des couvertures — table `cover_cache_index` (04_BASE_DE_DONNEES.md).
///
/// [Correctif ADR-010] `put()` gère l'INDEX (taille + horodatage d'accès) pour
/// un fichier déjà écrit sur disque par l'appelant — la compression au format
/// 400×600/JPEG q85 mentionnée dans l'ADR nécessiterait un package de
/// traitement d'image (`image`, `flutter_image_compress`...) qui n'est pas
/// budgété actuellement (règle R1 du chapitre 12, restructuration_claude.md) :
/// les couvertures sont mises en cache TELLES QUE téléchargées, sans
/// redimensionnement. À réévaluer si le poids du cache devient un problème réel.
class CoverCacheManager {
  CoverCacheManager(this._db, this._coversDir);

  final Database _db;
  final String _coversDir;

  static const maxSizeBytes = 200 * 1024 * 1024; // 200 Mo
  static const maxAgeDays = 30;

  /// Indexe un fichier déjà écrit à `<coversDir>/<filename>` (voir
  /// DownloadManager, qui télécharge puis appelle `put()`). Déclenche
  /// l'éviction LRU si `maxSizeBytes` est dépassé après cet ajout. Retourne le
  /// chemin absolu du fichier.
  Future<String> put(String filename, int sizeBytes) async {
    await _db.insert(
      'cover_cache_index',
      {
        'filename': filename,
        'size_bytes': sizeBytes,
        'accessed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await evictLeastRecentlyUsed();
    return p.join(_coversDir, filename);
  }

  /// À appeler chaque fois qu'une couverture déjà en cache est effectivement
  /// affichée (ex. CoverPlaceholder) — sinon l'éviction LRU finit par évincer
  /// des couvertures encore consultées régulièrement, seulement parce qu'elles
  /// n'ont jamais été retouchées depuis leur téléchargement initial.
  Future<void> touch(String filename) async {
    await _db.update(
      'cover_cache_index',
      {'accessed_at': DateTime.now().millisecondsSinceEpoch},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  Future<void> evictLeastRecentlyUsed() async {
    // Plus récemment accédé en premier : tout ce qui dépasse maxSizeBytes en
    // cumulant à partir de là est, par définition, le moins récemment utilisé.
    final rows = await _db.query('cover_cache_index', orderBy: 'accessed_at DESC');
    var total = 0;
    final toEvict = <String>[];
    for (final row in rows) {
      total += row['size_bytes'] as int;
      if (total > maxSizeBytes) toEvict.add(row['filename'] as String);
    }

    for (final filename in toEvict) {
      await _db.delete('cover_cache_index', where: 'filename = ?', whereArgs: [filename]);
      final file = File(p.join(_coversDir, filename));
      if (await file.exists()) await file.delete();
    }
  }
}

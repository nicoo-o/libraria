import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/models/library_item.dart';

/// Référence unique pour l'accès à `library_items` — voir 04_BASE_DE_DONNEES.md.
/// Quelques méthodes ci-dessous sont écrites en entier (pas des stubs) parce que leur
/// requête est déjà entièrement spécifiée dans MES_PROPOSITIONS_LIBRARIA.md /
/// restructuration_claude.md ; le reste est à compléter au fur et à mesure des écrans.
class LibraryRepository {
  LibraryRepository(this._db);

  final Database _db;

  Future<void> saveItem(LibraryItem item) async {
    await _db.insert(
      'library_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LibraryItem?> getById(String id) async {
    final rows = await _db.query('library_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return LibraryItem.fromMap(rows.first);
  }

  Future<List<LibraryItem>> getAll({bool includeDeleted = false}) async {
    final rows = await _db.query(
      'library_items',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'added_at DESC',
    );
    return rows.map(LibraryItem.fromMap).toList();
  }

  Future<void> updatePosition(String itemId, {required double readProgress, String? lastCfi}) async {
    await _db.update(
      'library_items',
      {
        'read_progress': readProgress,
        if (lastCfi != null) 'last_cfi': lastCfi,
        'last_opened_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Suppression réelle différée 30 jours (`deleted_at`) — corbeille à 2 paliers,
  /// voir 08_UI_UX_DESIGN_SYSTEM.md pour la confirmation en amont.
  Future<void> softDelete(String itemId) async {
    await _db.update(
      'library_items',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> purgeDeletedOlderThan(Duration age) async {
    final threshold = DateTime.now().subtract(age).millisecondsSinceEpoch;
    // [Correctif ADR-011] La purge ne supprimait QUE la ligne DB — le fichier
    // physique (livre + couverture) restait orphelin sur le disque
    // indéfiniment. On récupère les items à purger AVANT de les effacer de la
    // DB, pour pouvoir nettoyer leurs fichiers.
    final rows = await _db.query(
      'library_items',
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [threshold],
    );
    for (final row in rows) {
      await _deletePhysicalFiles(LibraryItem.fromMap(row));
    }
    await _db.delete('library_items', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [threshold]);
  }

  Future<void> _deletePhysicalFiles(LibraryItem item) async {
    final path = item.localPath;
    if (path != null) {
      // Fichier (EPUB, M4B) OU dossier (audiobook LibriVox extrait —
      // AudiobookZipExtractor, Partie 4) : vérifier les deux, comme dans
      // LocalFileVerifier.
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      } else {
        final dir = Directory(path);
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    }
    final coverPath = item.coverPath;
    if (coverPath != null) {
      final coverFile = File(coverPath);
      if (await coverFile.exists()) await coverFile.delete();
      // [Correctif] Nettoyage immédiat de l'index — auparavant seulement
      // signalé en commentaire ("le prochain passage LRU la découvrira"),
      // ce qui laissait une ligne fantôme dans cover_cache_index jusqu'au
      // prochain put() ailleurs dans l'app (pas de garantie de délai).
      await _db.delete('cover_cache_index', where: 'filename = ?', whereArgs: [p.basename(coverPath)]);
    }
  }

  /// Liste des items dans la corbeille (2ᵉ palier avant suppression réelle,
  /// ADR-011) — écran dédié, pas seulement `getAll(includeDeleted: true)` qui
  /// mélangerait actifs et supprimés.
  Future<List<LibraryItem>> getTrash() async {
    final rows = await _db.query(
      'library_items',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(LibraryItem.fromMap).toList();
  }

  /// Restaure un item de la corbeille — symétrique de [softDelete].
  Future<void> restore(String itemId) async {
    await _db.update(
      'library_items',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Relier un fichier local après déplacement/renommage externe (badge « manquant »,
  /// 08_UI_UX_DESIGN_SYSTEM.md).
  Future<void> relink(String itemId, {required String newPath, required String newSha}) async {
    await _db.update(
      'library_items',
      {
        'local_path': newPath,
        'content_sha256': newSha,
        'is_missing': 0,
        'last_verified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Symétrique de [relink] — posé par `LocalFileVerifier` (tâche périodique
  /// Workmanager, Partie 7) quand le fichier n'existe plus à `local_path`.
  /// Ne supprime JAMAIS l'entrée : c'est le badge « manquant » + le flux
  /// `relink()` qui gèrent la suite, pas une suppression silencieuse.
  Future<void> markMissing(String itemId) async {
    await _db.update(
      'library_items',
      {
        'is_missing': 1,
        'last_verified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// « Récemment ouverts » — écran d'accueil (MES_PROPOSITIONS_LIBRARIA.md #1).
  Future<List<LibraryItem>> getRecentlyOpened({int limit = 10}) async {
    final rows = await _db.query(
      'library_items',
      where: 'deleted_at IS NULL AND last_opened_at IS NOT NULL',
      orderBy: 'last_opened_at DESC',
      limit: limit,
    );
    return rows.map(LibraryItem.fromMap).toList();
  }

  /// « À reprendre ou abandonner » — items commencés puis délaissés (MES_PROPOSITIONS
  /// #3), utilisé aussi par NF-050 (ratio abandon/terminé, chapitre 12).
  Future<List<LibraryItem>> getStalledReads({int staleDays = 30}) async {
    final threshold = DateTime.now().subtract(Duration(days: staleDays)).millisecondsSinceEpoch;
    final rows = await _db.query(
      'library_items',
      where: 'deleted_at IS NULL AND read_progress > 0 AND read_progress < 0.95 '
          'AND (last_opened_at IS NULL OR last_opened_at < ?)',
      whereArgs: [threshold],
      orderBy: 'last_opened_at ASC',
    );
    return rows.map(LibraryItem.fromMap).toList();
  }

  /// Marquage « Lu » manuel (chapitre 12, NF-006) — jusqu'ici aucun bouton ni
  /// méthode ne posait `read_progress = 1.0` (voir audit). Ne touche pas
  /// `last_cfi` : marquer un livre comme lu ne doit pas faire perdre la
  /// position de lecture réelle si l'utilisateur revient dessus plus tard.
  Future<void> markAsRead(String itemId) async {
    await updatePosition(itemId, readProgress: 1.0);
  }

  /// Vitesse de lecture mémorisée PAR LIVRE (chapitre 12, NF-023). La colonne
  /// existait depuis la migration v14 et était déjà mappée dans LibraryItem,
  /// mais rien ne l'écrivait ni ne la lisait (squelette mort, voir audit) —
  /// c'est ce écran audio (audio_player_screen.dart) qui l'appelle désormais.
  Future<void> updatePlaybackSpeed(String itemId, double speed) async {
    await _db.update(
      'library_items',
      {'playback_speed_pref': speed},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Détection de doublon par hash — MES_PROPOSITIONS_LIBRARIA.md #2, réutilisée par
  /// l'import en masse (chapitre 12, NF-093).
  Future<LibraryItem?> findByContentHash(String sha256) async {
    final rows = await _db.query('library_items', where: 'content_sha256 = ?', whereArgs: [sha256], limit: 1);
    if (rows.isEmpty) return null;
    return LibraryItem.fromMap(rows.first);
  }
}

import 'package:sqflite/sqflite.dart';

/// Statistiques de lecture — dérivées de `reading_sessions`/`library_items`, aucune
/// nouvelle table nécessaire pour la plupart (04_BASE_DE_DONNEES.md, chapitre 12.5).
class ReadingStatsService {
  ReadingStatsService(this._db);
  final Database _db;

  /// Auteur le plus lu (chapitre 12, NF-044).
  Future<List<Map<String, Object?>>> mostReadAuthors({int limit = 5}) {
    return _db.rawQuery('''
      SELECT li.author, COUNT(*) AS session_count
      FROM reading_sessions rs
      JOIN library_items li ON li.id = rs.item_id
      WHERE li.author IS NOT NULL
      GROUP BY li.author
      ORDER BY session_count DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Jours de semaine préférés pour lire (chapitre 12, NF-047).
  Future<List<Map<String, Object?>>> sessionsByWeekday() {
    return _db.rawQuery('''
      SELECT strftime('%w', started_at / 1000, 'unixepoch') AS weekday, COUNT(*) AS count
      FROM reading_sessions
      GROUP BY weekday
      ORDER BY weekday ASC
    ''');
  }

  /// Répartition papier(EPUB)/audio (chapitre 12, NF-045).
  Future<List<Map<String, Object?>>> mediaTypeBreakdown() {
    return _db.rawQuery('''
      SELECT media_type, COUNT(*) AS count
      FROM library_items
      WHERE deleted_at IS NULL
      GROUP BY media_type
    ''');
  }

  /// Le reste (objectif annuel NF-043, vitesse moyenne NF-046, temps moyen pour
  /// terminer NF-051, etc.) suit le même principe — requête pure sur les tables
  /// existantes, voir docs/restructuration_claude.md chapitre 12.5 pour la liste.
}

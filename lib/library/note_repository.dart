import 'package:sqflite/sqflite.dart';

/// Notes/surlignages avec CFI reel + recherche plein texte FTS5 (07_READER_AUDIOBOOK.md).
class NoteRepository {
  NoteRepository(this._db);
  final Database _db;

  Future<void> add({
    required String id,
    required String itemId,
    required String cfi,
    String color = '#FFEB3B',
    String? text,
    String? note,
  }) async {
    await _db.insert('notes', {
      'id': id,
      'item_id': itemId,
      'cfi': cfi,
      'color': color,
      'text': text,
      'note': note,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> getForItem(String itemId) =>
      _db.query('notes', where: 'item_id = ?', whereArgs: [itemId], orderBy: 'created_at ASC');

  /// Recherche plein texte -- voir 07_READER_AUDIOBOOK.md pour la requete `bm25()`
  /// complete. Si le module FTS5 est indisponible sur ce device (table/triggers
  /// jamais crees a l'ouverture de la DB, voir database_helper.dart), on retombe
  /// automatiquement sur une recherche LIKE classique, moins pertinente mais
  /// fonctionnelle partout.
  Future<List<Map<String, Object?>>> searchNotes(String query, {int limit = 50}) async {
    try {
      return await _db.rawQuery('''
        SELECT n.id, n.item_id, snippet(notes_fts, 0, '<mark>', '</mark>', '...', 12) AS snippet,
               bm25(notes_fts) AS rank
        FROM notes_fts JOIN notes n ON n.rowid = notes_fts.rowid
        WHERE notes_fts MATCH ? ORDER BY rank LIMIT ?
      ''', [_escapeFts(query), limit]);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('fts5') || msg.contains('notes_fts') || msg.contains('no such table')) {
        final like = '%${query.replaceAll('%', '').replaceAll('_', '')}%';
        return _db.query(
          'notes',
          columns: ['id', 'item_id', 'text AS snippet'],
          where: '(text LIKE ? OR note LIKE ?)',
          whereArgs: [like, like],
          orderBy: 'created_at DESC',
          limit: limit,
        );
      }
      rethrow;
    }
  }

  String _escapeFts(String query) => '"${query.replaceAll('"', '""')}"';
}
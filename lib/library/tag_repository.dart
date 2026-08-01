import 'package:sqflite/sqflite.dart';

/// Tags libres, multi-couleurs, transverses, filtrables en combinaison avec les
/// étagères (`étagère ∩ ensemble de tags`, 08_UI_UX_DESIGN_SYSTEM.md). Autocomplete
/// sur les tags déjà utilisés, limite 20 tags/item — la limite se vérifie côté UI
/// avant d'appeler `attach()`, pas ici (pas de contrainte SQL dédiée pour ça).
class TagRepository {
  TagRepository(this._db);
  final Database _db;

  Future<int> getOrCreate(String label, {int color = 0}) async {
    final existing = await _db.query('tags', where: 'label = ? COLLATE NOCASE', whereArgs: [label], limit: 1);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return _db.insert('tags', {'label': label, 'color': color, 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> attach(String itemId, int tagId) async {
    await _db.insert('item_tags', {'item_id': itemId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> detach(String itemId, int tagId) async {
    await _db.delete('item_tags', where: 'item_id = ? AND tag_id = ?', whereArgs: [itemId, tagId]);
  }

  Future<List<Map<String, Object?>>> getAllTags() => _db.query('tags', orderBy: 'label ASC');

  Future<List<Map<String, Object?>>> getTagsForItem(String itemId) => _db.rawQuery('''
    SELECT t.* FROM tags t
    JOIN item_tags it ON it.tag_id = t.id
    WHERE it.item_id = ?
    ORDER BY t.label ASC
  ''', [itemId]);
}

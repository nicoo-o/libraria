import 'package:sqflite/sqflite.dart';

/// Étagères — collections nommées, un item peut appartenir à plusieurs, réordonnées
/// par glisser-déposer + alternative boutons Monter/Descendre (SC 2.5.7, WCAG 2.2,
/// 08_UI_UX_DESIGN_SYSTEM.md). `isSmart`/`smartRule` : chapitre 12, NF-003.
class ShelfRepository {
  ShelfRepository(this._db);
  final Database _db;

  Future<void> create({required String id, required String name, String? color}) async {
    await _db.insert('shelves', {'id': id, 'name': name, 'color': color, 'position': 0, 'is_smart': 0});
  }

  Future<List<Map<String, Object?>>> getAll() =>
      _db.query('shelves', orderBy: 'position ASC');

  Future<void> addItem(String shelfId, String itemId) async {
    final maxPos = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT MAX(position) FROM shelf_items WHERE shelf_id = ?', [shelfId]),
        ) ??
        0;
    await _db.insert('shelf_items', {'shelf_id': shelfId, 'item_id': itemId, 'position': maxPos + 1});
  }

  Future<void> removeItem(String shelfId, String itemId) async {
    await _db.delete('shelf_items', where: 'shelf_id = ? AND item_id = ?', whereArgs: [shelfId, itemId]);
  }

  /// Réordonnancement — TOUJOURS accompagné de boutons Monter/Descendre dans l'UI
  /// (SC 2.5.7), le drag seul ne satisfait pas ce critère WCAG.
  Future<void> reorder(String shelfId, List<String> orderedItemIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedItemIds.length; i++) {
      batch.update('shelf_items', {'position': i},
          where: 'shelf_id = ? AND item_id = ?', whereArgs: [shelfId, orderedItemIds[i]]);
    }
    await batch.commit(noResult: true);
  }

  /// Étagère intelligente — filtre sauvegardé (chapitre 12, NF-003). `smartRule` est
  /// un JSON simple interprété côté UI (pas de moteur de règles générique en V1).
  Future<void> setSmartRule(String shelfId, {required bool isSmart, String? rule}) async {
    await _db.update('shelves', {'is_smart': isSmart ? 1 : 0, 'smart_rule': rule},
        where: 'id = ?', whereArgs: [shelfId]);
  }
}

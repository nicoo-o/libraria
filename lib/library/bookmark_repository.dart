import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/models/bookmark.dart';

/// [Décision de portée] Le tableau de portée V1 (docs/restructuration_claude.md)
/// liste les signets EPUB comme faisant partie de la Partie 6 (lecteur), mais
/// aucun repository ni écran n'existait — seul le modèle `Bookmark` était
/// écrit. Choix fait ici : signets EN V1, mais en version MINIMALE (signet
/// rapide sans annotation, pas de note/texte/couleur) — l'enrichissement
/// (annotation, export, recherche plein texte sur les signets) reste V2,
/// cohérent avec NF-021 du chapitre 12 ("Signet rapide sans annotation").
class BookmarkRepository {
  BookmarkRepository(this._db);
  final Database _db;

  Future<Bookmark> add({required String itemId, required String location}) async {
    final bookmark = Bookmark(
      id: const Uuid().v4(),
      itemId: itemId,
      location: location,
      createdAt: DateTime.now(),
    );
    await _db.insert('bookmarks', bookmark.toMap());
    return bookmark;
  }

  Future<List<Bookmark>> getForItem(String itemId) async {
    final rows = await _db.query(
      'bookmarks',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}

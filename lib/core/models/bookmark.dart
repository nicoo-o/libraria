/// Miroir de la table `bookmarks` (04_BASE_DE_DONNEES.md). `location` sert aussi bien
/// pour un CFI EPUB que pour un couple (index fichier, position ms) sérialisé en texte
/// pour les audiobooks multi-fichiers (07_READER_AUDIOBOOK.md).
class Bookmark {
  final String id;
  final String itemId;
  final String location;
  final String? text;
  final String? note;
  final int color;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.itemId,
    required this.location,
    this.text,
    this.note,
    this.color = 0,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, Object?> map) => Bookmark(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        location: map['location'] as String,
        text: map['text'] as String?,
        note: map['note'] as String?,
        color: (map['color'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'item_id': itemId,
        'location': location,
        'text': text,
        'note': note,
        'color': color,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

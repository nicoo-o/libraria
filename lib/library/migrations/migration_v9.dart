/// v9 — Fichiers manquants + corbeille à 2 paliers + intégrité par hash.
///
/// Note de réconciliation (04_BASE_DE_DONNEES.md) : un addendum externe (Lovable)
/// avait assigné le numéro « v8 » à la fois à ces colonnes ET en collision avec
/// `cover_cache_index` déjà numéroté v8 par ailleurs. Renuméroté ici en v9, après
/// `cover_cache_index` (v8), dans un ordre cohérent.
const String migrationV9 = '''
ALTER TABLE library_items ADD COLUMN is_missing INTEGER NOT NULL DEFAULT 0;
ALTER TABLE library_items ADD COLUMN last_verified_at INTEGER;
ALTER TABLE library_items ADD COLUMN deleted_at INTEGER;
ALTER TABLE library_items ADD COLUMN content_sha256 TEXT;
CREATE INDEX IF NOT EXISTS idx_items_missing ON library_items(is_missing);
CREATE INDEX IF NOT EXISTS idx_items_deleted ON library_items(deleted_at);
''';

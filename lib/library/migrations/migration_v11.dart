/// v11 — Tags libres, transverses aux étagères.
const String migrationV11 = '''
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT NOT NULL UNIQUE COLLATE NOCASE,
  color INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS item_tags (
  item_id TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);
''';

/// v4 — Signets.
const String migrationV4 = '''
CREATE TABLE IF NOT EXISTS bookmarks (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, location TEXT NOT NULL,
  text TEXT, note TEXT, color INTEGER DEFAULT 0, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_item ON bookmarks(item_id);
''';
